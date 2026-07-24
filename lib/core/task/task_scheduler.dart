// ============================================================================
// 小酥 (XiaoSu) - 任务调度器（TaskScheduler）
//
// 职责：
// 1. 管理定时任务（一次性任务、周期任务、话题追踪）
// 2. 通过 MethodChannel 桥接 Android WorkManager
// 3. 任务的增删改查（CRUD）
// 4. 任务状态持久化与恢复
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'package:xiaosu_core/main.dart' show appLogger;
import 'package:xiaosu_core/platform/android_scheduler.dart';
import 'package:xiaosu_core/services/database_service.dart';
import 'package:xiaosu_core/models/task_model.dart';

/// ============================================================================
/// 任务调度器 —— 管理所有后台定时任务
///
/// 使用单例模式，全局唯一。
///
/// 任务类型：
/// - [TaskType.oneTime]     一次性定时任务（如：10分钟后提醒我）
/// - [TaskType.periodic]    周期重复任务（如：每天早上8点汇报）
/// - [TaskType.topicTrack]  话题追踪任务（如：每周追踪 AI 行业动态）
/// ============================================================================
class TaskScheduler {
  /// 单例实例
  TaskScheduler._internal();
  static final TaskScheduler instance = TaskScheduler._internal();

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── 原生桥接层 ─────────────────────────────────────────────
  final AndroidScheduler _androidScheduler = AndroidScheduler();

  /// ─── 任务缓存（内存中） ─────────────────────────────────────
  final Map<String, ScheduledTask> _tasks = {};

  /// ─── 是否已初始化 ───────────────────────────────────────────
  bool _initialized = false;

  /// ─── UUID 生成器 ────────────────────────────────────────────
  static const _uuid = Uuid();

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化任务调度器
  ///
  /// 从数据库恢复所有持久化的任务，并同步到系统 WorkManager
  Future<void> initialize() async {
    if (_initialized) {
      _logger.w('⚠️ TaskScheduler 已经初始化过');
      return;
    }

    _logger.i('⏰ TaskScheduler 正在初始化...');

    // 从数据库加载所有任务
    final tasks = await DatabaseService.instance.getAllTasks();
    for (final task in tasks) {
      _tasks[task.id] = task;

      // 如果任务已激活（未过期、未取消），同步到 WorkManager
      if (task.isActive) {
        await _syncToWorkManager(task);
      }
    }

    _initialized = true;
    _logger.i('✅ TaskScheduler 初始化完成，恢复 ${_tasks.length} 个任务');
  }

  // ==========================================================================
  // 任务 CRUD
  // ==========================================================================

  /// 创建一次性定时任务
  ///
  /// [title] 任务标题
  /// [prompt] 执行时的提示词（会发送给 AI 生成回复）
  /// [executeAt] 执行时间
  /// [conversationId] 关联的对话 ID（回复会发送到该对话）
  /// [onComplete] 执行完成回调
  Future<ScheduledTask> createOneTimeTask({
    required String title,
    required String prompt,
    required DateTime executeAt,
    String? conversationId,
    VoidCallback? onComplete,
  }) async {
    final task = ScheduledTask(
      id: _uuid.v4(),
      title: title,
      type: TaskType.oneTime,
      prompt: prompt,
      executeAt: executeAt,
      conversationId: conversationId,
      status: TaskStatus.scheduled,
      createdAt: DateTime.now(),
    );

    await _addTask(task);
    _logger.i('📌 创建一次性任务: ${task.title} @ ${task.executeAt}');
    return task;
  }

  /// 创建周期重复任务
  ///
  /// [title] 任务标题
  /// [prompt] 执行时的提示词
  /// [interval] 执行间隔（如 Duration(days: 1)）
  /// [firstExecuteAt] 首次执行时间
  /// [conversationId] 关联的对话 ID
  Future<ScheduledTask> createPeriodicTask({
    required String title,
    required String prompt,
    required Duration interval,
    required DateTime firstExecuteAt,
    String? conversationId,
  }) async {
    final task = ScheduledTask(
      id: _uuid.v4(),
      title: title,
      type: TaskType.periodic,
      prompt: prompt,
      intervalSeconds: interval.inSeconds,
      executeAt: firstExecuteAt,
      conversationId: conversationId,
      status: TaskStatus.scheduled,
      createdAt: DateTime.now(),
    );

    await _addTask(task);
    _logger.i('🔁 创建周期任务: ${task.title} 间隔=${interval.inSeconds}s');
    return task;
  }

  /// 创建话题追踪任务
  ///
  /// [topic] 追踪的话题名称
  /// [interval] 检查间隔
  /// [summaryPrompt] 汇总时的提示词模板
  Future<ScheduledTask> createTopicTrackingTask({
    required String topic,
    required Duration interval,
    String summaryPrompt = '请汇总「{topic}」最近的最新动态和重要变化',
  }) async {
    final task = ScheduledTask(
      id: _uuid.v4(),
      title: '话题追踪: $topic',
      type: TaskType.topicTrack,
      prompt: summaryPrompt.replaceAll('{topic}', topic),
      intervalSeconds: interval.inSeconds,
      executeAt: DateTime.now().add(interval),
      metadata: {'topic': topic},
      status: TaskStatus.scheduled,
      createdAt: DateTime.now(),
    );

    await _addTask(task);
    _logger.i('📡 创建话题追踪: $topic');
    return task;
  }

  /// 获取所有任务
  List<ScheduledTask> getAllTasks() {
    return _tasks.values.toList()
      ..sort((a, b) => (a.executeAt).compareTo(b.executeAt));
  }

  /// 获取指定状态的任务
  List<ScheduledTask> getTasksByStatus(TaskStatus status) {
    return _tasks.values
        .where((t) => t.status == status)
        .toList()
      ..sort((a, b) => a.executeAt.compareTo(b.executeAt));
  }

  /// 获取单个任务
  ScheduledTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  // ==========================================================================
  // 任务控制
  // ==========================================================================

  /// 暂停任务
  Future<void> pauseTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      _logger.w('⚠️ 任务不存在: $taskId');
      return;
    }

    task.status = TaskStatus.paused;
    await _persistTask(task);

    // 从 WorkManager 取消
    await _androidScheduler.cancelTask(taskId);
    _logger.i('⏸️ 暂停任务: ${task.title}');
  }

  /// 恢复任务
  Future<void> resumeTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      _logger.w('⚠️ 任务不存在: $taskId');
      return;
    }

    task.status = TaskStatus.scheduled;
    await _persistTask(task);
    await _syncToWorkManager(task);
    _logger.i('▶️ 恢复任务: ${task.title}');
  }

  /// 取消（删除）任务
  Future<void> cancelTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    task.status = TaskStatus.cancelled;
    await _persistTask(task);

    // 从 WorkManager 取消
    await _androidScheduler.cancelTask(taskId);

    // 从缓存中移除
    _tasks.remove(taskId);
    _logger.i('❌ 取消任务: ${task.title}');
  }

  /// 立即执行某个任务（调试用）
  Future<TaskExecutionResult> executeNow(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      throw TaskNotFoundException('任务不存在: $taskId');
    }

    _logger.i('⚡ 立即执行任务: ${task.title}');
    return _executeTask(task);
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 添加任务到调度器
  Future<void> _addTask(ScheduledTask task) async {
    _tasks[task.id] = task;
    await _persistTask(task);
    await _syncToWorkManager(task);
  }

  /// 持久化任务到数据库
  Future<void> _persistTask(ScheduledTask task) async {
    try {
      await DatabaseService.instance.saveTask(task);
    } catch (e) {
      _logger.e('❌ 任务持久化失败: $e');
    }
  }

  /// 同步任务到 Android WorkManager
  Future<void> _syncToWorkManager(ScheduledTask task) async {
    if (!task.isActive) return;

    final delay = task.executeAt.difference(DateTime.now());

    // 如果执行时间已过且是周期任务，立即安排下一次
    if (delay.isNegative && task.type == TaskType.periodic) {
      await _androidScheduler.schedulePeriodic(
        taskId: task.id,
        intervalSeconds: task.intervalSeconds!,
        prompt: task.prompt,
        metadata: jsonEncode(task.metadata ?? {}),
      );
      return;
    }

    // 一次性任务
    if (task.type == TaskType.oneTime) {
      await _androidScheduler.scheduleOneTime(
        taskId: task.id,
        delaySeconds: delay.inSeconds > 0 ? delay.inSeconds : 0,
        prompt: task.prompt,
        metadata: jsonEncode(task.metadata ?? {}),
      );
      return;
    }

    // 周期任务
    if (task.type == TaskType.periodic || task.type == TaskType.topicTrack) {
      await _androidScheduler.schedulePeriodic(
        taskId: task.id,
        intervalSeconds: task.intervalSeconds!,
        prompt: task.prompt,
        metadata: jsonEncode(task.metadata ?? {}),
      );
      return;
    }
  }

  /// 执行任务（生成 AI 回复）
  Future<TaskExecutionResult> _executeTask(ScheduledTask task) async {
    try {
      // 调用 ChatEngine 处理任务提示词
      // 这里通过事件总线或直接调用实现
      final result = await _runPromptForTask(task);

      // 更新任务执行记录
      task.lastExecutedAt = DateTime.now();
      task.executionCount++;

      if (task.type == TaskType.oneTime) {
        task.status = TaskStatus.completed;
      }

      await _persistTask(task);

      return TaskExecutionResult(
        success: true,
        taskId: task.id,
        result: result,
        executedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.e('❌ 任务执行失败: ${task.title} - $e');

      task.executionCount++;
      task.lastError = e.toString();
      await _persistTask(task);

      return TaskExecutionResult(
        success: false,
        taskId: task.id,
        error: e.toString(),
        executedAt: DateTime.now(),
      );
    }
  }

  /// 运行任务的提示词
  /// TODO: 集成 ChatEngine 的完整对话流程
  Future<String> _runPromptForTask(ScheduledTask task) async {
    // 这里应该调用 ChatEngine.sendMessage() 或类似方法
    // 将 task.prompt 作为用户消息发送给 AI
    // 并将 AI 回复保存到对应的对话中

    _logger.d('🏃 运行任务提示词: ${_truncate(task.prompt, 80)}');

    // 占位实现 —— 实际会调用 ChatEngine
    return '任务 [${task.title}] 已执行';
  }

  /// 截断文本
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

// ============================================================================
/// 任务执行结果
/// ============================================================================
class TaskExecutionResult {
  final bool success;
  final String taskId;
  final String? result;
  final String? error;
  final DateTime executedAt;

  const TaskExecutionResult({
    required this.success,
    required this.taskId,
    this.result,
    this.error,
    required this.executedAt,
  });
}

// ============================================================================
/// 任务未找到异常
/// ============================================================================
class TaskNotFoundException implements Exception {
  final String message;
  const TaskNotFoundException(this.message);

  @override
  String toString() => 'TaskNotFoundException: $message';
}

/// VoidCallback 类型定义（避免额外导入）
typedef VoidCallback = void Function();

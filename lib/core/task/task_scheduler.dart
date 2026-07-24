// ============================================================================
// 小酥 - 任务调度器（完整版）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

/// 任务调度器 - 管理定时任务的CRUD和执行
class TaskScheduler {
  static final TaskScheduler instance = TaskScheduler._();
  TaskScheduler._();

  static const String _storageKey = 'xiaosu_tasks';
  final List<TaskModel> _tasks = [];
  Timer? _checkTimer;
  bool _initialized = false;

  /// 初始化调度器
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _startScheduler();
    _initialized = true;
  }

  /// 启动调度器定时检查
  void _startScheduler() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndRunTasks();
    });
  }

  /// 检查并执行到期任务
  void _checkAndRunTasks() {
    final now = DateTime.now();
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status == TaskStatus.idle || task.status == TaskStatus.running) {
        if (task.nextExecutionAt != null && task.nextExecutionAt!.isBefore(now)) {
          _executeTask(task.id);
        }
      }
    }
  }

  /// 执行任务
  Future<void> _executeTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final task = _tasks[idx];
    // 更新为运行中
    _tasks[idx] = task.copyWith(status: TaskStatus.running);
    await _saveToStorage();

    try {
      // 模拟任务执行（实际会调用ChatEngine）
      await Future.delayed(const Duration(seconds: 1));

      final now = DateTime.now();
      final nextRun = task.interval != null
          ? now.add(task.interval!)
          : null;

      _tasks[idx] = task.copyWith(
        status: task.interval != null ? TaskStatus.idle : TaskStatus.completed,
        lastExecutedAt: now,
        executionCount: task.executionCount + 1,
        nextExecutionAt: nextRun,
        lastResult: '执行成功',
      );
    } catch (e) {
      _tasks[idx] = task.copyWith(
        status: TaskStatus.failed,
        lastError: e.toString(),
      );
    }
    await _saveToStorage();
  }

  /// 获取所有任务
  List<TaskModel> getAllTasks() => List.unmodifiable(_tasks);

  /// 添加任务
  Future<void> addTask(TaskModel task) async {
    _tasks.add(task);
    await _saveToStorage();
  }

  /// 删除任务
  Future<void> removeTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveToStorage();
  }

  /// 暂停任务
  Future<void> pauseTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(status: TaskStatus.paused);
      await _saveToStorage();
    }
  }

  /// 恢复任务
  Future<void> resumeTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = _tasks[idx];
      final nextRun = task.interval != null
          ? DateTime.now().add(task.interval!)
          : null;
      _tasks[idx] = task.copyWith(
        status: TaskStatus.idle,
        nextExecutionAt: nextRun,
      );
      await _saveToStorage();
    }
  }

  /// 立即执行任务
  Future<void> runTaskNow(String taskId) async {
    await _executeTask(taskId);
  }

  /// 更新任务
  Future<void> updateTask(TaskModel task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _tasks[idx] = task;
      await _saveToStorage();
    }
  }

  /// 从本地存储加载
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _tasks.clear();
        _tasks.addAll(list.map((e) =>
            TaskModel.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  /// 保存到本地存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {
      // ignore save errors
    }
  }

  /// 释放资源
  void dispose() {
    _checkTimer?.cancel();
    _tasks.clear();
  }
}

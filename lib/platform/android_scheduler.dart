// ============================================================================
// 小酥 (XiaoSu) - Android 调度桥接层
//
// 职责：
// 封装 MethodChannel，与 Android 原生 WorkManager 通信
// 提供类型安全的 Dart 侧 API
//
// 原生侧（Android/Kotlin）需要实现：
// - 注册 MethodChannel "com.xiaosu.scheduler"
// - 处理 scheduleOneTime / schedulePeriodic / cancelTask / getPendingTasks
// - 使用 androidx.work.WorkManager 实现后台任务调度
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

/// ============================================================================
/// Android 调度桥接 —— MethodChannel 封装
///
/// 所有方法都是类型安全的，返回明确的 Future 类型。
/// 如果平台不是 Android，方法会静默返回空结果。
/// ============================================================================
class AndroidScheduler {
  /// ─── MethodChannel 实例 ─────────────────────────────────────
  static const MethodChannel _channel = MethodChannel('com.xiaosu.scheduler');

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── 是否已检查过平台 ───────────────────────────────────────
  bool _platformChecked = false;
  bool _isAndroid = false;

  // ==========================================================================
  // 平台检测
  // ==========================================================================

  /// 检测当前平台是否为 Android
  Future<bool> get isAndroid async {
    if (!_platformChecked) {
      try {
        final result = await _channel.invokeMethod<bool>('isAndroidPlatform');
        _isAndroid = result ?? false;
      } catch (e) {
        // 在非 Android 平台上，MethodChannel 调用可能失败
        _isAndroid = false;
        _logger.d('📱 非 Android 平台，后台调度不可用');
      }
      _platformChecked = true;
    }
    return _isAndroid;
  }

  // ==========================================================================
  // 调度 API
  // ==========================================================================

  /// 安排一次性定时任务
  ///
  /// [taskId] 任务唯一标识
  /// [delaySeconds] 延迟多少秒后执行
  /// [prompt] 执行时发送给 AI 的提示词
  /// [metadata] 附加元数据（JSON 字符串）
  ///
  /// 返回是否安排成功
  Future<bool> scheduleOneTime({
    required String taskId,
    required int delaySeconds,
    required String prompt,
    String metadata = '{}',
  }) async {
    if (!await isAndroid) {
      _logger.w('⚠️ 非 Android 平台，无法安排一次性任务');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'scheduleOneTime',
        <String, dynamic>{
          'taskId': taskId,
          'delaySeconds': delaySeconds,
          'prompt': prompt,
          'metadata': metadata,
        },
      );

      _logger.i('📌 已安排一次性任务: $taskId (延迟 ${delaySeconds}s)');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 安排一次性任务失败: ${e.message}');
      return false;
    } catch (e) {
      _logger.e('❌ 安排一次性任务异常: $e');
      return false;
    }
  }

  /// 安排周期重复任务
  ///
  /// [taskId] 任务唯一标识
  /// [intervalSeconds] 执行间隔（秒），Android WorkManager 最小间隔为 15 分钟
  /// [prompt] 执行时发送给 AI 的提示词
  /// [metadata] 附加元数据（JSON 字符串）
  ///
  /// 返回是否安排成功
  Future<bool> schedulePeriodic({
    required String taskId,
    required int intervalSeconds,
    required String prompt,
    String metadata = '{}',
  }) async {
    if (!await isAndroid) {
      _logger.w('⚠️ 非 Android 平台，无法安排周期任务');
      return false;
    }

    // Android WorkManager 最小周期为 15 分钟
    final minInterval = 15 * 60; // 900 秒
    if (intervalSeconds < minInterval) {
      _logger.w('⚠️ 周期间隔过短（${intervalSeconds}s），自动调整为最小值 ${minInterval}s');
      intervalSeconds = minInterval;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'schedulePeriodic',
        <String, dynamic>{
          'taskId': taskId,
          'intervalSeconds': intervalSeconds,
          'prompt': prompt,
          'metadata': metadata,
        },
      );

      _logger.i('🔁 已安排周期任务: $taskId (间隔 ${intervalSeconds}s)');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 安排周期任务失败: ${e.message}');
      return false;
    } catch (e) {
      _logger.e('❌ 安排周期任务异常: $e');
      return false;
    }
  }

  /// 取消任务
  ///
  /// [taskId] 要取消的任务 ID
  /// 返回是否取消成功
  Future<bool> cancelTask(String taskId) async {
    if (!await isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'cancelTask',
        <String, dynamic>{
          'taskId': taskId,
        },
      );

      _logger.i('❌ 已取消任务: $taskId');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 取消任务失败: ${e.message}');
      return false;
    }
  }

  /// 获取所有待执行的任务
  ///
  /// 返回任务列表，每个元素包含 taskId、type、nextExecuteTime 等
  Future<List<PendingTaskInfo>> getPendingTasks() async {
    if (!await isAndroid) return [];

    try {
      final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
        'getPendingTasks',
      );

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return PendingTaskInfo(
          taskId: map['taskId'] as String,
          taskType: map['taskType'] as String? ?? 'unknown',
          nextExecuteTime: map['nextExecuteTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['nextExecuteTime'] as int)
              : null,
          isPeriodic: map['isPeriodic'] as bool? ?? false,
        );
      }).toList();
    } on PlatformException catch (e) {
      _logger.e('❌ 获取待执行任务失败: ${e.message}');
      return [];
    }
  }

  /// 取消所有任务
  ///
  /// 返回是否成功
  Future<bool> cancelAllTasks() async {
    if (!await isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('cancelAllTasks');
      _logger.i('🗑️ 已取消所有任务');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 取消所有任务失败: ${e.message}');
      return false;
    }
  }

  /// 检查 WorkManager 权限
  ///
  /// Android 12+ 需要 SCHEDULE_EXACT_ALARM 权限才能安排精确时间任务
  Future<bool> checkExactAlarmPermission() async {
    if (!await isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('checkExactAlarmPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 检查权限失败: ${e.message}');
      return false;
    }
  }

  /// 请求精确闹钟权限
  Future<bool> requestExactAlarmPermission() async {
    if (!await isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('requestExactAlarmPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('❌ 请求权限失败: ${e.message}');
      return false;
    }
  }

  // ==========================================================================
  // 回调监听（原生 → Flutter）
  // ==========================================================================

  /// 监听任务执行完成回调
  ///
  /// 当 WorkManager 执行完任务后，原生侧会通过 EventChannel
  /// 或 MethodChannel 回调通知 Flutter 层处理结果
  static Stream<TaskCallbackData> onTaskCompleted() {
    const eventChannel = EventChannel('com.xiaosu.scheduler/callback');

    return eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return TaskCallbackData(
        taskId: map['taskId'] as String,
        result: map['result'] as String? ?? '',
        success: map['success'] as bool? ?? false,
      );
    });
  }
}

// ============================================================================
/// 待执行任务信息（从 WorkManager 查询）
/// ============================================================================
class PendingTaskInfo {
  final String taskId;
  final String taskType;
  final DateTime? nextExecuteTime;
  final bool isPeriodic;

  const PendingTaskInfo({
    required this.taskId,
    required this.taskType,
    this.nextExecuteTime,
    required this.isPeriodic,
  });

  @override
  String toString() =>
      'PendingTask($taskId, type=$taskType, periodic=$isPeriodic, next=$nextExecuteTime)';
}

// ============================================================================
/// 任务完成回调数据
/// ============================================================================
class TaskCallbackData {
  final String taskId;
  final String result;
  final bool success;

  const TaskCallbackData({
    required this.taskId,
    required this.result,
    required this.success,
  });
}

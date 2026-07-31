// ============================================================================
// 小酥 - Android调度器
// ============================================================================

import 'platform_scheduler.dart';

/// Android平台调度器
class AndroidScheduler extends PlatformScheduler {
  @override
  String get platformName => 'Android';

  @override
  Future<void> initialize() async {
    // Android后台任务初始化
  }

  @override
  Future<void> scheduleBackgroundTask(String taskId, Duration delay) async {
    // 使用WorkManager调度后台任务
  }

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> dispose() async {}
}

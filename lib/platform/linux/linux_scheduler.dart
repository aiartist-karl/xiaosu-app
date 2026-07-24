// ============================================================================
// 小酥 - Linux调度器
// ============================================================================

import '../platform_scheduler.dart';

class LinuxScheduler extends PlatformScheduler {
  @override
  String get platformName => 'Linux';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleBackgroundTask(String taskId, Duration delay) async {}
  @override
  Future<void> cancelTask(String taskId) async {}
  @override
  Future<void> dispose() async {}
}

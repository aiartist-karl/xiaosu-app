// ============================================================================
// 小酥 - iOS调度器
// ============================================================================

import '../platform_scheduler.dart';

/// iOS平台调度器
class IosScheduler extends PlatformScheduler {
  @override
  String get platformName => 'iOS';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleBackgroundTask(String taskId, Duration delay) async {}

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> dispose() async {}
}

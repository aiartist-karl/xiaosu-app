// ============================================================================
// 小酥 - macOS调度器
// ============================================================================

import '../platform_scheduler.dart';

class MacosScheduler extends PlatformScheduler {
  @override
  String get platformName => 'macOS';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleBackgroundTask(String taskId, Duration delay) async {}
  @override
  Future<void> cancelTask(String taskId) async {}
  @override
  Future<void> dispose() async {}
}

// ============================================================================
// 小酥 - 平台调度器（跨平台）
// ============================================================================

/// 平台调度器接口
abstract class PlatformScheduler {
  String get platformName;
  Future<void> initialize();
  Future<void> scheduleBackgroundTask(String taskId, Duration delay);
  Future<void> cancelTask(String taskId);
  Future<void> dispose();
}

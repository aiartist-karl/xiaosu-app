// ============================================================================
// 小酥 - Coze Studio 任务调度管理器
// Phase 6: 统一管理层，整合本地 TaskScheduler + 远程日历 API
// ============================================================================

import '../gateway/api_gateway.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/models/task_model.dart';

/// Coze 任务调度管理器 - 统一管理日程事件
///
/// 职责：
/// 1. 对接 Coze Studio calendar-service
/// 2. 提供日程 CRUD 的高层封装
/// 3. 支持日期范围查询、今日/本周快捷查询
class CozeTaskManager {
  static final CozeTaskManager instance = CozeTaskManager._();
  CozeTaskManager._();

  final TaskRepository _repo = TaskRepository();

  bool _initialized = false;
  String? _currentBotId;

  // 缓存日程列表（减少重复请求）
  List<CozeCalendarEvent> _cachedEvents = [];
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 当前 Bot ID
  String? get currentBotId => _currentBotId;

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化任务管理器
  Future<void> initialize({String? botId}) async {
    if (_initialized) return;
    _currentBotId = botId;
    _initialized = true;
  }

  /// 设置当前 Bot ID
  void setCurrentBot(String botId) {
    _currentBotId = botId;
    _clearCache();
  }

  // ==========================================================================
  // 日程 CRUD
  // ==========================================================================

  /// 创建日程
  ///
  /// [title] 日程标题
  /// [startTime] 开始时间
  /// [endTime] 结束时间
  /// [description] 描述
  /// [reminder] 提醒时间（如 "5m", "1h", "1d" 等）
  Future<ApiResponse<CozeCalendarEvent>> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? reminder,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await _repo.createEvent(
      title: title,
      startTime: startTime,
      endTime: endTime,
      description: description,
      reminder: reminder,
      botId: _currentBotId,
      metadata: metadata,
    );

    // 成功后清除缓存
    if (result.success) {
      _clearCache();
    }

    return result;
  }

  /// 获取日程列表（指定日期范围）
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 检查缓存
    if (_isCacheValid()) {
      return ApiResponse.ok(_cachedEvents);
    }

    final result = await _repo.fetchEventList(
      startDate: startDate,
      endDate: endDate,
      botId: _currentBotId,
    );

    if (result.success && result.data != null) {
      _cachedEvents = result.data!;
      _lastFetchTime = DateTime.now();
    }

    return result;
  }

  /// 获取今日日程
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchTodayEvents() async {
    return _repo.fetchTodayEvents(botId: _currentBotId);
  }

  /// 获取本周日程
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchWeekEvents() async {
    return _repo.fetchWeekEvents(botId: _currentBotId);
  }

  /// 更新日程
  Future<ApiResponse<CozeCalendarEvent>> updateEvent(
    String eventId, {
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? reminder,
    CozeEventStatus? status,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await _repo.updateEvent(
      eventId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      description: description,
      reminder: reminder,
      status: status,
      metadata: metadata,
    );

    if (result.success) {
      _clearCache();
    }

    return result;
  }

  /// 删除日程
  Future<ApiResponse<void>> deleteEvent(String eventId) async {
    final result = await _repo.deleteEvent(eventId);

    if (result.success) {
      _clearCache();
    }

    return result;
  }

  /// 标记日程为已完成
  Future<ApiResponse<CozeCalendarEvent>> completeEvent(String eventId) async {
    return updateEvent(eventId, status: CozeEventStatus.completed);
  }

  /// 取消日程
  Future<ApiResponse<CozeCalendarEvent>> cancelEvent(String eventId) async {
    return updateEvent(eventId, status: CozeEventStatus.cancelled);
  }

  // ==========================================================================
  // 批量操作
  // ==========================================================================

  /// 创建多个日程（批量）
  Future<List<ApiResponse<CozeCalendarEvent>>> createEvents(
    List<CozeCalendarEvent> events,
  ) async {
    final results = <ApiResponse<CozeCalendarEvent>>[];
    for (final event in events) {
      final result = await createEvent(
        title: event.title,
        startTime: event.startTime,
        endTime: event.endTime,
        description: event.description,
        reminder: event.reminder,
        metadata: event.metadata,
      );
      results.add(result);
    }
    return results;
  }

  /// 获取即将到来的日程（按时间排序）
  Future<List<CozeCalendarEvent>> fetchUpcomingEvents({
    int limit = 10,
  }) async {
    final now = DateTime.now();
    final farFuture = now.add(const Duration(days: 30));

    final result = await fetchEvents(startDate: now, endDate: farFuture);
    if (!result.success || result.data == null) return [];

    final events = List<CozeCalendarEvent>.from(result.data!);
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    return events.take(limit).toList();
  }

  // ==========================================================================
  // 缓存管理
  // ==========================================================================

  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  void _clearCache() {
    _cachedEvents = [];
    _lastFetchTime = null;
  }

  /// 手动清除缓存
  void invalidateCache() => _clearCache();

  /// 强制刷新日程列表
  Future<ApiResponse<List<CozeCalendarEvent>>> refreshEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _clearCache();
    return fetchEvents(startDate: startDate, endDate: endDate);
  }
}

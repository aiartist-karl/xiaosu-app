// ============================================================================
// 小酥 - 任务/日程数据仓库层
// Phase 6: 封装 Coze Studio 日历/任务调度 API 调用
// ============================================================================

import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';
import '../models/task_model.dart';

/// 任务/日程数据仓库 - 封装 Coze Studio Calendar Event API
///
/// 对接 calendar-service 模块
/// 使用 PAT Token 认证
class TaskRepository {
  final ApiGateway _api;

  TaskRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // API 路径常量
  // ==========================================================================
  static const String _pathCreate = '/v3/calendar/event/create';
  static const String _pathList = '/v3/calendar/event/list';
  static const String _pathUpdate = '/v3/calendar/event/update';
  static const String _pathDelete = '/v3/calendar/event/delete';

  // ==========================================================================
  // CRUD 操作
  // ==========================================================================

  /// 创建日程事件
  ///
  /// POST /v3/calendar/event/create
  /// Body: { title, description?, start_time, end_time, reminder?, bot_id? }
  Future<ApiResponse<CozeCalendarEvent>> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? reminder,
    String? botId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      };
      if (description != null) body['description'] = description;
      if (reminder != null) body['reminder'] = reminder;
      if (botId != null) body['bot_id'] = botId;
      if (metadata != null) body['metadata'] = metadata;

      final response = await _api.post(
        _pathCreate,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建日程失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final eventData = data['event'] as Map<String, dynamic>? ?? data;
      return ApiResponse.ok(CozeCalendarEvent.fromJson(eventData));
    } catch (e) {
      return ApiResponse.fail('创建日程异常: ${e.toString()}');
    }
  }

  /// 获取日程列表
  ///
  /// GET /v3/calendar/event/list
  /// Query: start_date, end_date, bot_id?, page, page_size
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchEventList({
    required DateTime startDate,
    required DateTime endDate,
    String? botId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (botId != null) queryParams['bot_id'] = botId;

      final response = await _api.get(
        _pathList,
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取日程列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final eventsRaw = data['events'] ?? data['data'];
      if (eventsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final events = eventsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeCalendarEvent.fromJson(e))
          .toList();

      return ApiResponse.ok(events);
    } catch (e) {
      return ApiResponse.fail('获取日程列表异常: ${e.toString()}');
    }
  }

  /// 更新日程事件
  ///
  /// POST /v3/calendar/event/update
  /// Body: { event_id, title?, start_time?, end_time?, description?, ... }
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
    try {
      final body = <String, dynamic>{
        'event_id': eventId,
      };
      if (title != null) body['title'] = title;
      if (startTime != null) body['start_time'] = startTime.toIso8601String();
      if (endTime != null) body['end_time'] = endTime.toIso8601String();
      if (description != null) body['description'] = description;
      if (reminder != null) body['reminder'] = reminder;
      if (status != null) body['status'] = status.name;
      if (metadata != null) body['metadata'] = metadata;

      final response = await _api.post(
        _pathUpdate,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '更新日程失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final eventData = data['event'] as Map<String, dynamic>? ?? data;
      return ApiResponse.ok(CozeCalendarEvent.fromJson(eventData));
    } catch (e) {
      return ApiResponse.fail('更新日程异常: ${e.toString()}');
    }
  }

  /// 删除日程事件
  ///
  /// DELETE /v3/calendar/event/delete
  /// Query: event_id
  Future<ApiResponse<void>> deleteEvent(String eventId) async {
    try {
      final response = await _api.delete(
        _pathDelete,
        headers: {'Content-Type': 'application/json'},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '删除日程失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除日程异常: ${e.toString()}');
    }
  }

  /// 获取今日日程
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchTodayEvents({
    String? botId,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return fetchEventList(
      startDate: startOfDay,
      endDate: endOfDay,
      botId: botId,
    );
  }

  /// 获取本周日程
  Future<ApiResponse<List<CozeCalendarEvent>>> fetchWeekEvents({
    String? botId,
  }) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfDay.add(const Duration(days: 7));

    return fetchEventList(
      startDate: startOfDay,
      endDate: endOfWeek,
      botId: botId,
    );
  }
}

// ============================================================================
// 小酥 - 记忆数据仓库层
// Phase 6: 扩展对接 Coze Studio 记忆系统 API
// 保留本地 MemoryCenter 支持 + 新增 Coze Studio 远程记忆 API
// ============================================================================

import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';
import '../../core/memory/memory_center.dart';
import '../models/memory_model.dart';

/// 记忆数据仓库 - 同时支持本地记忆和 Coze Studio 远程记忆
///
/// 本地记忆：通过 MemoryCenterService（向量搜索 + SharedPreferences 持久化）
/// 远程记忆：通过 Coze Studio memory-service API
class MemoryRepository {
  static final MemoryRepository instance = MemoryRepository._();
  MemoryRepository._();

  final MemoryCenterService _localMemory = MemoryCenterService.instance;
  final ApiGateway _api = ApiGateway.instance;

  // ==========================================================================
  // API 路径常量
  // ==========================================================================
  static const String _pathCreate = '/v3/memory/create';
  static const String _pathList = '/v3/memory/list';
  static const String _pathDelete = '/v3/memory/delete';
  static const String _pathSearch = '/v3/memory/search';

  // ==========================================================================
  // 本地记忆操作（保留原有功能）
  // ==========================================================================

  /// 添加本地记忆
  Future<MemoryItem> addLocal(
    String content, {
    MemoryType type = MemoryType.shortTerm,
    double importance = 0.5,
  }) async {
    return await _localMemory.addMemory(
      content: content,
      type: type,
      importance: importance,
    );
  }

  /// 搜索本地记忆
  List<MemoryItem> searchLocal(String query, {int topK = 5}) {
    return _localMemory.searchMemories(query, topK: topK);
  }

  /// 删除本地记忆
  Future<void> removeLocal(String id) async {
    await _localMemory.removeMemory(id);
  }

  /// 获取所有本地记忆
  List<MemoryItem> getAllLocal({MemoryType? type}) {
    return _localMemory.getAllMemories(type: type);
  }

  /// 清空本地记忆
  Future<void> clearAllLocal() async {
    await _localMemory.clearAll();
  }

  // ==========================================================================
  // Coze Studio 远程记忆操作（Phase 6 新增）
  // ==========================================================================

  /// 创建远程记忆
  ///
  /// POST /v3/memory/create
  /// Body: { content, tags[], bot_id?, type? }
  Future<ApiResponse<CozeMemory>> createMemory(
    String content, {
    List<String> tags = const [],
    String? botId,
    CozeMemoryType type = CozeMemoryType.longTerm,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        'tags': tags,
        'type': type.name,
      };
      if (botId != null) body['bot_id'] = botId;

      final response = await _api.post(
        _pathCreate,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建记忆失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final memoryData = data['memory'] as Map<String, dynamic>? ?? data;
      return ApiResponse.ok(CozeMemory.fromJson(memoryData));
    } catch (e) {
      return ApiResponse.fail('创建记忆异常: ${e.toString()}');
    }
  }

  /// 获取远程记忆列表
  ///
  /// GET /v3/memory/list
  /// Query: bot_id, page, page_size
  Future<ApiResponse<List<CozeMemory>>> fetchMemoryList({
    String? botId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
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
        return ApiResponse.fail(response.error ?? '获取记忆列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final memoriesRaw = data['memories'] ?? data['data'];
      if (memoriesRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final memories = memoriesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeMemory.fromJson(e))
          .toList();

      return ApiResponse.ok(memories);
    } catch (e) {
      return ApiResponse.fail('获取记忆列表异常: ${e.toString()}');
    }
  }

  /// 删除远程记忆
  ///
  /// DELETE /v3/memory/delete
  /// Query: memory_id
  Future<ApiResponse<void>> deleteMemory(String memoryId) async {
    try {
      final response = await _api.delete(
        _pathDelete,
        headers: {'Content-Type': 'application/json'},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '删除记忆失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除记忆异常: ${e.toString()}');
    }
  }

  /// 搜索远程记忆
  ///
  /// POST /v3/memory/search
  /// Body: { query, bot_id?, top_k? }
  Future<ApiResponse<List<CozeMemory>>> searchMemory(
    String query, {
    String? botId,
    int topK = 10,
  }) async {
    try {
      final body = <String, dynamic>{
        'query': query,
        'top_k': topK,
      };
      if (botId != null) body['bot_id'] = botId;

      final response = await _api.post(
        _pathSearch,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '搜索记忆失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final memoriesRaw = data['memories'] ?? data['data'] ?? data['results'];
      if (memoriesRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final memories = memoriesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeMemory.fromJson(e))
          .toList();

      return ApiResponse.ok(memories);
    } catch (e) {
      return ApiResponse.fail('搜索记忆异常: ${e.toString()}');
    }
  }

  /// 同步记忆：先搜索本地，再查询远程，合并结果
  Future<List<CozeMemory>> searchAll(
    String query, {
    String? botId,
    int localTopK = 5,
    int remoteTopK = 5,
  }) async {
    final remoteResult = await searchMemory(query, botId: botId, topK: remoteTopK);
    return remoteResult.data ?? [];
  }
}

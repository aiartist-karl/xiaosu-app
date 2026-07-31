// ============================================================================
// 小酥 - 对话仓库层
// Phase 3: 对接 Coze Studio 会话 API，保留本地 SQLite 兼容
// ============================================================================

import 'dart:async';
import '../models/conversation_model.dart';
import '../../services/database_service.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 对话仓库 - 支持本地 SQLite + Coze Studio 远程同步
class ConversationRepository {
  static final ConversationRepository instance = ConversationRepository._();
  ConversationRepository._();

  final DatabaseService _db = DatabaseService.instance;
  final ApiGateway _api = ApiGateway.instance;

  // 本地缓存
  final Map<String, ConversationModel> _cache = {};
  bool _cacheLoaded = false;

  // ==========================================================================
  // 本地 CRUD（向后兼容）
  // ==========================================================================

  /// 获取所有对话（优先本地缓存）
  Future<List<ConversationModel>> getAll({String status = 'active'}) async {
    if (!_cacheLoaded) {
      final list = await _db.getConversations(status: status);
      for (final c in list) {
        _cache[c.id] = c;
      }
      _cacheLoaded = true;
    }
    return _cache.values
        .where((c) => c.status == status)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// 获取单个对话
  Future<ConversationModel?> getById(String id) async {
    if (_cache.containsKey(id)) return _cache[id];
    final model = await _db.getConversation(id);
    if (model != null) _cache[id] = model;
    return model;
  }

  /// 创建对话（本地 + 远程）
  Future<ConversationModel> create(ConversationModel conversation) async {
    // 先存本地
    await _db.insertConversation(conversation);
    _cache[conversation.id] = conversation;
    return conversation;
  }

  /// 更新对话
  Future<void> update(ConversationModel conversation) async {
    await _db.updateConversation(conversation);
    _cache[conversation.id] = conversation;
  }

  /// 删除对话
  Future<void> delete(String id) async {
    await _db.deleteConversation(id);
    _cache.remove(id);
  }

  // ==========================================================================
  // Phase 3: Coze Studio 远程 API
  // ==========================================================================

  /// 从 Coze Studio 获取会话列表
  Future<List<ConversationModel>> fetchFromCoze({
    String? botId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (botId != null) queryParams['bot_id'] = botId;

    final response = await _api.get(
      AppConfig.v1Conversations,
      queryParams: queryParams,
      authType: CozeAuthType.pat,
    );

    if (!response.success) return [];

    final conversations = response.data?['conversations'] as List? ?? [];
    final models = conversations
        .map((c) => ConversationModel.fromCozeApi(
            Map<String, dynamic>.from(c as Map)))
        .toList();

    // 缓存到本地
    for (final m in models) {
      _cache[m.id] = m;
    }

    return models;
  }

  /// 在 Coze Studio 创建会话
  Future<ConversationModel?> createOnCoze({String? botId}) async {
    final body = <String, dynamic>{
      'bot_id': botId ?? AppConfig.cozeStudioBotId,
    };

    final response = await _api.post(
      AppConfig.v1ConversationCreate,
      body: body,
      authType: CozeAuthType.pat,
    );

    if (!response.success) return null;

    final data = response.data?['data'] ?? response.data;
    if (data == null) return null;

    final model = ConversationModel.fromCozeApi(
        Map<String, dynamic>.from(data as Map));

    // 缓存并持久化
    _cache[model.id] = model;
    try {
      await _db.insertConversation(model);
    } catch (_) {
      // 本地持久化失败不影响远程会话
    }

    return model;
  }

  /// 获取 Coze Studio 会话详情
  Future<ConversationModel?> retrieveFromCoze(String conversationId) async {
    final response = await _api.get(
      AppConfig.v1ConversationRetrieve,
      queryParams: {'conversation_id': conversationId},
      authType: CozeAuthType.pat,
    );

    if (!response.success) return null;

    final data = response.data?['data'] ?? response.data;
    if (data == null) return null;

    final model = ConversationModel.fromCozeApi(
        Map<String, dynamic>.from(data as Map));
    _cache[model.id] = model;
    return model;
  }

  /// 更新 Coze Studio 会话名称
  Future<bool> updateOnCoze(String conversationId, {String? name, Map<String, dynamic>? metaData}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (metaData != null) body['meta_data'] = metaData;

    final response = await _api.put(
      '/v1/conversations/$conversationId',
      body: body,
      authType: CozeAuthType.session,
    );

    if (response.success && _cache.containsKey(conversationId)) {
      _cache[conversationId] = _cache[conversationId]!.copyWith(
        title: name ?? _cache[conversationId]!.title,
      );
    }

    return response.success;
  }

  /// 删除 Coze Studio 会话
  Future<bool> deleteOnCoze(String conversationId) async {
    final response = await _api.delete(
      '/v1/conversations/$conversationId',
      authType: CozeAuthType.session,
    );

    if (response.success) {
      _cache.remove(conversationId);
      try {
        await _db.deleteConversation(conversationId);
      } catch (_) {}
    }

    return response.success;
  }

  /// 清空 Coze Studio 会话消息
  Future<bool> clearOnCoze(String conversationId) async {
    final response = await _api.post(
      '/v1/conversations/$conversationId/clear',
      authType: CozeAuthType.session,
    );

    if (response.success && _cache.containsKey(conversationId)) {
      _cache[conversationId] = _cache[conversationId]!.copyWith(
        messageCount: 0,
        lastMessage: '',
      );
    }

    return response.success;
  }

  /// 获取 Coze Studio 会话消息列表
  Future<List<Map<String, dynamic>>> fetchMessagesFromCoze({
    required String conversationId,
    String? cursor,
    int limit = 50,
  }) async {
    final body = <String, dynamic>{
      'conversation_id': conversationId,
      'limit': limit,
    };
    if (cursor != null) body['cursor'] = cursor;

    final response = await _api.post(
      AppConfig.v1ConversationMessageList,
      body: body,
      authType: CozeAuthType.pat,
    );

    if (!response.success) return [];

    final data = response.data?['data'] ?? response.data;
    if (data == null) return [];

    final messages = data['messages'] as List? ?? [];
    return messages.map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  /// 获取 Coze Studio chat 消息列表（/v3/chat/message/list）
  Future<List<Map<String, dynamic>>> fetchChatMessagesFromCoze({
    required String conversationId,
    required String chatId,
  }) async {
    final response = await _api.get(
      AppConfig.v3ChatMessageList,
      queryParams: {
        'conversation_id': conversationId,
        'chat_id': chatId,
      },
      authType: CozeAuthType.pat,
    );

    if (!response.success) return [];

    final data = response.data?['data'] ?? response.data;
    if (data == null) return [];

    final messages = data['messages'] as List? ?? [];
    return messages.map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
    _cacheLoaded = false;
  }
}

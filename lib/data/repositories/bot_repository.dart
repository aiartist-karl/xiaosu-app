// ============================================================================
// 小酥 v2 - Bot 数据仓库层
// Phase 2: 封装 Coze Studio Bot 管理 API 调用
// ============================================================================

import '../models/bot_model.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// Bot 数据仓库 - 封装所有 Bot 相关 API 调用
///
/// 支持两种认证方式：
/// - PAT Token: 用于 OpenAPI v1 端点（/v1/bot/list, /v1/bots 等）
/// - Session Cookie: 用于内部 API 端点（/api/draftbot/* 等）
class BotRepository {
  final ApiGateway _api;

  BotRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // OpenAPI v1（PAT 认证）
  // ==========================================================================

  /// 获取 Bot 列表
  ///
  /// GET /v1/bot/list
  /// Query: space_id, page_index, page_size, keyword
  Future<ApiResponse<List<BotModel>>> fetchBotList({
    int pageIndex = 0,
    int pageSize = 20,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, String>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': pageIndex.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      final response = await _api.get(
        AppConfig.v1BotList,
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final botsRaw = data['bots'];
      if (botsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final bots = botsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => BotModel.fromV1List(e))
          .toList();

      return ApiResponse.ok(bots);
    } catch (e) {
      return ApiResponse.fail('获取 Bot 列表异常: ${e.toString()}');
    }
  }

  /// 获取 Bot 详情
  ///
  /// GET /v1/bots/:bot_id
  Future<ApiResponse<BotModel>> fetchBotDetail(String botId) async {
    try {
      final response = await _api.get(
        '/v1/bots/$botId',
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 详情失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('Bot 详情数据为空');
      }

      // v1 详情可能包在 data 字段中
      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final bot = BotModel.fromV1Detail(botData);
      return ApiResponse.ok(bot);
    } catch (e) {
      return ApiResponse.fail('获取 Bot 详情异常: ${e.toString()}');
    }
  }

  /// 创建 Bot
  ///
  /// POST /v1/bots
  Future<ApiResponse<BotModel>> createBot(BotModel bot) async {
    try {
      final body = bot.toCreateBody(spaceId: AppConfig.cozeStudioSpaceId);

      final response = await _api.post(
        '/v1/bots',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建 Bot 失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('创建 Bot 返回数据为空');
      }

      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final createdBot = BotModel.fromV1Detail(botData);
      return ApiResponse.ok(createdBot);
    } catch (e) {
      return ApiResponse.fail('创建 Bot 异常: ${e.toString()}');
    }
  }

  /// 更新 Bot
  ///
  /// PUT /v1/bots/:bot_id
  Future<ApiResponse<BotModel>> updateBot(String botId, BotModel bot) async {
    try {
      final body = bot.toUpdateBody();

      final response = await _api.put(
        '/v1/bots/$botId',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '更新 Bot 失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        // 更新成功但无返回数据，返回传入的 bot
        return ApiResponse.ok(bot);
      }

      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final updatedBot = BotModel.fromV1Detail(botData);
      return ApiResponse.ok(updatedBot);
    } catch (e) {
      return ApiResponse.fail('更新 Bot 异常: ${e.toString()}');
    }
  }

  /// 发布 Bot
  ///
  /// POST /v1/bots/publish
  Future<ApiResponse<Map<String, dynamic>>> publishBot(
    String botId, {
    String? versionDesc,
  }) async {
    try {
      final body = BotModel(
        id: botId,
        name: '',
      ).toPublishBody(
        spaceId: AppConfig.cozeStudioSpaceId,
        versionDesc: versionDesc,
      );

      final response = await _api.post(
        '/v1/bots/publish',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '发布 Bot 失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('发布 Bot 异常: ${e.toString()}');
    }
  }

  /// 删除 Bot（通过内部 API，需要 Session 认证）
  ///
  /// POST /api/draftbot/delete
  Future<ApiResponse<void>> deleteBot(String botId) async {
    try {
      final response = await _api.post(
        '/api/draftbot/delete',
        body: {'agent_id': botId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '删除 Bot 失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除 Bot 异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 内部 API（Session 认证）
  // ==========================================================================

  /// 获取 Bot 在线信息
  ///
  /// GET /v1/bot/get_online_info
  Future<ApiResponse<Map<String, dynamic>>> getBotOnlineInfo(String botId) async {
    try {
      final response = await _api.get(
        AppConfig.v1BotList.replaceAll('/list', '/get_online_info'),
        queryParams: {'bot_id': botId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 在线信息失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('获取 Bot 在线信息异常: ${e.toString()}');
    }
  }

  /// 通过内部 API 创建 Bot 草稿
  ///
  /// POST /api/draftbot/create
  Future<ApiResponse<BotModel>> createDraftBot(BotModel bot) async {
    try {
      final body = {
        'space_id': AppConfig.cozeStudioSpaceId,
        'name': bot.name,
        if (bot.description.isNotEmpty) 'description': bot.description,
        if (bot.iconUri != null) 'avatar_url': bot.iconUri,
        if (bot.prompt != null) 'prompt': bot.prompt,
        if (bot.modelInfo != null) 'model_info': bot.modelInfo,
      };

      final response = await _api.post(
        '/api/draftbot/create',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建草稿 Bot 失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('创建草稿 Bot 返回数据为空');
      }

      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final createdBot = BotModel.fromDraftBot(botData);
      return ApiResponse.ok(createdBot);
    } catch (e) {
      return ApiResponse.fail('创建草稿 Bot 异常: ${e.toString()}');
    }
  }

  /// 通过内部 API 获取 Bot 显示信息
  ///
  /// POST /api/draftbot/get_display_info
  Future<ApiResponse<BotModel>> getDraftBotDisplayInfo(String agentId) async {
    try {
      final response = await _api.post(
        '/api/draftbot/get_display_info',
        body: {'agent_id': agentId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 显示信息失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('Bot 显示信息数据为空');
      }

      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final bot = BotModel.fromDraftBot(botData);
      return ApiResponse.ok(bot);
    } catch (e) {
      return ApiResponse.fail('获取 Bot 显示信息异常: ${e.toString()}');
    }
  }

  /// 通过内部 API 更新 Bot 显示信息
  ///
  /// POST /api/draftbot/update_display_info
  Future<ApiResponse<void>> updateDraftBotDisplayInfo(
    String agentId,
    BotModel bot,
  ) async {
    try {
      final body = <String, dynamic>{
        'agent_id': agentId,
      };
      if (bot.name.isNotEmpty) body['name'] = bot.name;
      if (bot.description.isNotEmpty) body['description'] = bot.description;
      if (bot.iconUri != null) body['avatar_url'] = bot.iconUri;
      if (bot.prompt != null) body['prompt'] = bot.prompt;
      if (bot.modelInfo != null) body['model_info'] = bot.modelInfo;

      final response = await _api.post(
        '/api/draftbot/update_display_info',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '更新 Bot 显示信息失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('更新 Bot 显示信息异常: ${e.toString()}');
    }
  }

  /// 通过内部 API 发布 Bot 草稿
  ///
  /// POST /api/draftbot/publish
  Future<ApiResponse<Map<String, dynamic>>> publishDraftBot(
    String agentId, {
    String? versionDesc,
  }) async {
    try {
      final body = <String, dynamic>{
        'agent_id': agentId,
        if (versionDesc != null) 'version_desc': versionDesc,
      };

      final response = await _api.post(
        '/api/draftbot/publish',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '发布 Bot 失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('发布 Bot 异常: ${e.toString()}');
    }
  }

  /// 通过内部 API 复制 Bot
  ///
  /// POST /api/draftbot/duplicate
  Future<ApiResponse<BotModel>> duplicateBot(
    String agentId, {
    String? targetName,
  }) async {
    try {
      final body = <String, dynamic>{
        'agent_id': agentId,
        if (targetName != null) 'target_name': targetName,
      };

      final response = await _api.post(
        '/api/draftbot/duplicate',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '复制 Bot 失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      final botData = data?['data'] as Map<String, dynamic>? ?? data ?? {};
      final bot = BotModel.fromDraftBot(botData);
      return ApiResponse.ok(bot);
    } catch (e) {
      return ApiResponse.fail('复制 Bot 异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // bot-store-service 扩展 API
  // ==========================================================================

  /// 获取 Bot 商店列表
  ///
  /// GET http://36.134.216.154:8945/api/bots
  Future<ApiResponse<List<BotModel>>> fetchBotStoreList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      // bot-store-service 运行在 8945 端口
      final storeUrl = '${AppConfig.cozeStudioHost.replaceAll(':8888', ':8945')}/api/bots';
      final uri = Uri.parse(storeUrl).replace(queryParameters: queryParams);

      final response = await _api.get(
        uri.path,
        queryParams: queryParams,
        authType: CozeAuthType.none, // 商店列表可选认证
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 商店列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      final botsRaw = data?['bots'];
      if (botsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final bots = botsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => BotModel.fromBotStore(e))
          .toList();

      return ApiResponse.ok(bots);
    } catch (e) {
      return ApiResponse.fail('获取 Bot 商店列表异常: ${e.toString()}');
    }
  }

  /// 获取 Bot 商店详情
  ///
  /// GET http://36.134.216.154:8945/api/bots/:agent_id
  Future<ApiResponse<BotModel>> fetchBotStoreDetail(String agentId) async {
    try {
      final response = await _api.get(
        '/api/bots/$agentId',
        authType: CozeAuthType.none,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取 Bot 商店详情失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('Bot 商店详情数据为空');
      }

      final botData = data['data'] as Map<String, dynamic>? ?? data;
      final bot = BotModel.fromBotStore(botData);
      return ApiResponse.ok(bot);
    } catch (e) {
      return ApiResponse.fail('获取 Bot 商店详情异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 发布前检查
  // ==========================================================================

  /// 发布前检查
  ///
  /// POST /api/draftbot/commit_check
  Future<ApiResponse<Map<String, dynamic>>> commitCheck(String agentId) async {
    try {
      final response = await _api.post(
        '/api/draftbot/commit_check',
        body: {'agent_id': agentId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '发布前检查失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('发布前检查异常: ${e.toString()}');
    }
  }

  /// 获取发布渠道列表
  ///
  /// POST /api/draftbot/publish/connector/list
  Future<ApiResponse<List<Map<String, dynamic>>>> getPublishConnectors(
    String agentId,
  ) async {
    try {
      final response = await _api.post(
        '/api/draftbot/publish/connector/list',
        body: {'agent_id': agentId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取发布渠道列表失败',
            statusCode: response.statusCode);
      }

      final connectors = response.data?['connectors'];
      if (connectors is List) {
        return ApiResponse.ok(
          connectors.whereType<Map<String, dynamic>>().toList(),
        );
      }

      return ApiResponse.ok(const []);
    } catch (e) {
      return ApiResponse.fail('获取发布渠道列表异常: ${e.toString()}');
    }
  }
}

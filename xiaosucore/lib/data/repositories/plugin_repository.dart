// ============================================================================
// 小酥 v2 - 插件数据仓库层
// Phase 5: 封装 Coze Studio 插件 API 调用
// ============================================================================

import '../models/plugin_model.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 插件数据仓库 - 封装所有插件相关 API 调用
///
/// 支持三层 API：
/// - 内部 API (/api/plugin_api/*): Session 认证，完整插件 CRUD
/// - 内部 API (/api/marketplace_api/*): Session 认证，插件市场浏览
/// - 扩展服务 (/api/plugins/*): 可选认证，插件市场 service (8935 端口)
class PluginRepository {
  final ApiGateway _api;

  PluginRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // 插件列表查询
  // ==========================================================================

  /// 获取开发者插件列表（内部 API）
  ///
  /// POST /api/plugin_api/get_dev_plugin_list
  /// 返回当前空间下用户开发的插件列表
  Future<ApiResponse<List<PluginModel>>> fetchDevPluginList({
    int page = 0,
    int pageSize = 20,
    String? keyword,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': page,
        'page_size': pageSize,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      };

      final response = await _api.post(
        '/api/plugin_api/get_dev_plugin_list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取开发者插件列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final pluginsRaw = data?['plugin_list'] ?? data?['plugins'] ?? data?['data'];
      if (pluginsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final plugins = pluginsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PluginModel.fromCozeApi(e))
          .toList();

      return ApiResponse.ok(plugins);
    } catch (e) {
      return ApiResponse.fail('获取开发者插件列表异常: ${e.toString()}');
    }
  }

  /// 获取运行时插件列表（已安装 + 内置）
  ///
  /// POST /api/plugin_api/get_playground_plugin_list
  Future<ApiResponse<List<PluginModel>>> fetchPlaygroundPluginList() async {
    try {
      final body = {
        'space_id': AppConfig.cozeStudioSpaceId,
      };

      final response = await _api.post(
        '/api/plugin_api/get_playground_plugin_list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取运行时插件列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final pluginsRaw = data?['plugin_list'] ?? data?['plugins'] ?? data?['data'];
      if (pluginsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final plugins = pluginsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PluginModel.fromCozeApi(e))
          .toList();

      return ApiResponse.ok(plugins);
    } catch (e) {
      return ApiResponse.fail('获取运行时插件列表异常: ${e.toString()}');
    }
  }

  /// 获取插件市场产品列表（内部 API）
  ///
  /// GET /api/marketplace/product/list
  Future<ApiResponse<List<PluginModel>>> fetchMarketplacePluginList({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? sort,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;
      if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;

      final response = await _api.get(
        '/api/marketplace/product/list',
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取插件市场列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final productsRaw = data?['products'] ?? data?['data'] ?? data?['list'];
      if (productsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final plugins = productsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PluginModel.fromMarketplace(e))
          .toList();

      return ApiResponse.ok(plugins);
    } catch (e) {
      return ApiResponse.fail('获取插件市场列表异常: ${e.toString()}');
    }
  }

  /// 搜索插件市场
  ///
  /// GET /api/marketplace/product/search
  Future<ApiResponse<List<PluginModel>>> searchMarketplacePlugins(String keyword) async {
    try {
      final response = await _api.get(
        '/api/marketplace/product/search',
        queryParams: {'keyword': keyword},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '搜索插件市场失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final productsRaw = data?['products'] ?? data?['data'];
      if (productsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final plugins = productsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PluginModel.fromMarketplace(e))
          .toList();

      return ApiResponse.ok(plugins);
    } catch (e) {
      return ApiResponse.fail('搜索插件市场异常: ${e.toString()}');
    }
  }

  /// 获取插件市场分类列表
  ///
  /// GET /api/marketplace/product/category/list
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchPluginCategories() async {
    try {
      final response = await _api.get(
        '/api/marketplace/product/category/list',
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取插件分类列表失败',
          statusCode: response.statusCode,
        );
      }

      final categories = response.data?['categories'];
      if (categories is List) {
        return ApiResponse.ok(
          categories.whereType<Map<String, dynamic>>().toList(),
        );
      }

      return ApiResponse.ok(const []);
    } catch (e) {
      return ApiResponse.fail('获取插件分类列表异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 插件详情
  // ==========================================================================

  /// 获取插件详情（内部 API）
  ///
  /// POST /api/plugin_api/get_plugin_info
  Future<ApiResponse<PluginModel>> fetchPluginDetail(String pluginId) async {
    try {
      final response = await _api.post(
        '/api/plugin_api/get_plugin_info',
        body: {'plugin_id': pluginId, 'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取插件详情失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('插件详情数据为空');
      }

      final pluginData = data['data'] as Map<String, dynamic>? ?? data;
      final plugin = PluginModel.fromCozeApi(pluginData);
      return ApiResponse.ok(plugin);
    } catch (e) {
      return ApiResponse.fail('获取插件详情异常: ${e.toString()}');
    }
  }

  /// 获取市场插件详情
  ///
  /// GET /api/marketplace/product/detail
  Future<ApiResponse<PluginModel>> fetchMarketplacePluginDetail(String productId) async {
    try {
      final response = await _api.get(
        '/api/marketplace/product/detail',
        queryParams: {'product_id': productId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取市场插件详情失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final productData = data?['product'] as Map<String, dynamic>? ?? data?['data'] as Map<String, dynamic>? ?? data;
      if (productData == null) {
        return ApiResponse.fail('市场插件详情数据为空');
      }

      final plugin = PluginModel.fromMarketplace(productData);
      return ApiResponse.ok(plugin);
    } catch (e) {
      return ApiResponse.fail('获取市场插件详情异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 插件工具列表
  // ==========================================================================

  /// 获取插件下的工具列表
  ///
  /// POST /api/plugin_api/get_plugin_apis
  Future<ApiResponse<List<PluginTool>>> fetchPluginTools(String pluginId) async {
    try {
      final response = await _api.post(
        '/api/plugin_api/get_plugin_apis',
        body: {'plugin_id': pluginId, 'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取插件工具列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final toolsRaw = data?['apis'] ?? data?['tool_list'] ?? data?['tools'] ?? data?['data'];
      if (toolsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final tools = toolsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PluginTool.fromCozeApi(e))
          .toList();

      return ApiResponse.ok(tools);
    } catch (e) {
      return ApiResponse.fail('获取插件工具列表异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 插件调用
  // ==========================================================================

  /// 调用插件工具
  ///
  /// 通过内部 API 执行插件工具调用
  /// POST /api/conversation/chat 中使用 tool_use 消息类型，
  /// 或者通过 tool_proxy 服务直接调用
  Future<ApiResponse<Map<String, dynamic>>> invokePlugin({
    required String pluginId,
    required String toolName,
    required Map<String, dynamic> params,
    String? conversationId,
  }) async {
    try {
      // 通过 tool_proxy 调用插件
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'tool_name': toolName,
        'parameters': params,
        'space_id': AppConfig.cozeStudioSpaceId,
        if (conversationId != null) 'conversation_id': conversationId,
      };

      final response = await _api.post(
        '/api/tool_proxy/invoke',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '调用插件失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      return ApiResponse.ok(data ?? {});
    } catch (e) {
      return ApiResponse.fail('调用插件异常: ${e.toString()}');
    }
  }

  /// 通过 playground API 调用插件（运行时环境）
  ///
  /// POST /api/playground_api/invoke_plugin
  Future<ApiResponse<Map<String, dynamic>>> invokePluginViaPlayground({
    required String pluginId,
    required String toolName,
    required Map<String, dynamic> params,
  }) async {
    try {
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'tool_name': toolName,
        'parameters': params,
      };

      final response = await _api.post(
        '/api/playground_api/invoke_plugin',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '通过 playground 调用插件失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      return ApiResponse.ok(data ?? {});
    } catch (e) {
      return ApiResponse.fail('通过 playground 调用插件异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 自定义插件管理
  // ==========================================================================

  /// 注册自定义插件
  ///
  /// POST /api/plugin_api/register
  Future<ApiResponse<PluginModel>> registerPlugin({
    required String name,
    required String description,
    String? iconUrl,
    String? category,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'name': name,
        'description': description,
        if (iconUrl != null) 'icon_url': iconUrl,
        if (category != null) 'category': category,
      };

      final response = await _api.post(
        '/api/plugin_api/register',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '注册插件失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final pluginData = data?['data'] as Map<String, dynamic>? ?? data;
      if (pluginData == null) {
        return ApiResponse.fail('注册插件返回数据为空');
      }

      final plugin = PluginModel.fromCozeApi(pluginData);
      return ApiResponse.ok(plugin);
    } catch (e) {
      return ApiResponse.fail('注册插件异常: ${e.toString()}');
    }
  }

  /// 更新插件信息
  ///
  /// POST /api/plugin_api/update
  Future<ApiResponse<void>> updatePlugin(
    String pluginId, {
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'space_id': AppConfig.cozeStudioSpaceId,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (iconUrl != null) 'icon_url': iconUrl,
      };

      final response = await _api.post(
        '/api/plugin_api/update',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '更新插件失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('更新插件异常: ${e.toString()}');
    }
  }

  /// 删除插件
  ///
  /// POST /api/plugin_api/del_plugin
  Future<ApiResponse<void>> deletePlugin(String pluginId) async {
    try {
      final response = await _api.post(
        '/api/plugin_api/del_plugin',
        body: {'plugin_id': pluginId, 'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '删除插件失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除插件异常: ${e.toString()}');
    }
  }

  /// 发布插件
  ///
  /// POST /api/plugin_api/publish_plugin
  Future<ApiResponse<void>> publishPlugin(String pluginId) async {
    try {
      final response = await _api.post(
        '/api/plugin_api/publish_plugin',
        body: {'plugin_id': pluginId, 'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '发布插件失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('发布插件异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // API 管理（自定义插件的 API 定义）
  // ==========================================================================

  /// 创建插件 API
  ///
  /// POST /api/plugin_api/create_api
  Future<ApiResponse<Map<String, dynamic>>> createPluginApi({
    required String pluginId,
    required String apiName,
    required String description,
    required String method, // GET / POST / PUT / DELETE
    required String url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'space_id': AppConfig.cozeStudioSpaceId,
        'api_name': apiName,
        'description': description,
        'method': method.toUpperCase(),
        'url': url,
        if (headers != null) 'headers': headers,
        if (parameters != null) 'parameters': parameters,
      };

      final response = await _api.post(
        '/api/plugin_api/create_api',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '创建插件 API 失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('创建插件 API 异常: ${e.toString()}');
    }
  }

  /// 批量创建插件 API
  ///
  /// POST /api/plugin_api/batch_create_api
  Future<ApiResponse<void>> batchCreatePluginApis(
    String pluginId,
    List<Map<String, dynamic>> apiDefinitions,
  ) async {
    try {
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'space_id': AppConfig.cozeStudioSpaceId,
        'apis': apiDefinitions,
      };

      final response = await _api.post(
        '/api/plugin_api/batch_create_api',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '批量创建插件 API 失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('批量创建插件 API 异常: ${e.toString()}');
    }
  }

  /// 调试插件 API
  ///
  /// POST /api/plugin_api/debug_api
  Future<ApiResponse<Map<String, dynamic>>> debugPluginApi({
    required String pluginId,
    required String apiId,
    required Map<String, dynamic> params,
  }) async {
    try {
      final body = <String, dynamic>{
        'plugin_id': pluginId,
        'api_id': apiId,
        'parameters': params,
        'space_id': AppConfig.cozeStudioSpaceId,
      };

      final response = await _api.post(
        '/api/plugin_api/debug_api',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '调试插件 API 失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('调试插件 API 异常: ${e.toString()}');
    }
  }

  /// 将插件 API 转换为 OpenAPI 格式
  ///
  /// POST /api/plugin_api/convert_to_openapi
  Future<ApiResponse<Map<String, dynamic>>> convertToOpenApi(String pluginId) async {
    try {
      final response = await _api.post(
        '/api/plugin_api/convert_to_openapi',
        body: {'plugin_id': pluginId, 'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '转换 OpenAPI 失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('转换 OpenAPI 异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 市场收藏/复制
  // ==========================================================================

  /// 收藏市场产品（安装机制）
  Future<ApiResponse<void>> favoriteMarketProduct(String productId) async {
    try {
      final response = await _api.post(
        '/api/marketplace/product/favorite',
        body: {'product_id': productId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '收藏市场产品失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('收藏市场产品异常: ${e.toString()}');
    }
  }

  /// 复制市场产品到自有空间
  Future<ApiResponse<PluginModel>> duplicateMarketProduct(String productId) async {
    try {
      final response = await _api.post(
        '/api/marketplace/product/duplicate',
        body: {'product_id': productId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '复制市场产品失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final pluginData = data?['data'] as Map<String, dynamic>? ?? data;
      if (pluginData == null) {
        return ApiResponse.fail('复制市场产品返回数据为空');
      }

      final plugin = PluginModel.fromCozeApi(pluginData);
      return ApiResponse.ok(plugin);
    } catch (e) {
      return ApiResponse.fail('复制市场产品异常: ${e.toString()}');
    }
  }
}
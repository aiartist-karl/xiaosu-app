// ============================================================================
// 小酥 - 插件市场
// Phase 5: 扩展对接 Coze Studio 插件 API
// - 保留原有内置插件管理能力
// - 新增 Coze Studio 插件同步、调用、自定义插件支持
// ============================================================================

import '../skill/skill.dart';
import '../skill/skill_registry.dart';
import '../../data/models/plugin_model.dart';
import '../../data/repositories/plugin_repository.dart';

/// 插件信息（本地内置）
class PluginInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String category;
  final String icon;
  final bool installed;
  final bool official;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author = '小酥官方',
    this.category = '通用',
    this.icon = '📦',
    this.installed = false,
    this.official = true,
  });
}

/// 插件市场
///
/// 管理能力：
/// 1. 本地内置插件（离线可用）
/// 2. Coze Studio 远程插件（需网络连接）
/// 3. 自定义插件（用户创建的插件）
/// 4. 插件市场浏览与安装
class PluginMarket {
  static final PluginMarket instance = PluginMarket._();
  PluginMarket._();

  // 插件仓库
  final PluginRepository _repo = PluginRepository();

  // ==========================================================================
  // 内置插件列表
  // ==========================================================================

  final List<PluginInfo> _plugins = [
    const PluginInfo(id: 'image_gen', name: '图片生成', description: 'AI生成图片', icon: '🎨', category: '创作', installed: true),
    const PluginInfo(id: 'tts', name: '语音合成', description: '文字转语音', icon: '🔊', category: '多媒体', installed: true),
    const PluginInfo(id: 'web_search', name: '网络搜索', description: '联网搜索信息', icon: '🔍', category: '工具', installed: true),
    const PluginInfo(id: 'email', name: '邮件助手', description: '发送邮件', icon: '📧', category: '办公', installed: true),
    const PluginInfo(id: 'lark', name: '飞书集成', description: '飞书消息与文档', icon: '🐦', category: '办公', installed: true),
    const PluginInfo(id: 'social', name: '社交媒体', description: '社交平台管理', icon: '📱', category: '社交', installed: false),
    const PluginInfo(id: 'video', name: '视频生成', description: 'AI生成视频', icon: '🎬', category: '创作', installed: false),
    const PluginInfo(id: 'podcast', name: '播客制作', description: '生成播客音频', icon: '🎙️', category: '创作', installed: true),
    const PluginInfo(id: 'tracking', name: '话题追踪', description: '持续追踪话题动态', icon: '📡', category: '工具', installed: true),
    const PluginInfo(id: 'forbidden_word', name: '违禁词检测', description: '检测平台违禁词', icon: '⚠️', category: '安全', installed: true),
    const PluginInfo(id: 'cloud_sync', name: '云同步', description: '数据云端同步', icon: '☁️', category: '工具', installed: true),
    const PluginInfo(id: 'browser', name: '浏览器', description: '网页浏览与自动化', icon: '🌐', category: '工具', installed: false),
    const PluginInfo(id: 'chart', name: '图表生成', description: '生成数据图表', icon: '📊', category: '创作', installed: true),
    const PluginInfo(id: 'doc_gen', name: '文档生成', description: '生成Word/PDF文档', icon: '📄', category: '创作', installed: true),
    const PluginInfo(id: 'code_sandbox', name: '代码沙箱', description: '安全执行代码', icon: '💻', category: '开发', installed: false),
    const PluginInfo(id: 'pro_domain', name: '专业领域', description: '专业领域知识库', icon: '🎓', category: '知识', installed: true),
  ];

  // ==========================================================================
  // Coze Studio 远程插件状态
  // ==========================================================================

  /// Coze Studio 插件缓存（plugin_id -> PluginModel）
  final Map<String, PluginModel> _cozePluginCache = {};

  /// Coze Studio 自定义插件缓存
  final Map<String, PluginModel> _customPluginCache = {};

  /// 是否已同步远程插件
  bool _isSynced = false;

  /// Coze 插件是否可用（已连接 Coze Studio）
  bool get isCozeAvailable => _isSynced && _cozePluginCache.isNotEmpty;

  // ==========================================================================
  // 本地插件管理（向后兼容）
  // ==========================================================================

  /// 获取所有本地插件
  List<PluginInfo> get allPlugins => List.unmodifiable(_plugins);

  /// 获取已安装本地插件
  List<PluginInfo> get installedPlugins => _plugins.where((p) => p.installed).toList();

  /// 获取未安装本地插件
  List<PluginInfo> get availablePlugins => _plugins.where((p) => !p.installed).toList();

  /// 安装本地插件
  Future<bool> install(String pluginId) async {
    final idx = _plugins.indexWhere((p) => p.id == pluginId);
    if (idx == -1) return false;
    _plugins[idx] = PluginInfo(
      id: _plugins[idx].id, name: _plugins[idx].name,
      description: _plugins[idx].description, version: _plugins[idx].version,
      author: _plugins[idx].author, category: _plugins[idx].category,
      icon: _plugins[idx].icon, installed: true, official: _plugins[idx].official,
    );
    return true;
  }

  /// 卸载本地插件
  Future<bool> uninstall(String pluginId) async {
    final idx = _plugins.indexWhere((p) => p.id == pluginId);
    if (idx == -1) return false;
    _plugins[idx] = PluginInfo(
      id: _plugins[idx].id, name: _plugins[idx].name,
      description: _plugins[idx].description, version: _plugins[idx].version,
      author: _plugins[idx].author, category: _plugins[idx].category,
      icon: _plugins[idx].icon, installed: false, official: _plugins[idx].official,
    );
    return true;
  }

  /// 搜索本地插件
  List<PluginInfo> search(String query) {
    final q = query.toLowerCase();
    return _plugins.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q)
    ).toList();
  }

  // ==========================================================================
  // Coze Studio 插件同步
  // ==========================================================================

  /// 同步 Coze Studio 插件列表到本地缓存
  ///
  /// 从 Coze Studio 拉取：
  /// 1. 运行时插件（已安装 + 已启用）
  /// 2. 开发者自定义插件
  Future<bool> syncCozePlugins() async {
    try {
      // 1. 获取运行时插件
      final playgroundResult = await _repo.fetchPlaygroundPluginList();
      if (playgroundResult.success && playgroundResult.data != null) {
        for (final plugin in playgroundResult.data!) {
          _cozePluginCache[plugin.id] = plugin;
        }
      }

      // 2. 获取开发者自定义插件
      final devResult = await _repo.fetchDevPluginList();
      if (devResult.success && devResult.data != null) {
        for (final plugin in devResult.data!) {
          if (plugin.sourceType == PluginSourceType.custom) {
            _customPluginCache[plugin.id] = plugin;
          }
          _cozePluginCache[plugin.id] = plugin;
        }
      }

      _isSynced = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取所有 Coze Studio 插件（含缓存）
  List<PluginModel> get cozePlugins =>
      _cozePluginCache.values.toList();

  /// 获取 Coze Studio 自定义插件
  List<PluginModel> get customPlugins =>
      _customPluginCache.values.toList();

  /// 获取所有插件（本地 + Coze 远程）
  List<PluginModel> get allCozeAndCustomPlugins {
    final all = <String, PluginModel>{};
    all.addAll(_cozePluginCache);
    all.addAll(_customPluginCache);
    return all.values.toList();
  }

  // ==========================================================================
  // Coze Studio 插件市场浏览
  // ==========================================================================

  /// 浏览插件市场（从 Coze Studio marketplace 获取）
  Future<List<PluginModel>> browseMarketplace({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? keyword,
    String? sort,
  }) async {
    try {
      final result = await _repo.fetchMarketplacePluginList(
        page: page,
        pageSize: pageSize,
        category: category,
        keyword: keyword,
        sort: sort,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 搜索插件市场
  Future<List<PluginModel>> searchMarketplace(String keyword) async {
    try {
      final result = await _repo.searchMarketplacePlugins(keyword);
      if (result.success && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 获取插件分类列表
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final result = await _repo.fetchPluginCategories();
      if (result.success && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================================================
  // 插件详情与调用
  // ==========================================================================

  /// 获取插件详情（优先缓存，否则从 API 获取）
  Future<PluginModel?> getPluginDetail(String pluginId) async {
    // 先查缓存
    if (_cozePluginCache.containsKey(pluginId)) {
      return _cozePluginCache[pluginId];
    }
    if (_customPluginCache.containsKey(pluginId)) {
      return _customPluginCache[pluginId];
    }

    // 从 API 获取
    try {
      final result = await _repo.fetchPluginDetail(pluginId);
      if (result.success && result.data != null) {
        _cozePluginCache[pluginId] = result.data!;
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 获取插件下的工具列表
  Future<List<PluginTool>> getPluginTools(String pluginId) async {
    // 先查缓存
    final cached = _cozePluginCache[pluginId];
    if (cached != null && cached.tools.isNotEmpty) {
      return cached.tools;
    }

    // 从 API 获取
    try {
      final result = await _repo.fetchPluginTools(pluginId);
      if (result.success && result.data != null) {
        // 更新缓存
        if (cached != null) {
          _cozePluginCache[pluginId] = cached.copyWith(tools: result.data!);
        }
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 调用 Coze Studio 插件工具
  ///
  /// 流程：
  /// 1. 从缓存或 API 获取插件详情
  /// 2. 使用 PluginModel.prepareInvoke 进行参数验证
  /// 3. 通过 PluginRepository 发起调用
  /// 4. 返回调用结果
  Future<PluginInvokeResult> invokeCozePlugin({
    required String pluginId,
    required String toolName,
    required Map<String, dynamic> params,
    String? conversationId,
  }) async {
    try {
      // 获取插件详情
      final plugin = await getPluginDetail(pluginId);
      if (plugin == null) {
        return PluginInvokeResult.error('插件 "$pluginId" 不存在');
      }

      // 参数验证
      final invokeResult = plugin.prepareInvoke(toolName, params);
      if (!invokeResult.isSuccess) {
        return invokeResult; // 参数校验失败
      }

      // 发起调用
      final result = await _repo.invokePlugin(
        pluginId: pluginId,
        toolName: toolName,
        params: params,
        conversationId: conversationId,
      );

      if (result.success) {
        return PluginInvokeResult.success(result.data ?? {});
      } else {
        return PluginInvokeResult.error(result.error ?? '插件调用失败');
      }
    } catch (e) {
      return PluginInvokeResult.error('插件调用异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 自定义插件管理
  // ==========================================================================

  /// 注册自定义插件
  Future<PluginModel?> registerCustomPlugin({
    required String name,
    required String description,
    String? iconUrl,
    String? category,
  }) async {
    try {
      final result = await _repo.registerPlugin(
        name: name,
        description: description,
        iconUrl: iconUrl,
        category: category,
      );

      if (result.success && result.data != null) {
        _customPluginCache[result.data!.id] = result.data!;
        _cozePluginCache[result.data!.id] = result.data!;
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 更新自定义插件
  Future<bool> updateCustomPlugin(
    String pluginId, {
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    try {
      final result = await _repo.updatePlugin(
        pluginId,
        name: name,
        description: description,
        iconUrl: iconUrl,
      );

      if (result.success) {
        // 更新缓存
        final cached = _customPluginCache[pluginId];
        if (cached != null) {
          _customPluginCache[pluginId] = cached.copyWith(
            name: name,
            description: description,
            iconUrl: iconUrl,
          );
        }
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  /// 删除自定义插件
  Future<bool> deleteCustomPlugin(String pluginId) async {
    try {
      final result = await _repo.deletePlugin(pluginId);
      if (result.success) {
        _customPluginCache.remove(pluginId);
        _cozePluginCache.remove(pluginId);
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  /// 发布自定义插件到市场
  Future<bool> publishCustomPlugin(String pluginId) async {
    try {
      final result = await _repo.publishPlugin(pluginId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// 为自定义插件添加 API 工具
  Future<bool> addCustomPluginTool({
    required String pluginId,
    required String toolName,
    required String description,
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final result = await _repo.createPluginApi(
        pluginId: pluginId,
        apiName: toolName,
        description: description,
        method: method,
        url: url,
        headers: headers,
        parameters: parameters,
      );

      if (result.success) {
        // 刷新插件工具缓存
        _cozePluginCache.remove(pluginId);
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  // ==========================================================================
  // 插件安装（从市场安装到 Coze Studio）
  // ==========================================================================

  /// 从市场收藏/安装插件
  Future<bool> favoriteMarketPlugin(String productId) async {
    try {
      final result = await _repo.favoriteMarketProduct(productId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// 复制市场插件到自有空间
  Future<PluginModel?> duplicateMarketPlugin(String productId) async {
    try {
      final result = await _repo.duplicateMarketProduct(productId);
      if (result.success && result.data != null) {
        _cozePluginCache[result.data!.id] = result.data!;
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ==========================================================================
  // 综合查询
  // ==========================================================================

  /// 全局搜索（本地 + Coze 远程）
  List<Map<String, dynamic>> searchAll(String query) {
    final q = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    // 搜索本地插件
    for (final p in _plugins) {
      if (p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q)) {
        results.add({
          'source': 'builtin',
          'plugin': p,
          'name': p.name,
          'description': p.description,
          'icon': p.icon,
          'category': p.category,
        });
      }
    }

    // 搜索 Coze 远程插件
    for (final p in _cozePluginCache.values) {
      if (p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q)) {
        results.add({
          'source': p.sourceType == PluginSourceType.custom ? 'custom' : 'coze',
          'plugin': p,
          'name': p.name,
          'description': p.description,
          'icon': p.iconUrl ?? '🔌',
          'category': p.category,
        });
      }
    }

    return results;
  }

  /// 获取插件统计信息
  Map<String, dynamic> get stats => {
    'builtin_total': _plugins.length,
    'builtin_installed': _plugins.where((p) => p.installed).length,
    'coze_total': _cozePluginCache.length,
    'custom_total': _customPluginCache.length,
    'is_synced': _isSynced,
  };

  /// 清除缓存
  void clearCache() {
    _cozePluginCache.clear();
    _customPluginCache.clear();
    _isSynced = false;
  }
}

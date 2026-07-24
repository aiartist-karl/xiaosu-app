// ============================================================================
// 小酥 - 插件市场
// ============================================================================

import '../skill/skill.dart';
import '../skill/skill_registry.dart';

/// 插件信息
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
class PluginMarket {
  static final PluginMarket instance = PluginMarket._();
  PluginMarket._();

  // 内置插件列表
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

  /// 获取所有插件
  List<PluginInfo> get allPlugins => List.unmodifiable(_plugins);

  /// 获取已安装插件
  List<PluginInfo> get installedPlugins => _plugins.where((p) => p.installed).toList();

  /// 获取可用插件
  List<PluginInfo> get availablePlugins => _plugins.where((p) => !p.installed).toList();

  /// 安装插件
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

  /// 卸载插件
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

  /// 搜索插件
  List<PluginInfo> search(String query) {
    final q = query.toLowerCase();
    return _plugins.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q)
    ).toList();
  }
}

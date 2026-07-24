// ============================================================================
// 小酥 - 插件市场（对接后端版）
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../skill/skill.dart';
import '../skill/skill_registry.dart';
import '../services/agent_api_service.dart';
import '../../config/app_config.dart';

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

/// 后端工具映射
class BackendTool {
  final String name;
  final String description;
  final bool enabled;

  const BackendTool({required this.name, required this.description, this.enabled = true});
}

/// 插件市场 - 对接后端真实工具
class PluginMarket {
  static final PluginMarket instance = PluginMarket._();
  PluginMarket._();

  final AgentApiService _agentApi = AgentApiService.instance;
  final http.Client _client = http.Client();

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

  // 后端工具缓存
  List<BackendTool> _backendTools = [];
  bool _backendLoaded = false;

  /// 获取所有插件
  List<PluginInfo> get allPlugins => List.unmodifiable(_plugins);

  /// 获取已安装插件
  List<PluginInfo> get installedPlugins => _plugins.where((p) => p.installed).toList();

  /// 获取可用插件
  List<PluginInfo> get availablePlugins => _plugins.where((p) => !p.installed).toList();

  /// 获取后端工具列表
  List<BackendTool> get backendTools => List.unmodifiable(_backendTools);

  /// 后端工具是否已加载
  bool get isBackendLoaded => _backendLoaded;

  /// 从后端获取真实工具列表
  Future<bool> fetchFromBackend() async {
    try {
      final response = await _client
          .get(Uri.parse('${AppConfig.agentApiBase}/api/health'),
              headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tools = data['tools'] as List<dynamic>? ?? [];

        _backendTools = tools.map((t) {
          final name = t is String ? t : (t as Map)['name'] as String? ?? 'unknown';
          return BackendTool(
            name: name,
            description: _toolDescription(name),
            enabled: true,
          );
        }).toList();

        _backendLoaded = true;

        // 同步更新本地插件的installed状态
        for (int i = 0; i < _plugins.length; i++) {
          final plugin = _plugins[i];
          final isAvailable = _backendTools.any((t) => t.name == plugin.id);
          if (isAvailable != plugin.installed) {
            _plugins[i] = PluginInfo(
              id: plugin.id, name: plugin.name, description: plugin.description,
              version: plugin.version, author: plugin.author, category: plugin.category,
              icon: plugin.icon, installed: isAvailable, official: plugin.official,
            );
          }
        }

        return true;
      }
    } catch (_) {
      // fallback到本地数据
    }
    return false;
  }

  /// 安装插件
  Future<bool> install(String pluginId) async {
    final idx = _plugins.indexWhere((p) => p.id == pluginId);
    if (idx == -1) return false;

    // 尝试通知后端
    try {
      await _notifyBackend('enable', pluginId);
    } catch (_) {
      // 后端不可达，仅本地更新
    }

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

    // 尝试通知后端
    try {
      await _notifyBackend('disable', pluginId);
    } catch (_) {}

    _plugins[idx] = PluginInfo(
      id: _plugins[idx].id, name: _plugins[idx].name,
      description: _plugins[idx].description, version: _plugins[idx].version,
      author: _plugins[idx].author, category: _plugins[idx].category,
      icon: _plugins[idx].icon, installed: false, official: _plugins[idx].official,
    );
    return true;
  }

  /// 通知后端启用/禁用工具
  Future<void> _notifyBackend(String action, String pluginId) async {
    // 发送chat消息通知后端（通过AgentAPI）
    final message = action == 'enable'
        ? '启用插件: $pluginId'
        : '禁用插件: $pluginId';
    // 通过现有的API通道通知
    await _agentApi.sendMessage(
      conversationId: 'system_plugin_mgr',
      message: message,
    ).drain();
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

  /// 工具描述映射
  String _toolDescription(String name) {
    const map = {
      'bash_execute': '执行Shell命令', 'bash_background': '后台执行命令',
      'task_status': '查看后台任务状态', 'file_read': '读取文件', 'file_write': '写入文件',
      'file_list': '列出目录', 'create_file': '创建文件', 'edit_file': '编辑文件',
      'create_directory': '创建目录', 'delete_file': '删除文件', 'code_search': '搜索代码',
      'file_search': '搜索文件', 'web_search': '网络搜索', 'web_fetch': '获取网页',
      'github_api': 'GitHub操作', 'git_push': 'Git推送', 'image_generate': '生成图片',
      'email_send': '发送邮件', 'calendar_create': '创建日历', 'calendar_list': '查看日历',
      'memory_save': '保存记忆', 'memory_search': '搜索记忆', 'memory_list': '列出记忆',
      'code_analysis': '代码分析', 'system_info': '系统信息',
    };
    return map[name] ?? '工具: $name';
  }

  void dispose() {
    _client.close();
  }
}

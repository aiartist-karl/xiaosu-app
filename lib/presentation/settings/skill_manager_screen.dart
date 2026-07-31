// ============================================================================
// 小酥 - 技能管理页面（对接后端插件 API）
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/gateway/api_gateway.dart';
import '../../data/repositories/plugin_repository.dart';
import '../../data/models/plugin_model.dart';

/// 技能管理页面
class SkillManagerScreen extends StatefulWidget {
  const SkillManagerScreen({super.key});

  @override
  State<SkillManagerScreen> createState() => _SkillManagerScreenState();
}

class _SkillManagerScreenState extends State<SkillManagerScreen> {
  final PluginRepository _pluginRepo = PluginRepository(ApiGateway.instance);
  List<PluginModel> _plugins = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _pluginRepo.fetchPlaygroundPluginList();
      if (response.success && response.data != null) {
        setState(() {
          _plugins = response.data!;
          _loading = false;
        });
      } else {
        setState(() {
          _error = response.message ?? '加载失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络错误：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlugins,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPlugins,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _plugins.isEmpty
                  ? const Center(child: Text('暂无可用技能'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _plugins.length,
                      itemBuilder: (context, index) {
                        final plugin = _plugins[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                _getPluginIcon(plugin.name),
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            title: Text(plugin.name),
                            subtitle: Text(
                              plugin.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                            onTap: () => _showPluginDetail(plugin),
                          ),
                        );
                      },
                    ),
    );
  }

  String _getPluginIcon(String name) {
    const icons = {
      '搜索': '🔍', '翻译': '🌐', '天气': '🌤️',
      '新闻': '📰', '地图': '️', '音乐': '🎵',
      '视频': '🎬', '图片': '🖼️', '文档': '📄',
      '代码': '💻', '邮件': '📧', '日历': '📅',
      '提醒': '⏰', '笔记': '', '文件': '',
    };
    for (final entry in icons.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return '⚙️';
  }

  void _showPluginDetail(PluginModel plugin) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plugin.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(plugin.description),
            const SizedBox(height: 16),
            if (plugin.tools.isNotEmpty)
              Text('包含 ${plugin.tools.length} 个工具', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

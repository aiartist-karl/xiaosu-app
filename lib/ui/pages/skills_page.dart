// ============================================================================
// 小酥 (XiaoSu) - 技能管理页（完整版）
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/skill/skill_registry.dart';
import '../../core/skill/skill.dart';
import '../../core/services/agent_api_service.dart';

/// 技能页 —— 查看和管理已注册技能 + 后端工具
class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> with SingleTickerProviderStateMixin {
  final SkillRegistry _registry = SkillRegistry.instance;
  final AgentApiService _agentApi = AgentApiService.instance;
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  // 后端工具列表
  static const List<Map<String, String>> _backendTools = [
    {'name': 'bash_execute', 'desc': '执行Shell命令', 'icon': '💻', 'category': '系统'},
    {'name': 'bash_background', 'desc': '后台执行命令', 'icon': '⚙️', 'category': '系统'},
    {'name': 'task_status', 'desc': '查看后台任务状态', 'icon': '📋', 'category': '系统'},
    {'name': 'file_read', 'desc': '读取文件内容', 'icon': '📖', 'category': '文件'},
    {'name': 'file_write', 'desc': '写入文件内容', 'icon': '📝', 'category': '文件'},
    {'name': 'file_list', 'desc': '列出目录文件', 'icon': '📂', 'category': '文件'},
    {'name': 'create_file', 'desc': '创建新文件', 'icon': '📄', 'category': '文件'},
    {'name': 'edit_file', 'desc': '编辑文件内容', 'icon': '✏️', 'category': '文件'},
    {'name': 'create_directory', 'desc': '创建目录', 'icon': '📁', 'category': '文件'},
    {'name': 'delete_file', 'desc': '删除文件或目录', 'icon': '🗑️', 'category': '文件'},
    {'name': 'code_search', 'desc': '搜索代码内容', 'icon': '🔎', 'category': '代码'},
    {'name': 'file_search', 'desc': '搜索文件名', 'icon': '🔍', 'category': '代码'},
    {'name': 'web_search', 'desc': '联网搜索信息', 'icon': '🌐', 'category': '网络'},
    {'name': 'web_fetch', 'desc': '获取网页内容', 'icon': '📡', 'category': '网络'},
    {'name': 'github_api', 'desc': 'GitHub API操作', 'icon': '🐙', 'category': '网络'},
    {'name': 'git_push', 'desc': 'Git提交推送', 'icon': '📤', 'category': '网络'},
    {'name': 'image_generate', 'desc': 'AI生成图片', 'icon': '🎨', 'category': '创作'},
    {'name': 'email_send', 'desc': '发送邮件', 'icon': '📧', 'category': '办公'},
    {'name': 'calendar_create', 'desc': '创建日历事件', 'icon': '📅', 'category': '办公'},
    {'name': 'calendar_list', 'desc': '查看日历事件', 'icon': '🗓️', 'category': '办公'},
    {'name': 'memory_save', 'desc': '保存记忆', 'icon': '💾', 'category': '记忆'},
    {'name': 'memory_search', 'desc': '搜索记忆', 'icon': '🧠', 'category': '记忆'},
    {'name': 'memory_list', 'desc': '列出记忆', 'icon': '📋', 'category': '记忆'},
    {'name': 'code_analysis', 'desc': '代码分析', 'icon': '🔬', 'category': '代码'},
    {'name': 'system_info', 'desc': '系统信息', 'icon': '🖥️', 'category': '系统'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索技能或工具...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('技能管理'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '本地技能 (${_registry.length})'),
            Tab(text: '后端工具 (${_backendTools.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSkillsTab(),
          _buildBackendToolsTab(),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    final skills = _searchQuery.isNotEmpty
        ? _registry.search(_searchQuery)
        : _registry.allSkills;

    if (skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.extension_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的技能' : '暂无已注册技能',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: skill.enabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.grey.shade200,
              child: Text(_getSkillIcon(skill.skillId), style: const TextStyle(fontSize: 18)),
            ),
            title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(skill.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: skill.enabled ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    skill.enabled ? '启用' : '禁用',
                    style: TextStyle(
                      fontSize: 11,
                      color: skill.enabled ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: skill.enabled,
                  onChanged: (v) {
                    setState(() => skill.enabled = v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v ? '已启用 ${skill.name}' : '已禁用 ${skill.name}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackendToolsTab() {
    final tools = _searchQuery.isNotEmpty
        ? _backendTools.where((t) =>
            t['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t['desc']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t['category']!.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList()
        : _backendTools;

    // Group by category
    final categories = <String, List<Map<String, String>>>{};
    for (final tool in tools) {
      final cat = tool['category']!;
      categories.putIfAbsent(cat, () => []);
      categories[cat]!.add(tool);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: categories.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...entry.value.map((tool) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: ListTile(
                  dense: true,
                  leading: Text(tool['icon']!, style: const TextStyle(fontSize: 22)),
                  title: Text(tool['name']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  subtitle: Text(tool['desc']!, style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('可用', style: TextStyle(fontSize: 10, color: Colors.green)),
                  ),
                  onTap: () {
                    _showToolDetail(context, tool);
                  },
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  void _showToolDetail(BuildContext context, Map<String, String> tool) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tool['icon']!, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tool['name']!, style: Theme.of(ctx).textTheme.titleMedium),
                      Text(tool['desc']!, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('分类: ${tool['category']}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text('状态: 已连接后端', style: TextStyle(fontSize: 14, color: Colors.green.shade700)),
            const SizedBox(height: 8),
            Text(
              '该工具由后端Agent服务器提供，通过SSE流式通信与APP交互。',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getSkillIcon(String skillId) {
    const icons = {
      'image_gen': '🎨', 'tts': '🔊', 'web_search': '🔍',
      'email': '📧', 'lark': '🐦', 'social': '📱',
      'video': '🎬', 'podcast': '🎙️', 'pro_domain': '🎓',
      'forbidden_word': '⚠️', 'cloud_sync': '☁️', 'tracking': '📡',
      'browser': '🌐', 'chart': '📊', 'doc_gen': '📄',
      'code_sandbox': '💻',
    };
    return icons[skillId] ?? '⚙️';
  }
}

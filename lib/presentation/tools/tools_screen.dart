// ============================================================================
// 小酥 - 工具集界面（全部接真实后端API）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/agent_api_service.dart';
import '../files/file_manager_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final AgentApiService _api = AgentApiService.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具集'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildToolCard(context,
            icon: Icons.calendar_today, color: Colors.orange,
            title: '日历管理', subtitle: '查看和创建日历事件',
            onTap: () => _showCalendarTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(context,
            icon: Icons.folder, color: Colors.green,
            title: '文件管理', subtitle: '浏览和下载服务器文件',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FileManagerScreen()));
            },
          ),
          const SizedBox(height: 12),
          _buildToolCard(context,
            icon: Icons.memory, color: Colors.purple,
            title: '记忆管理', subtitle: '查看、搜索和管理AI记忆',
            onTap: () => _showMemoryTools(context),
          ),
          const SizedBox(height: 12),
          _buildToolCard(context,
            icon: Icons.search, color: Colors.teal,
            title: '网页搜索', subtitle: '搜索互联网获取信息',
            onTap: () { Navigator.pop(context); _goNewChat('帮我搜索'); },
          ),
          const SizedBox(height: 12),
          _buildToolCard(context,
            icon: Icons.image, color: Colors.pink,
            title: '图片生成', subtitle: '使用AI生成图片',
            onTap: () { Navigator.pop(context); _goNewChat('帮我生成一张图片'); },
          ),
          const SizedBox(height: 12),
          _buildToolCard(context,
            icon: Icons.code, color: Colors.brown,
            title: '代码执行', subtitle: '在沙箱中执行代码',
            onTap: () { Navigator.pop(context); _goNewChat('帮我执行代码'); },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, {
    required IconData icon, required Color color,
    required String title, required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }

  void _showCalendarTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('日历管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.orange),
                title: const Text('查看日程'),
                subtitle: const Text('查看后端日历事件'),
                onTap: () { Navigator.pop(context); _loadCalendarEvents(); },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.orange),
                title: const Text('创建日程'),
                subtitle: const Text('通过对话让AI创建日历事件'),
                onTap: () { Navigator.pop(context); _goNewChat('帮我创建一个日程'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemoryTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('记忆管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list, color: Colors.purple),
                title: const Text('查看所有记忆'),
                subtitle: const Text('列出AI已保存的记忆'),
                onTap: () { Navigator.pop(context); _loadMemories(); },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.purple),
                title: const Text('搜索记忆'),
                subtitle: const Text('搜索AI已记住的信息'),
                onTap: () { Navigator.pop(context); _showMemorySearchDialog(); },
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.purple),
                title: const Text('添加记忆'),
                subtitle: const Text('通过对话告诉AI需要记住的信息'),
                onTap: () { Navigator.pop(context); _goNewChat('请记住以下信息'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadCalendarEvents() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getCalendar(days: 7);
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        final events = (result['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _showCalendarDialog(events);
      } else {
        _showErrorDialog('获取日历失败: ${result['error']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('网络错误: $e');
    }
  }

  void _showCalendarDialog(List<Map<String, dynamic>> events) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('未来7天日程'),
        content: SizedBox(
          width: double.maxFinite,
          child: events.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无日程安排'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (ctx, i) {
                    final e = events[i];
                    return ListTile(
                      leading: const Icon(Icons.event, color: Colors.orange),
                      title: Text(e['title']?.toString() ?? ''),
                      subtitle: Text('${e['dtstart']?.toString() ?? ''}'),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getMemories();
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        final memories = (result['memories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _showMemoryDialog(memories);
      } else {
        _showErrorDialog('获取记忆失败: ${result['error']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('网络错误: $e');
    }
  }

  void _showMemoryDialog(List<Map<String, dynamic>> memories) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI记忆'),
        content: SizedBox(
          width: double.maxFinite,
          child: memories.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无记忆'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: memories.length,
                  itemBuilder: (ctx, i) {
                    final m = memories[i];
                    return ListTile(
                      leading: const Icon(Icons.memory, color: Colors.purple),
                      title: Text(m['key']?.toString() ?? ''),
                      subtitle: Text(m['content']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  void _showMemorySearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('搜索记忆'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入关键词...', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final query = controller.text.trim();
              if (query.isEmpty) return;
              setState(() => _isLoading = true);
              try {
                final result = await _api.searchMemory(query);
                setState(() => _isLoading = false);
                if (result['success'] == true) {
                  final results = (result['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                  _showSearchResultsDialog(results);
                } else {
                  _showErrorDialog('搜索失败');
                }
              } catch (e) {
                setState(() => _isLoading = false);
                _showErrorDialog('搜索错误: $e');
              }
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  void _showSearchResultsDialog(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('搜索结果 (${results.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('未找到相关记忆'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    final r = results[i];
                    return ListTile(
                      leading: const Icon(Icons.memory, color: Colors.purple),
                      title: Text(r['key']?.toString() ?? ''),
                      subtitle: Text(r['content']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('错误'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定'))],
      ),
    );
  }

  void _goNewChat([String? hint]) {
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    context.push('/chat/$id');
  }
}

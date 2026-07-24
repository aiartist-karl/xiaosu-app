import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tools = [];
  List<Map<String, dynamic>> _plugins = [];
  Set<String> _installedPlugins = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 获取后端工具列表
      final response = await http.get(
        Uri.parse('${AppConfig.agentApiBase}/api/tools'),
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _tools = List<Map<String, dynamic>>.from(data['tools'] ?? []);
      }
      // 加载本地插件状态
      _loadPluginState();
    } catch (e) {
      // 使用默认工具列表
      _tools = _getDefaultTools();
    }
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _getDefaultTools() {
    return [
      {'name': 'bash_execute', 'description': '执行Shell命令', 'category': '系统'},
      {'name': 'file_read', 'description': '读取文件', 'category': '文件'},
      {'name': 'file_write', 'description': '写入文件', 'category': '文件'},
      {'name': 'file_list', 'description': '列出目录', 'category': '文件'},
      {'name': 'code_search', 'description': '搜索代码', 'category': '开发'},
      {'name': 'git_push', 'description': 'Git提交推送', 'category': '开发'},
      {'name': 'web_search', 'description': '联网搜索', 'category': '网络'},
      {'name': 'web_fetch', 'description': '抓取网页', 'category': '网络'},
      {'name': 'github_actions', 'description': 'GitHub Actions', 'category': '开发'},
      {'name': 'create_file', 'description': '创建文件', 'category': '文件'},
      {'name': 'edit_file', 'description': '编辑文件', 'category': '文件'},
    ];
  }

  void _loadPluginState() {
    // 从本地存储加载已安装的插件
    _plugins = [
      {'name': '代码助手', 'desc': '智能代码补全和重构建议', 'icon': Icons.code, 'category': '开发'},
      {'name': '文件管理', 'desc': '浏览和管理服务器文件', 'icon': Icons.folder, 'category': '工具'},
      {'name': '日程管理', 'desc': '创建和查看日程安排', 'icon': Icons.calendar_today, 'category': '效率'},
      {'name': '记忆系统', 'desc': 'AI记忆管理，记住你的偏好', 'icon': Icons.memory, 'category': 'AI'},
      {'name': '网络搜索', 'desc': '实时联网搜索信息', 'icon': Icons.search, 'category': '网络'},
      {'name': '终端执行', 'desc': '远程执行Shell命令', 'icon': Icons.terminal, 'category': '系统'},
      {'name': '数据库查询', 'desc': 'SQL数据库查询和管理', 'icon': Icons.storage, 'category': '数据'},
      {'name': '邮件发送', 'desc': '通过SMTP发送邮件', 'icon': Icons.email, 'category': '通讯'},
    ];
    // 默认全部已安装
    _installedPlugins = _plugins.map((p) => p['name'] as String).toSet();
  }

  void _togglePlugin(String name) {
    setState(() {
      if (_installedPlugins.contains(name)) {
        _installedPlugins.remove(name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name 已卸载'), duration: const Duration(seconds: 1)),
        );
      } else {
        _installedPlugins.add(name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name 已安装'), duration: const Duration(seconds: 1)),
        );
      }
    });
  }

  Future<void> _executeTool(String name) async {
    final argController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('执行: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: argController,
              decoration: const InputDecoration(labelText: '参数 (JSON格式)', hintText: '{"key": "value"}'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, argController.text),
            child: const Text('执行'),
          ),
        ],
      ),
    );

    if (result != null) {
      Map<String, dynamic> args = {};
      try {
        if (result.isNotEmpty) args = jsonDecode(result);
      } catch (_) {}

      try {
        final response = await http.post(
          Uri.parse('${AppConfig.agentApiBase}/api/tools/execute'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.agentAuthToken}',
          },
          body: jsonEncode({'name': name, 'arguments': args}),
        );
        final data = jsonDecode(response.body);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('执行结果'),
              content: SingleChildScrollView(
                child: Text(data['result']?.toString() ?? '无返回', style: const TextStyle(fontSize: 13)),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('执行失败: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工具与插件'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '内置工具', icon: Icon(Icons.build)),
            Tab(text: '插件商店', icon: Icon(Icons.apps)),
            Tab(text: '执行记录', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: 内置工具
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tools.length,
                  itemBuilder: (ctx, i) {
                    final tool = _tools[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(Icons.build, color: Colors.blue[700], size: 20),
                        ),
                        title: Text(tool['name']?.toString() ?? ''),
                        subtitle: Text(tool['description']?.toString() ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _executeTool(tool['name']?.toString() ?? ''),
                        ),
                      ),
                    );
                  },
                ),
                // Tab 2: 插件商店
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plugins.length,
                  itemBuilder: (ctx, i) {
                    final plugin = _plugins[i];
                    final name = plugin['name'] as String;
                    final installed = _installedPlugins.contains(name);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: installed ? Colors.green[100] : Colors.grey[200],
                          child: Icon(
                            plugin['icon'] as IconData? ?? Icons.extension,
                            color: installed ? Colors.green[700] : Colors.grey,
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(plugin['desc']?.toString() ?? ''),
                        trailing: Switch(
                          value: installed,
                          onChanged: (_) => _togglePlugin(name),
                          activeColor: Colors.green,
                        ),
                      ),
                    );
                  },
                ),
                // Tab 3: 执行记录
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无执行记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('使用工具后记录将显示在这里', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

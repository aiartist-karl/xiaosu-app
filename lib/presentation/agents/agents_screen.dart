import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/agents'),
        headers: {'Authorization': 'Bearer ${AppConfig.authToken}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _agents = List<Map<String, dynamic>>.from(data['agents'] ?? []);
          _loading = false;
        });
      } else {
        setState(() { _error = '加载失败: ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = '网络错误: $e'; _loading = false; });
    }
  }

  Future<void> _createAgent() async {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建新Agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: '角色')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: '描述'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'name': nameController.text,
                'role': roleController.text,
                'description': descController.text,
              });
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/agents'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.authToken}',
          },
          body: jsonEncode(result),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          _loadAgents();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent创建成功')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }

  Future<void> _deleteAgent(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个Agent吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await http.delete(
          Uri.parse('${AppConfig.baseUrl}/api/agents/$id'),
          headers: {'Authorization': 'Bearer ${AppConfig.authToken}'},
        );
        _loadAgents();
      } catch (e) {
        // ignore
      }
    }
  }

  void _assignTask(String agentName) {
    final taskController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('分配任务给 $agentName'),
        content: TextField(
          controller: taskController,
          decoration: const InputDecoration(labelText: '任务描述'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('任务已分配给 $agentName')),
              );
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('多Agent管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAgents),
          IconButton(icon: const Icon(Icons.add), onPressed: _createAgent),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadAgents,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 统计卡片
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      // Agent列表
                      ..._agents.map((agent) => _buildAgentCard(agent)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsCard() {
    final total = _agents.length;
    final active = _agents.where((a) => a['status'] == 'active' || a['status'] == 'running').length;
    final idle = total - active;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('总览统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem('总数', total.toString(), Colors.blue),
                _buildStatItem('活跃', active.toString(), Colors.green),
                _buildStatItem('空闲', idle.toString(), Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            // 可视化条形图
            if (total > 0) ...[
              const Text('Agent状态分布', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: active / total,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                  minHeight: 24,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('活跃 ${(active / total * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('空闲 ${(idle / total * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final name = agent['name'] as String? ?? 'Unknown';
    final role = agent['role'] as String? ?? '';
    final desc = agent['description'] as String? ?? '';
    final status = agent['status'] as String? ?? 'idle';
    final tasks = agent['tasks_completed'] as int? ?? 0;
    final id = agent['id'] as String? ?? '';
    final isActive = status == 'active' || status == 'running';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey[300],
                  child: Icon(
                    isActive ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (role.isNotEmpty) Text(role, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? '活跃' : '空闲',
                    style: TextStyle(fontSize: 11, color: isActive ? Colors.green[800] : Colors.grey[700]),
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 12),
            // 任务统计
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.blue[400]),
                const SizedBox(width: 4),
                Text('已完成: $tasks 个任务', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _assignTask(name),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('分配任务'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _deleteAgent(id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 小酥 - 多Agent协作管理页（对接真实后端API + 任务分配 + 可视化）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/agent_api_service.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> with SingleTickerProviderStateMixin {
  final AgentApiService _api = AgentApiService.instance;
  List<Map<String, dynamic>> _agents = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final result = await _api.getAgents();
      if (result['success'] == true) {
        final list = (result['agents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() { _agents = list; _isLoading = false; });
      } else {
        setState(() { _errorMessage = result['error'] ?? '加载失败'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = '网络错误: $e'; _isLoading = false; });
    }
  }

  Future<void> _createAgent() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建新Agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Agent名称', hintText: '如：代码审查Agent', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', hintText: '描述这个Agent的职责', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: promptCtrl, decoration: const InputDecoration(labelText: '系统提示词', hintText: '定义Agent的行为和能力', border: OutlineInputBorder()), maxLines: 4),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'system_prompt': promptCtrl.text.trim(),
            }),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      final createResult = await _api.createAgent(
        name: result['name']!,
        description: result['description'] ?? '',
        systemPrompt: result['system_prompt'] ?? '',
      );
      if (createResult['success'] == true) {
        _loadAgents();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent创建成功')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: ${createResult['error']}')));
      }
    }
  }

  Future<void> _deleteAgent(String agentId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除Agent'),
        content: Text('确定删除"$name"吗？相关任务数据将被清除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _api.deleteAgent(agentId);
      if (result['success'] == true) {
        _loadAgents();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: ${result['error']}')));
      }
    }
  }

  void _assignTask(String agentId, String agentName) {
    final taskCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('分配任务给 $agentName'),
        content: TextField(
          controller: taskCtrl,
          decoration: const InputDecoration(hintText: '描述任务内容...', border: OutlineInputBorder()),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final task = taskCtrl.text.trim();
              if (task.isNotEmpty) {
                _executeTask(agentId, agentName, task);
              }
            },
            child: const Text('分配'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTask(String agentId, String agentName, String task) async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.executeTool(name: 'assign_task', arguments: {'agent_id': agentId, 'task': task});
      setState(() => _isLoading = false);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('任务已分配给 $agentName')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('任务分配失败: ${result['error']}')));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误: $e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': case 'running': return Colors.green;
      case 'idle': return Colors.grey;
      case 'error': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'active': return '运行中';
      case 'idle': return '空闲';
      case 'error': return '异常';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent协作'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAgents, tooltip: '刷新')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(_errorMessage, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _loadAgents, icon: const Icon(Icons.refresh), label: const Text('重试')),
                  ]),
                )
              : _agents.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.psychology, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('还没有Agent', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('创建Agent来协作完成复杂任务', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        const SizedBox(height: 24),
                        FilledButton.icon(onPressed: _createAgent, icon: const Icon(Icons.add), label: const Text('创建Agent')),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAgents,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildStatsCard()),
                          SliverToBoxAdapter(child: const SizedBox(height: 12)),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(children: [
                                Text('已注册Agent', style: Theme.of(context).textTheme.titleMedium),
                                const Spacer(),
                                Text('${_agents.length}个', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ]),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildAgentCard(index),
                                childCount: _agents.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createAgent,
        tooltip: '创建Agent',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsCard() {
    final activeCount = _agents.where((a) => a['status'] == 'active' || a['status'] == 'running').length;
    final idleCount = _agents.where((a) => a['status'] == 'idle').length;
    final errorCount = _agents.where((a) => a['status'] == 'error').length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.hub, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('协作概览', style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _StatCard('总Agent', '${_agents.length}', Colors.blue),
                const SizedBox(width: 8),
                _StatCard('运行中', '$activeCount', Colors.green),
                const SizedBox(width: 8),
                _StatCard('空闲', '$idleCount', Colors.grey),
                const SizedBox(width: 8),
                _StatCard('异常', '$errorCount', Colors.red),
              ]),
              const SizedBox(height: 16),
              // 状态条形图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Row(children: [
                    if (activeCount > 0) Expanded(flex: activeCount, child: Container(color: Colors.green)),
                    if (idleCount > 0) Expanded(flex: idleCount, child: Container(color: Colors.grey.shade400)),
                    if (errorCount > 0) Expanded(flex: errorCount, child: Container(color: Colors.red)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text('点击Agent卡片可分配任务，实现多Agent协作', style: TextStyle(fontSize: 12, color: Colors.blueGrey))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard(int index) {
    final agent = _agents[index];
    final id = agent['id']?.toString() ?? '';
    final name = agent['name']?.toString() ?? '未命名';
    final desc = agent['description']?.toString() ?? '';
    final status = agent['status']?.toString() ?? 'idle';
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _assignTask(id, name),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(id.contains('main') ? Icons.psychology : Icons.smart_toy, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(_statusText(status), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _assignTask(id, name),
                    icon: const Icon(Icons.assignment, size: 16),
                    label: const Text('分配任务', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => _deleteAgent(id, name),
                  tooltip: '删除',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

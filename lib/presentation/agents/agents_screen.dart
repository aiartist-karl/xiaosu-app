// ============================================================================
// 小酥 - 多Agent协作管理页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// Agent模型定义
class AgentModel {
  final String id;
  final String name;
  final String description;
  final String status;
  final String systemPrompt;
  final int taskCount;
  final DateTime createdAt;

  AgentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.systemPrompt = '',
    this.taskCount = 0,
    required this.createdAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '未命名Agent',
      description: json['description'] ?? '',
      status: json['status'] ?? 'idle',
      systemPrompt: json['system_prompt'] ?? '',
      taskCount: json['task_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'status': status,
    'system_prompt': systemPrompt,
    'task_count': taskCount,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Agent管理页面
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  final ApiGateway _api = ApiGateway.instance;
  List<AgentModel> _agents = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _api.get(
        '/api/agents',
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success && response.data != null) {
        final list = response.data!['agents'] as List? ?? [];
        setState(() {
          _agents = list
              .map((e) => AgentModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _isLoading = false;
        });
      } else {
        // 离线模式 - 使用本地数据
        setState(() {
          _agents = _localAgents;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _agents = _localAgents;
        _isLoading = false;
        _errorMessage = '离线模式';
      });
    }
  }

  // 本地默认Agent
  final List<AgentModel> _localAgents = [
    AgentModel(
      id: 'agent_main',
      name: '小酥主Agent',
      description: '主调度Agent，负责对话和任务分发',
      status: 'active',
      systemPrompt: '你是小酥主Agent，负责协调子Agent完成复杂任务',
      taskCount: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    AgentModel(
      id: 'agent_code',
      name: '代码助手',
      description: '专注于代码编写和审查的子Agent',
      status: 'idle',
      systemPrompt: '你是代码专家，擅长编写、审查和优化代码',
      taskCount: 8,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    AgentModel(
      id: 'agent_research',
      name: '研究员',
      description: '联网搜索和信息整理的子Agent',
      status: 'idle',
      systemPrompt: '你是研究助手，擅长搜索、整理和分析信息',
      taskCount: 5,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

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
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agent名称',
                  hintText: '如：代码审查Agent',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '描述',
                  hintText: '描述这个Agent的职责',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptCtrl,
                decoration: const InputDecoration(
                  labelText: '系统提示词',
                  hintText: '定义Agent的行为和能力',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
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
      final newAgent = AgentModel(
        id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
        name: result['name']!,
        description: result['description'] ?? '',
        status: 'idle',
        systemPrompt: result['system_prompt'] ?? '',
        taskCount: 0,
        createdAt: DateTime.now(),
      );

      // 尝试同步到后端
      try {
        await _api.post(
          '/api/agents',
          body: newAgent.toJson(),
          headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
        );
      } catch (_) {}

      setState(() => _agents.add(newAgent));
    }
  }

  Future<void> _deleteAgent(int index) async {
    final agent = _agents[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除Agent'),
        content: Text('确定删除"${agent.name}"吗？相关任务数据将被清除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.delete(
          '/api/agents/${agent.id}',
          headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
        );
      } catch (_) {}

      setState(() => _agents.removeAt(index));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
      case 'running':
        return Colors.green;
      case 'idle':
        return Colors.grey;
      case 'error':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'active':
        return '运行中';
      case 'idle':
        return '空闲';
      case 'error':
        return '异常';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent协作'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAgents,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _agents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('还没有Agent', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('创建Agent来协作完成复杂任务', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _createAgent,
                        icon: const Icon(Icons.add),
                        label: const Text('创建Agent'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAgents,
                  child: CustomScrollView(
                    slivers: [
                      // 协作架构概览
                      SliverToBoxAdapter(
                        child: _buildArchitectureCard(),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                '已注册Agent',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Text(
                                '${_agents.length}个',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
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

  Widget _buildArchitectureCard() {
    final activeCount = _agents.where((a) => a.status == 'active' || a.status == 'running').length;
    final totalTasks = _agents.fold<int>(0, (sum, a) => sum + a.taskCount);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('协作架构', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat('总Agent', '${_agents.length}', Colors.blue),
                  const SizedBox(width: 12),
                  _MiniStat('运行中', '$activeCount', Colors.green),
                  const SizedBox(width: 12),
                  _MiniStat('已完成任务', '$totalTasks', Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '主Agent可分发任务给子Agent，子Agent执行完成后结果回调主Agent',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard(int index) {
    final agent = _agents[index];
    final statusColor = _statusColor(agent.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/agent-task/${agent.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(
                      agent.id == 'agent_main' ? Icons.psychology : Icons.smart_toy,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agent.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusText(agent.status),
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.task_alt, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${agent.taskCount}个任务', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(_formatTime(agent.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const Spacer(),
                  if (agent.status != 'active' && agent.status != 'running')
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      onPressed: () => _activateAgent(index),
                      tooltip: '激活',
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _deleteAgent(index),
                    tooltip: '删除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _MiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _activateAgent(int index) {
    setState(() {
      _agents[index] = AgentModel(
        id: _agents[index].id,
        name: _agents[index].name,
        description: _agents[index].description,
        status: 'active',
        systemPrompt: _agents[index].systemPrompt,
        taskCount: _agents[index].taskCount,
        createdAt: _agents[index].createdAt,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_agents[index].name} 已激活'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}

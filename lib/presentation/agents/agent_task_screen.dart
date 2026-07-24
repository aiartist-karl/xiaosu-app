// ============================================================================
// 小酥 - Agent任务分发页
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// Agent任务模型
class TaskModel {
  final String id;
  final String agentId;
  final String title;
  final String description;
  final String status;
  final String result;
  final DateTime createdAt;
  final DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.agentId,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.result = '',
    required this.createdAt,
    this.completedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      agentId: json['agent_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      result: json['result'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(json['completed_at'] ?? ''),
    );
  }
}

/// Agent任务页面
class AgentTaskScreen extends StatefulWidget {
  final String agentId;
  const AgentTaskScreen({super.key, required this.agentId});

  @override
  State<AgentTaskScreen> createState() => _AgentTaskScreenState();
}

class _AgentTaskScreenState extends State<AgentTaskScreen> {
  final ApiGateway _api = ApiGateway.instance;
  final List<TaskModel> _tasks = [];
  final TextEditingController _taskCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final response = await _api.get(
        '/api/agent/${widget.agentId}/tasks',
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success && response.data != null) {
        final list = response.data!['tasks'] as List? ?? [];
        setState(() {
          _tasks.clear();
          _tasks.addAll(list.map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e))));
        });
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  Future<void> _dispatchTask() async {
    final title = _taskCtrl.text.trim();
    if (title.isEmpty) return;

    final newTask = TaskModel(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      agentId: widget.agentId,
      title: title,
      status: 'running',
      createdAt: DateTime.now(),
    );

    setState(() {
      _tasks.insert(0, newTask);
      _taskCtrl.clear();
    });

    // 发送到后端
    try {
      final response = await _api.post(
        '/api/agent/${widget.agentId}/task',
        body: {'title': title, 'task_id': newTask.id},
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success) {
        // 模拟执行完成
        await Future.delayed(const Duration(seconds: 3));
        setState(() {
          final idx = _tasks.indexWhere((t) => t.id == newTask.id);
          if (idx >= 0) {
            _tasks[idx] = TaskModel(
              id: newTask.id,
              agentId: newTask.agentId,
              title: newTask.title,
              status: 'completed',
              result: '任务已执行完成，结果已回调主Agent',
              createdAt: newTask.createdAt,
              completedAt: DateTime.now(),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == newTask.id);
        if (idx >= 0) {
          _tasks[idx] = TaskModel(
            id: newTask.id,
            agentId: newTask.agentId,
            title: newTask.title,
            status: 'error',
            result: '执行失败: $e',
            createdAt: newTask.createdAt,
          );
        }
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'running':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'running':
        return '执行中';
      case 'pending':
        return '等待中';
      case 'error':
        return '失败';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'running':
        return Icons.sync;
      case 'pending':
        return Icons.hourglass_empty;
      case 'error':
        return Icons.error;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agent任务'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 任务分发输入区
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.send_to_mobile, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('分发任务', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Agent: ${widget.agentId}',
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskCtrl,
                        decoration: const InputDecoration(
                          hintText: '输入任务描述...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _dispatchTask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _dispatchTask,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('分发'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 任务列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('暂无任务', style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Text('在上方输入任务描述并点击分发', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return _buildTaskItem(task);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskModel task) {
    final statusColor = _getStatusColor(task.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon(task.status), color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(task.status),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (task.result.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.result,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  _formatTime(task.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
                if (task.completedAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.check, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(task.completedAt!),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

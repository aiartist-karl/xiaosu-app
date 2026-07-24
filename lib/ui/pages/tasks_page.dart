// ============================================================================
// 小酥 (XiaoSu) - 任务管理页（完整版）
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/task/task_scheduler.dart';
import '../../models/task_model.dart';

/// 任务页 —— 查看和管理定时任务 / 话题追踪
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TaskScheduler _scheduler = TaskScheduler.instance;
  List<TaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _tasks = _scheduler.getAllTasks();
    });
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskType selectedType = TaskType.custom;
    int intervalMinutes = 60;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    hintText: '例如：每日新闻摘要',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '任务描述',
                    hintText: '描述任务要做什么',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: '任务类型',
                    border: OutlineInputBorder(),
                  ),
                  items: TaskType.values
                      .where((t) => t != TaskType.workflow)
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_typeName(t)),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: intervalMinutes,
                  decoration: const InputDecoration(
                    labelText: '执行间隔',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 15, child: Text('每15分钟')),
                    const DropdownMenuItem(value: 30, child: Text('每30分钟')),
                    const DropdownMenuItem(value: 60, child: Text('每1小时')),
                    const DropdownMenuItem(value: 360, child: Text('每6小时')),
                    const DropdownMenuItem(value: 1440, child: Text('每天')),
                  ],
                  onChanged: (v) => setDialogState(() => intervalMinutes = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                _scheduler.addTask(TaskModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  type: selectedType,
                  createdAt: DateTime.now(),
                  interval: Duration(minutes: intervalMinutes),
                  nextExecutionAt: DateTime.now().add(Duration(minutes: intervalMinutes)),
                  status: TaskStatus.idle,
                ));
                Navigator.pop(ctx);
                _loadTasks();
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  String _typeName(TaskType t) {
    switch (t) {
      case TaskType.scheduled: return '定时任务';
      case TaskType.topicTracking: return '话题追踪';
      case TaskType.reminder: return '提醒';
      case TaskType.workflow: return '工作流';
      case TaskType.custom: return '自定义';
    }
  }

  String _statusName(TaskStatus s) {
    switch (s) {
      case TaskStatus.idle: return '空闲';
      case TaskStatus.running: return '运行中';
      case TaskStatus.paused: return '已暂停';
      case TaskStatus.completed: return '已完成';
      case TaskStatus.failed: return '失败';
      case TaskStatus.cancelled: return '已取消';
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.idle: return Colors.blue;
      case TaskStatus.running: return Colors.green;
      case TaskStatus.paused: return Colors.orange;
      case TaskStatus.completed: return Colors.teal;
      case TaskStatus.failed: return Colors.red;
      case TaskStatus.cancelled: return Colors.grey;
    }
  }

  IconData _statusIcon(TaskStatus s) {
    switch (s) {
      case TaskStatus.idle: return Icons.schedule;
      case TaskStatus.running: return Icons.play_circle;
      case TaskStatus.paused: return Icons.pause_circle;
      case TaskStatus.completed: return Icons.check_circle;
      case TaskStatus.failed: return Icons.error;
      case TaskStatus.cancelled: return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('暂无任务', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('点击右下角按钮创建新任务', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _loadTasks(),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Dismissible(
                    key: Key(task.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      _scheduler.removeTask(task.id);
                      _loadTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已删除任务: ${task.name}')),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_statusIcon(task.status), color: _statusColor(task.status), size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    task.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(task.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _statusName(task.status),
                                    style: TextStyle(fontSize: 11, color: _statusColor(task.status)),
                                  ),
                                ),
                              ],
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (task.nextExecutionAt != null)
                                  Expanded(
                                    child: Text(
                                      '⏰ 下次执行: ${_formatTime(task.nextExecutionAt!)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                if (task.lastExecutedAt != null)
                                  Text(
                                    '上次: ${_formatTime(task.lastExecutedAt!)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('类型: ${_typeName(task.type)} · 执行${task.executionCount}次',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const Spacer(),
                                if (task.status == TaskStatus.running || task.status == TaskStatus.idle)
                                  TextButton.icon(
                                    onPressed: () {
                                      _scheduler.pauseTask(task.id);
                                      _loadTasks();
                                    },
                                    icon: const Icon(Icons.pause, size: 16),
                                    label: const Text('暂停', style: TextStyle(fontSize: 12)),
                                  ),
                                if (task.status == TaskStatus.paused)
                                  TextButton.icon(
                                    onPressed: () {
                                      _scheduler.resumeTask(task.id);
                                      _loadTasks();
                                    },
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text('恢复', style: TextStyle(fontSize: 12)),
                                  ),
                                TextButton.icon(
                                  onPressed: () async {
                                    _scheduler.runTaskNow(task.id);
                                    _loadTasks();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('已触发: ${task.name}')),
                                    );
                                  },
                                  icon: const Icon(Icons.flash_on, size: 16),
                                  label: const Text('立即执行', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: '新建任务',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) {
      return '${diff.inMinutes.abs()}分钟前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟后';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时后';
    } else {
      return '${diff.inDays}天后';
    }
  }
}

// ============================================================================
// 小酥 - 工作流编辑器
// ============================================================================

import 'package:flutter/material.dart';

/// 工作流编辑器
class WorkflowEditorScreen extends StatefulWidget {
  const WorkflowEditorScreen({super.key});

  @override
  State<WorkflowEditorScreen> createState() => _WorkflowEditorScreenState();
}

class _WorkflowEditorScreenState extends State<WorkflowEditorScreen> {
  final List<Map<String, dynamic>> _nodes = [];
  String _workflowName = '未命名工作流';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workflowName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '运行工作流',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('工作流运行中...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('工作流已保存')),
              );
            },
          ),
        ],
      ),
      body: _nodes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔄', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('暂无工作流节点', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('点击下方按钮添加节点', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _nodes.length,
              itemBuilder: (context, index) {
                final node = _nodes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(node['icon'] as String? ?? '⚙️'),
                    ),
                    title: Text(node['name'] as String? ?? '节点'),
                    subtitle: Text(node['description'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() => _nodes.removeAt(index));
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNodeDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('添加节点'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _nodes.add({'name': '输入', 'description': '接收用户输入', 'icon': '📥'}));
              Navigator.pop(context);
            },
            child: const ListTile(leading: Text('📥'), title: Text('输入节点')),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _nodes.add({'name': 'LLM处理', 'description': '调用大语言模型', 'icon': '🧠'}));
              Navigator.pop(context);
            },
            child: const ListTile(leading: Text('🧠'), title: Text('LLM节点')),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _nodes.add({'name': '技能执行', 'description': '执行指定技能', 'icon': '⚡'}));
              Navigator.pop(context);
            },
            child: const ListTile(leading: Text('⚡'), title: Text('技能节点')),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _nodes.add({'name': '条件判断', 'description': '根据条件分支', 'icon': '🔀'}));
              Navigator.pop(context);
            },
            child: const ListTile(leading: Text('🔀'), title: Text('条件节点')),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _nodes.add({'name': '输出', 'description': '返回结果', 'icon': '📤'}));
              Navigator.pop(context);
            },
            child: const ListTile(leading: Text('📤'), title: Text('输出节点')),
          ),
        ],
      ),
    );
  }
}

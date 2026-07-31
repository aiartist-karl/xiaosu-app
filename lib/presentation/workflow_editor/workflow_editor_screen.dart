// ============================================================================
// 小酥 - 工作流编辑器（对接后端 API）
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/workflow_repository.dart';
import '../../data/models/workflow_model.dart';
import '../../core/gateway/api_gateway.dart';

/// 工作流编辑器
class WorkflowEditorScreen extends StatefulWidget {
  final String? workflowId;

  const WorkflowEditorScreen({super.key, this.workflowId});

  @override
  State<WorkflowEditorScreen> createState() => _WorkflowEditorScreenState();
}

class _WorkflowEditorScreenState extends State<WorkflowEditorScreen> {
  final WorkflowRepository _workflowRepo = WorkflowRepository(ApiGateway.instance);
  WorkflowModel? _workflow;
  bool _isLoading = true;
  String _workflowName = '未命名工作流';
  final List<Map<String, dynamic>> _nodes = [];

  @override
  void initState() {
    super.initState();
    if (widget.workflowId != null) {
      _loadWorkflow();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkflow() async {
    setState(() => _isLoading = true);
    try {
      final wf = await _workflowRepo.fetchWorkflowDetail(widget.workflowId!);
      if (wf.isSuccess && wf.data != null && mounted) {
        setState(() {
          _workflow = wf.data;
          _workflowName = wf.data!.name;
          // Parse nodes from workflow data
          _nodes.clear();
          if (wf.data!.data != null && wf.data!.data!['nodes'] is List) {
            for (var node in wf.data!.data!['nodes']) {
              _nodes.add(Map<String, dynamic>.from(node));
            }
          }
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        if (!wf.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败：${wf.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    }
  }

  Future<void> _saveWorkflow() async {
    if (_workflow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建工作流')),
      );
      return;
    }

    try {
      // Update workflow data with nodes
      final data = _workflow!.data ?? {};
      data['nodes'] = _nodes;

      await _workflowRepo.saveWorkflowCanvas(
        workflowId: _workflow!.workflowId,
        name: _workflowName,
        description: _workflow!.description ?? '',
        spaceId: _workflow!.spaceId,
        data: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('工作流已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  Future<void> _runWorkflow() async {
    if (_workflow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建工作流')),
      );
      return;
    }

    try {
      final result = await _workflowRepo.runWorkflow(
        workflowId: _workflow!.workflowId,
        parameters: {},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('运行结果：$result')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('运行失败：$e')),
        );
      }
    }
  }

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
            onPressed: _runWorkflow,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _saveWorkflow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
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

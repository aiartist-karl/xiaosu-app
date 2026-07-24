// ============================================================================
// 小酥 - 项目编辑器（对接后端真实数据）
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class ProjectEditorScreen extends StatefulWidget {
  final String projectId;

  const ProjectEditorScreen({super.key, required this.projectId});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _config = {};

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    setState(() { _loading = true; });
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.agentApiBase}/api/projects/${widget.projectId}'),
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _config = data;
          _nameController.text = data['name']?.toString() ?? '';
          _descController.text = data['description']?.toString() ?? '';
          _promptController.text = data['system_prompt']?.toString() ?? '';
          _loading = false;
        });
      } else {
        setState(() { _loading = false; });
      }
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  Future<void> _saveProject() async {
    setState(() { _saving = true; });
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.agentApiBase}/api/projects/${widget.projectId}'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.agentAuthToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameController.text,
          'description': _descController.text,
          'system_prompt': _promptController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.statusCode == 200 ? '保存成功' : '保存失败: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑项目'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProject,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 项目名称
                _buildSection('项目名称', TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: '输入项目名称', border: OutlineInputBorder()),
                )),
                const SizedBox(height: 20),

                // 项目描述
                _buildSection('项目描述', TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '描述项目目标和功能', border: OutlineInputBorder()),
                )),
                const SizedBox(height: 20),

                // 系统提示词
                _buildSection('AI系统提示词', TextField(
                  controller: _promptController,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: '设置AI在此项目中的行为...', border: OutlineInputBorder()),
                )),
                const SizedBox(height: 20),

                // 模型选择
                _buildSection('模型配置', DropdownButtonFormField<String>(
                  value: _config['model']?.toString() ?? 'deepseek-chat',
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'deepseek-chat', child: Text('DeepSeek Chat')),
                    DropdownMenuItem(value: 'deepseek-reasoner', child: Text('DeepSeek Reasoner')),
                    DropdownMenuItem(value: 'gpt-4', child: Text('GPT-4')),
                  ],
                  onChanged: (v) { if (v != null) setState(() { _config['model'] = v; }); },
                )),
                const SizedBox(height: 20),

                // 删除项目
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('删除项目', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      child,
    ]);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: const Text('删除后无法恢复，确定要删除吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

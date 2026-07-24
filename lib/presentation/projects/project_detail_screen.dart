// ============================================================================
// 小酥 - 项目详情页（对接后端数据）
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../core/services/agent_api_service.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({super.key, required this.projectId, required this.projectName});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _files = [];
  Map<String, dynamic>? _projectInfo;
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProjectData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 从后端加载项目数据
  Future<void> _loadProjectData() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.agentApiBase}/api/projects/${widget.projectId}'),
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _projectInfo = data;
          _files = List<Map<String, dynamic>>.from(data['files'] ?? []);
          _recentActivity = List<Map<String, dynamic>>.from(data['recent_activity'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = '加载失败: HTTP ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      // 后端没有项目API时，显示空状态
      setState(() {
        _error = '';
        _loading = false;
        _projectInfo = {'name': widget.projectName, 'id': widget.projectId, 'created_at': DateTime.now().toIso8601String()};
        _files = [];
        _recentActivity = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProjectData),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showProjectMenu(context)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined), text: '文件'),
            Tab(icon: Icon(Icons.settings_outlined), text: '配置'),
            Tab(icon: Icon(Icons.history), text: '活动'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty && _projectInfo == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(_error, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadProjectData, child: const Text('重试')),
                ]))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFilesTab(isDark),
                    _buildConfigTab(isDark),
                    _buildActivityTab(isDark),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilesTab(bool isDark) {
    if (_files.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('项目还没有文件', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('点击 + 添加文件或让AI帮你生成', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final fileName = file['name'] as String? ?? '未知文件';
          final fileType = file['type'] as String? ?? 'file';
          final fileSize = file['size'] as int? ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_getFileIcon(fileType), color: _getFileColor(fileType)),
              title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_formatSize(fileSize), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _showFileOptions(file)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildConfigSection('基本信息', [
          _buildConfigItem(Icons.tag, '项目ID', widget.projectId),
          _buildConfigItem(Icons.calendar_today, '创建时间', _projectInfo?['created_at']?.toString() ?? '-'),
          _buildConfigItem(Icons.update, '更新时间', _projectInfo?['updated_at']?.toString() ?? '-'),
        ]),
        const SizedBox(height: 16),
        _buildConfigSection('AI配置', [
          _buildConfigItem(Icons.smart_toy, '模型', _projectInfo?['model']?.toString() ?? 'deepseek-chat'),
          _buildConfigItem(Icons.thermostat, 'Temperature', (_projectInfo?['temperature'] ?? 0.7).toString()),
          _buildConfigItem(Icons.memory, '最大上下文', (_projectInfo?['max_context'] ?? 20).toString()),
        ]),
        const SizedBox(height: 16),
        _buildConfigSection('构建配置', [
          _buildConfigItem(Icons.build, '构建工具', _projectInfo?['build_tool']?.toString() ?? '未配置'),
          _buildConfigItem(Icons.code, '语言', _projectInfo?['language']?.toString() ?? '未配置'),
        ]),
      ],
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_recentActivity.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('暂无活动记录', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentActivity.length,
      itemBuilder: (context, index) {
        final activity = _recentActivity[index];
        return ListTile(
          leading: Icon(_getActivityIcon(activity['type'] as String? ?? ''), color: _getActivityColor(activity['type'] as String? ?? '')),
          title: Text(activity['title'] as String? ?? ''),
          subtitle: Text(activity['time'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        );
      },
    );
  }

  Widget _buildConfigSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...children,
    ]);
  }

  Widget _buildConfigItem(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey[500]),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: TextStyle(color: Colors.grey[600]))),
    ]));
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'folder': return Icons.folder;
      case 'dart': return Icons.code;
      case 'image': return Icons.image;
      case 'doc': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'folder': return Colors.amber;
      case 'dart': return Colors.blue;
      case 'image': return Colors.green;
      case 'doc': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'build': return Icons.build;
      case 'deploy': return Icons.cloud_upload;
      case 'edit': return Icons.edit;
      case 'create': return Icons.add_circle;
      default: return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'build': return Colors.blue;
      case 'deploy': return Colors.green;
      case 'edit': return Colors.orange;
      case 'create': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _showProjectMenu(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.edit), title: const Text('编辑项目'), onTap: () { Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.content_copy), title: const Text('复制项目'), onTap: () { Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('删除项目', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _confirmDelete(); }),
    ])));
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.create_new_folder), title: const Text('新建文件'), onTap: () { Navigator.pop(ctx); _createNewFile(); }),
      ListTile(leading: const Icon(Icons.upload_file), title: const Text('上传文件'), onTap: () { Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.smart_toy), title: const Text('让AI生成'), onTap: () { Navigator.pop(ctx); _askAiGenerate(); }),
    ])));
  }

  void _showFileOptions(Map<String, dynamic> file) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.visibility), title: const Text('预览'), onTap: () => Navigator.pop(ctx)),
      ListTile(leading: const Icon(Icons.edit), title: const Text('编辑'), onTap: () => Navigator.pop(ctx)),
      ListTile(leading: const Icon(Icons.download), title: const Text('下载'), onTap: () => Navigator.pop(ctx)),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('删除', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx)),
    ])));
  }

  void _createNewFile() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新建文件'),
      content: TextField(decoration: const InputDecoration(hintText: '输入文件名'), autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('创建'))],
    ));
  }

  void _askAiGenerate() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('让AI生成'),
      content: const TextField(maxLines: 3, decoration: InputDecoration(hintText: '描述你想生成什么...')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('生成'))],
    ));
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除项目 "${widget.projectName}" 吗？'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('删除', style: TextStyle(color: Colors.red)))],
    ));
  }
}

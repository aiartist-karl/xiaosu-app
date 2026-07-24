// ============================================================================
// 小酥 - 工程项目管理列表页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 项目模型
class ProjectModel {
  final String id;
  final String name;
  final String type;
  final String status;
  final String description;
  final int fileCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.type,
    this.status = 'active',
    this.description = '',
    this.fileCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '未命名项目',
      type: json['type'] ?? 'web_app',
      status: json['status'] ?? 'active',
      description: json['description'] ?? '',
      fileCount: json['file_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'description': description,
    'file_count': fileCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// 项目列表页
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ApiGateway _api = ApiGateway.instance;
  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);

    try {
      final response = await _api.get(
        '/api/projects',
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success && response.data != null) {
        final list = response.data!['projects'] as List? ?? [];
        setState(() {
          _projects = list
              .map((e) => ProjectModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
      } else {
        setState(() => _projects = _localProjects);
      }
    } catch (_) {
      setState(() => _projects = _localProjects);
    }

    setState(() => _isLoading = false);
  }

  final List<ProjectModel> _localProjects = [
    ProjectModel(
      id: 'proj_001',
      name: '小酥官网',
      type: 'web_app',
      description: '小酥AI助手官方网站',
      status: 'active',
      fileCount: 24,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ProjectModel(
      id: 'proj_002',
      name: '商城小程序',
      type: 'mini_app',
      description: '微信小程序电商项目',
      status: 'building',
      fileCount: 56,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  Future<void> _createProject() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'web_app';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创建工程项目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '项目名称',
                    hintText: '如：我的Web应用',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('选择项目模板', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _ProjectTypeSelector(
                  selectedType: selectedType,
                  onChanged: (type) => setDialogState(() => selectedType = type),
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
                'type': selectedType,
              }),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      final newProject = ProjectModel(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: result['name']!,
        type: result['type']!,
        description: result['description'] ?? '',
        status: 'active',
        fileCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 同步后端
      try {
        await _api.post(
          '/api/projects',
          body: newProject.toJson(),
          headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
        );
      } catch (_) {}

      setState(() => _projects.insert(0, newProject));

      // 跳转到项目详情
      if (mounted) {
        context.push('/project/${newProject.id}');
      }
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'web_app':
        return Icons.web;
      case 'mini_app':
        return Icons.phone_android;
      case 'android_app':
        return Icons.android;
      default:
        return Icons.folder;
    }
  }

  String _typeName(String type) {
    switch (type) {
      case 'web_app':
        return 'Web App';
      case 'mini_app':
        return '小程序';
      case 'android_app':
        return 'Android';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'building':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工程项目'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('还没有项目', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('创建你的第一个工程项目', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _createProject,
                        icon: const Icon(Icons.add),
                        label: const Text('创建项目'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return _buildProjectCard(project, index);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        tooltip: '创建项目',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project, int index) {
    final statusColor = _statusColor(project.status);
    final typeColor = _typeColor(project.type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/project/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_typeIcon(project.type), color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        if (project.description.isNotEmpty)
                          Text(
                            project.description,
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
                    child: Text(
                      project.status == 'active' ? '就绪' : '编译中',
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(_typeName(project.type), style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.insert_drive_file_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${project.fileCount}个文件', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const Spacer(),
                  Text(_formatDate(project.updatedAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'web_app':
        return Colors.blue;
      case 'mini_app':
        return Colors.green;
      case 'android_app':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}

/// 项目模板选择器
class _ProjectTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;

  const _ProjectTypeSelector({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = [
      {'type': 'web_app', 'name': 'Web App', 'icon': Icons.web, 'desc': 'HTML/CSS/JS', 'color': Colors.blue},
      {'type': 'mini_app', 'name': '小程序', 'icon': Icons.phone_android, 'desc': '微信小程序', 'color': Colors.green},
      {'type': 'android_app', 'name': 'Android', 'icon': Icons.android, 'desc': 'Android App', 'color': Colors.purple},
    ];

    return Column(
      children: types.map((t) {
        final isSelected = selectedType == t['type'];
        final color = t['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(t['type'] as String),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? color : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(t['icon'] as IconData, color: color, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(t['desc'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const Spacer(),
                  if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

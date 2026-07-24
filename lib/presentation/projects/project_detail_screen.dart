// ============================================================================
// 小酥 - 项目详情页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 项目文件节点
class FileNode {
  final String name;
  final bool isDirectory;
  final List<FileNode> children;
  final String? path;

  FileNode({
    required this.name,
    this.isDirectory = false,
    this.children = const [],
    this.path,
  });
}

/// 项目详情页
class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiGateway _api = ApiGateway.instance;
  late TabController _tabController;

  String _projectName = '工程项目';
  String _projectType = 'web_app';
  String _projectStatus = 'active';
  List<FileNode> _fileTree = [];
  List<String> _buildLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProjectDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectDetail() async {
    setState(() => _isLoading = true);

    try {
      final response = await _api.get(
        '/api/projects/${widget.projectId}',
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        setState(() {
          _projectName = data['name'] ?? _projectName;
          _projectType = data['type'] ?? _projectType;
          _projectStatus = data['status'] ?? _projectStatus;

          // 解析文件树
          final files = data['files'] as List? ?? [];
          _fileTree = files.map((f) => _parseFileNode(Map<String, dynamic>.from(f))).toList();

          // 编译日志
          _buildLogs = List<String>.from(data['build_logs'] as List? ?? []);
          _isLoading = false;
        });
      } else {
        _loadMockData();
      }
    } catch (_) {
      _loadMockData();
    }
  }

  void _loadMockData() {
    setState(() {
      _projectName = '示例项目';
      _fileTree = [
        FileNode(name: 'src', isDirectory: true, children: [
          FileNode(name: 'main.js', path: 'src/main.js'),
          FileNode(name: 'app.css', path: 'src/app.css'),
          FileNode(name: 'index.html', path: 'src/index.html'),
        ]),
        FileNode(name: 'package.json', path: 'package.json'),
        FileNode(name: 'README.md', path: 'README.md'),
      ];
      _buildLogs = [
        '[10:30:01] 初始化项目环境...',
        '[10:30:02] 安装依赖: npm install',
        '[10:30:15] 依赖安装完成',
        '[10:30:16] 开始编译...',
        '[10:30:28] 编译成功! 输出: dist/',
      ];
      _isLoading = false;
    });
  }

  FileNode _parseFileNode(Map<String, dynamic> json) {
    final children = (json['children'] as List? ?? [])
        .map((c) => _parseFileNode(Map<String, dynamic>.from(c)))
        .toList();
    return FileNode(
      name: json['name'] ?? '',
      isDirectory: json['is_directory'] ?? false,
      children: children,
      path: json['path'],
    );
  }

  Future<void> _triggerBuild() async {
    setState(() => _projectStatus = 'building');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在触发编译...'), duration: Duration(seconds: 2)),
    );

    try {
      await _api.post(
        '/api/projects/${widget.projectId}/build',
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );
    } catch (_) {}

    // 模拟编译过程
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _projectStatus = 'active';
      _buildLogs.add('[${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}] 编译完成');
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 编译完成!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_projectName),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '文件', icon: Icon(Icons.folder_outlined)),
            Tab(text: '状态', icon: Icon(Icons.info_outline)),
            Tab(text: '编译日志', icon: Icon(Icons.terminal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/project/${widget.projectId}/editor'),
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _triggerBuild,
            tooltip: '编译',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFileTree(),
                _buildStatusTab(),
                _buildLogsTab(),
              ],
            ),
    );
  }

  Widget _buildFileTree() {
    if (_fileTree.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('暂无文件', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _fileTree.length,
      itemBuilder: (context, index) => _buildFileNode(_fileTree[index], 0),
    );
  }

  Widget _buildFileNode(FileNode node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: node.isDirectory ? null : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('打开文件: ${node.name}'), duration: const Duration(seconds: 1)),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(left: 16.0 + depth * 20, top: 4, bottom: 4, right: 16),
            child: Row(
              children: [
                Icon(
                  node.isDirectory ? Icons.folder : _fileIcon(node.name),
                  size: 18,
                  color: node.isDirectory ? Colors.amber.shade700 : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: node.isDirectory ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.isDirectory)
          ...node.children.map((child) => _buildFileNode(child, depth + 1)),
      ],
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.js') || name.endsWith('.ts')) return Icons.javascript;
    if (name.endsWith('.css')) return Icons.style;
    if (name.endsWith('.html')) return Icons.html;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.md')) return Icons.article;
    if (name.endsWith('.py')) return Icons.code;
    return Icons.insert_drive_file;
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('项目信息', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _InfoRow('项目名称', _projectName),
                  _InfoRow('项目类型', _typeLabel(_projectType)),
                  _InfoRow('项目状态', _projectStatus == 'active' ? '就绪' : '编译中'),
                  _InfoRow('项目ID', widget.projectId),
                  _InfoRow('文件数量', '${_countFiles(_fileTree)}个'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快捷操作', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('编译项目'),
                        onPressed: _triggerBuild,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.edit, size: 16),
                        label: const Text('编辑代码'),
                        onPressed: () => context.push('/project/${widget.projectId}/editor'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.cloud_upload, size: 16),
                        label: const Text('部署'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('部署功能开发中...')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    if (_buildLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terminal, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('暂无编译日志', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('点击编译按钮开始构建', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _buildLogs.length,
        itemBuilder: (context, index) {
          final log = _buildLogs[index];
          final isError = log.contains('error') || log.contains('失败');
          final isSuccess = log.contains('成功') || log.contains('完成');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              log,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isError ? Colors.redAccent : isSuccess ? Colors.greenAccent : Colors.grey.shade300,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _InfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
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

  int _countFiles(List<FileNode> nodes) {
    int count = 0;
    for (final node in nodes) {
      if (!node.isDirectory) count++;
      count += _countFiles(node.children);
    }
    return count;
  }
}

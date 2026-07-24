// ============================================================================
// 小酥 - 文件管理（浏览后端服务器文件 + 下载）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/agent_api_service.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final AgentApiService _api = AgentApiService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _currentPath = '';
  final List<String> _pathBreadcrumbs = ['根目录'];

  @override
  void initState() {
    super.initState();
    _loadFiles('');
  }

  Future<void> _loadFiles(String path) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final result = await _api.getFiles(path: path);
      if (result['success'] == true) {
        final fileList = (result['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _files = fileList;
          _currentPath = path;
          _isLoading = false;
        });
      } else {
        setState(() { _errorMessage = result['error'] ?? '加载失败'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = '网络错误: $e'; _isLoading = false; });
    }
  }

  void _navigateInto(String folderName) {
    final newPath = _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
    _pathBreadcrumbs.add(folderName);
    _loadFiles(newPath);
  }

  void _navigateBack() {
    if (_pathBreadcrumbs.length <= 1) return;
    _pathBreadcrumbs.removeLast();
    final newPath = _pathBreadcrumbs.length == 1 ? '' : _pathBreadcrumbs.sublist(1).join('/');
    _loadFiles(newPath);
  }

  Future<void> _downloadFile(String filename) async {
    final url = _api.getFileDownloadUrl(_currentPath.isEmpty ? filename : '$_currentPath/$filename');
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法打开下载链接')));
      }
    }
  }

  IconData _fileIcon(String category) {
    switch (category) {
      case 'image': return Icons.image;
      case 'video': return Icons.video_file;
      case 'audio': return Icons.audio_file;
      case 'document': return Icons.description;
      case 'archive': return Icons.folder_zip;
      case 'code': return Icons.code;
      default: return Icons.insert_drive_file;
    }
  }

  Color _fileColor(String category) {
    switch (category) {
      case 'image': return Colors.pink;
      case 'video': return Colors.purple;
      case 'audio': return Colors.orange;
      case 'document': return Colors.blue;
      case 'archive': return Colors.brown;
      case 'code': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        centerTitle: true,
        leading: _pathBreadcrumbs.length > 1
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateBack)
            : null,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadFiles(_currentPath), tooltip: '刷新'),
        ],
      ),
      body: Column(
        children: [
          // 面包屑导航
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _pathBreadcrumbs.length; i++) ...[
                    if (i > 0) const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    InkWell(
                      onTap: i < _pathBreadcrumbs.length - 1
                          ? () {
                              final targetIdx = i;
                              while (_pathBreadcrumbs.length - 1 > targetIdx) {
                                _pathBreadcrumbs.removeLast();
                              }
                              final p = _pathBreadcrumbs.length == 1 ? '' : _pathBreadcrumbs.sublist(1).join('/');
                              _loadFiles(p);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          _pathBreadcrumbs[i],
                          style: TextStyle(
                            fontSize: 13,
                            color: i < _pathBreadcrumbs.length - 1 ? Theme.of(context).colorScheme.primary : null,
                            fontWeight: i == _pathBreadcrumbs.length - 1 ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 内容区
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 12),
                            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(_errorMessage, style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(onPressed: () => _loadFiles(_currentPath), icon: const Icon(Icons.refresh), label: const Text('重试')),
                          ],
                        ),
                      )
                    : _files.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text('此目录为空', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadFiles(_currentPath),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _files.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final file = _files[index];
                                final name = file['name'] as String? ?? '';
                                final isDir = file['is_dir'] as bool? ?? false;
                                final size = file['size'] as int? ?? 0;
                                final modified = file['modified'] as String? ?? '';
                                final category = file['category'] as String? ?? 'other';

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: (isDir ? Colors.amber : _fileColor(category)).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isDir ? Icons.folder : _fileIcon(category),
                                        color: isDir ? Colors.amber : _fileColor(category),
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      isDir ? '文件夹' : '${_formatSize(size)} · $modified',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    trailing: isDir
                                        ? const Icon(Icons.chevron_right, color: Colors.grey)
                                        : IconButton(
                                            icon: const Icon(Icons.download, size: 20),
                                            tooltip: '下载',
                                            onPressed: () => _downloadFile(name),
                                          ),
                                    onTap: isDir ? () => _navigateInto(name) : () => _downloadFile(name),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

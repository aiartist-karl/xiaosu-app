// ============================================================================
// 小酥 v2 - 文件列表页（对接 FileRepository）
// 从 FileRepository 获取文件列表，支持上传、下载、删除
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/file_repository.dart';
import '../../data/models/file_model.dart';
import '../theme/app_colors.dart';

/// 文件列表页（对接真实 API）
class FileListScreen extends StatefulWidget {
  const FileListScreen({super.key});

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  final FileRepository _repo = FileRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CozeFile> _files = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  _FileSortOption _sortOption = _FileSortOption.date;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repo.fetchFileList();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _files = result.data!;
      } else {
        _error = result.error ?? '加载失败';
      }
    });
  }

  List<CozeFile> get _filteredFiles {
    var list = List<CozeFile>.from(_files);

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_sortOption) {
      case _FileSortOption.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _FileSortOption.date:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _FileSortOption.size:
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return list;
  }

  Future<void> _uploadFile() async {
    // 模拟文件上传 UI
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传文件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(ctx).colorScheme.outline,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload,
                    size: 36,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  const Text('点击选择文件'),
                  const SizedBox(height: 4),
                  Text(
                    '支持 PDF、Word、图片等格式',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '文件名（模拟）',
                hintText: '输入文件名',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('上传'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件上传功能需要接入文件系统，当前为演示界面'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadFile(CozeFile file) async {
    final result = await _repo.downloadFile(file.id);

    if (!mounted) return;

    if (result.success && result.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载链接：${result.data}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '获取下载链接失败')),
      );
    }
  }

  Future<void> _deleteFile(CozeFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除文件「${file.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _repo.deleteFile(file.id);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? '删除失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏 + 排序
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: '搜索文件...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(isDark: isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '排序：',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ..._FileSortOption.values.map((option) {
                      final selected = _sortOption == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _sortOption = option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary(isDark).withOpacity(0.12)
                                  : AppColors.surfaceVariant(isDark: isDark),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary(isDark)
                                    : AppColors.textSecondary(isDark),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // 文件列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(isDark)
                    : _buildFileList(isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(bool isDark) {
    final files = _filteredFiles;

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppColors.textHint(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配文件' : '暂无文件',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty ? '点击右下角按钮上传文件' : '尝试其他搜索关键词',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: files.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.divider(isDark),
        ),
        itemBuilder: (context, index) {
          final file = files[index];
          return _buildFileItem(file, isDark);
        },
      ),
    );
  }

  Widget _buildFileItem(CozeFile file, bool isDark) {
    final fileType = _inferFileType(file.name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 文件类型图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: fileType.color(isDark).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fileType.icon, color: fileType.color(isDark), size: 22),
          ),
          const SizedBox(width: 14),
          // 文件信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatSize(file.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(file.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                    if (file.status != CozeFileStatus.ready) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning(isDark).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(file.status),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.warning(isDark),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 操作按钮
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'download':
                  _downloadFile(file);
                  break;
                case 'delete':
                  _deleteFile(file);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text('下载'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: Icon(Icons.more_vert, color: AppColors.textHint(isDark), size: 20),
          ),
        ],
      ),
    );
  }

  _FileTypeInfo _inferFileType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return _FileTypeInfo(Icons.description, AppColors.error);
      case 'doc':
      case 'docx':
        return _FileTypeInfo(Icons.article, AppColors.info);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return _FileTypeInfo(Icons.table_chart, AppColors.success);
      case 'ppt':
      case 'pptx':
        return _FileTypeInfo(Icons.slideshow, AppColors.warning);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return _FileTypeInfo(Icons.image, AppColors.secondary);
      case 'txt':
      case 'md':
        return _FileTypeInfo(Icons.note, AppColors.textSecondary);
      default:
        return _FileTypeInfo(Icons.insert_drive_file, AppColors.textSecondary);
    }
  }

  String _statusLabel(CozeFileStatus status) {
    switch (status) {
      case CozeFileStatus.uploaded:
        return '已上传';
      case CozeFileStatus.processing:
        return '处理中';
      case CozeFileStatus.ready:
        return '就绪';
      case CozeFileStatus.failed:
        return '失败';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class _FileTypeInfo {
  final IconData icon;
  final Color Function(bool isDark) color;

  _FileTypeInfo(this.icon, this.color);
}

enum _FileSortOption {
  name('名称'),
  date('日期'),
  size('大小');

  final String label;
  const _FileSortOption(this.label);
}

// ============================================================================
// 小酥 v2 - 文件管理页
// Phase 3: 对接真实API，移除假数据
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/file_repository.dart';
import '../../data/models/file_model.dart';
import '../theme/app_colors.dart';

/// 文件管理页面
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final FileRepository _fileRepo = FileRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _FileSortOption _sortOption = _FileSortOption.date;

  List<CozeFile> _files = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

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
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final result = await _fileRepo.fetchFileList();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.success && result.data != null) {
            _files = result.data!;
          } else {
            _hasError = true;
            _errorMessage = result.error ?? '获取文件列表失败';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '加载异常: ${e.toString()}';
        });
      }
    }
  }

  List<CozeFile> get _filteredFiles {
    var list = _files.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        centerTitle: true,
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
                      '排序方式：',
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
          Expanded(child: _buildFileList(isDark)),
        ],
      ),
    );
  }

  Widget _buildFileList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '加载失败',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadFiles,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('重试', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    final list = _filteredFiles;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? '没有找到匹配的文件' : '暂无文件',
              style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.divider(isDark),
      ),
      itemBuilder: (context, index) {
        final file = list[index];
        return _CozeFileListTile(file: file, isDark: isDark);
      },
    );
  }
}

// ─── CozeFile 列表项 Widget ──────────────────────────────────────
class _CozeFileListTile extends StatelessWidget {
  final CozeFile file;
  final bool isDark;

  const _CozeFileListTile({required this.file, required this.isDark});

  IconData _fileIcon() {
    final mime = file.mimeType.toLowerCase();
    final name = file.name.toLowerCase();
    if (mime.contains('pdf') || name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (mime.contains('excel') || mime.contains('spreadsheet') || name.endsWith('.xlsx') || name.endsWith('.xls')) return Icons.table_chart;
    if (mime.contains('word') || mime.contains('document') || name.endsWith('.docx') || name.endsWith('.doc')) return Icons.description;
    if (mime.contains('image') || name.endsWith('.png') || name.endsWith('.jpg')) return Icons.image;
    if (mime.contains('presentation') || name.endsWith('.pptx')) return Icons.slideshow;
    if (mime.contains('text') || name.endsWith('.md') || name.endsWith('.txt')) return Icons.article;
    return Icons.insert_drive_file;
  }

  Color _fileColor() {
    final icon = _fileIcon();
    if (icon == Icons.picture_as_pdf) return Colors.red;
    if (icon == Icons.table_chart) return Colors.green;
    if (icon == Icons.image) return Colors.purple;
    if (icon == Icons.slideshow) return Colors.orange;
    return AppColors.info(isDark);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _fileIcon();
    final color = _fileColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
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
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(file.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 排序选项 ────────────────────────────────────────────────────
enum _FileSortOption {
  date('按时间'),
  name('按名称'),
  size('按大小');

  final String label;
  const _FileSortOption(this.label);
}

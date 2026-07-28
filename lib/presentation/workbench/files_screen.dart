// ============================================================================
// 小酥 v2 - 文件管理页
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 文件管理页面
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _FileSortOption _sortOption = _FileSortOption.date;

  // 模拟文件数据
  final List<_FileItem> _files = [
    _FileItem(
      name: '项目方案.pdf',
      size: 2.4 * 1024 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(hours: 1)),
      type: FileType.pdf,
    ),
    _FileItem(
      name: '数据分析报告.xlsx',
      size: 1.8 * 1024 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(hours: 5)),
      type: FileType.excel,
    ),
    _FileItem(
      name: '会议纪要.md',
      size: 12 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 1)),
      type: FileType.text,
    ),
    _FileItem(
      name: 'UI设计稿_v3.png',
      size: 5.6 * 1024 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 2)),
      type: FileType.image,
    ),
    _FileItem(
      name: '产品需求文档.docx',
      size: 860 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 3)),
      type: FileType.word,
    ),
    _FileItem(
      name: '演示文稿.pptx',
      size: 8.2 * 1024 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 5)),
      type: FileType.ppt,
    ),
    _FileItem(
      name: '系统架构图.svg',
      size: 340 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 7)),
      type: FileType.image,
    ),
    _FileItem(
      name: 'README.txt',
      size: 4 * 1024,
      modifiedTime: DateTime.now().subtract(const Duration(days: 10)),
      type: FileType.text,
    ),
  ];

  List<_FileItem> get _filteredFiles {
    var list = _files.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortOption) {
      case _FileSortOption.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _FileSortOption.date:
        list.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
        break;
      case _FileSortOption.size:
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredFiles.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.divider(isDark),
              ),
              itemBuilder: (context, index) {
                final file = _filteredFiles[index];
                return _FileListTile(file: file, isDark: isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 上传文件
        },
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }
}

// ─── 文件列表项 Widget ──────────────────────────────────────────
class _FileListTile extends StatelessWidget {
  final _FileItem file;
  final bool isDark;

  const _FileListTile({required this.file, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 文件类型图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: file.type.color(isDark).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(file.type.icon, color: file.type.color(isDark), size: 22),
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
                      file.sizeString,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      file.timeString,
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
          // 更多按钮
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textHint(isDark),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 排序选项 ──────────────────────────────────────────────────
enum _FileSortOption {
  name('名称'),
  date('日期'),
  size('大小');

  final String label;
  const _FileSortOption(this.label);
}

// ─── 文件类型 ──────────────────────────────────────────────────
enum FileType {
  pdf(Icons.description),
  word(Icons.article),
  excel(Icons.table_chart),
  ppt(Icons.slideshow),
  image(Icons.image),
  text(Icons.note);

  final IconData icon;

  const FileType(this.icon);

  Color color(bool isDark) {
    switch (this) {
      case FileType.pdf:
        return AppColors.error(isDark);
      case FileType.word:
        return AppColors.info(isDark);
      case FileType.excel:
        return AppColors.success(isDark);
      case FileType.ppt:
        return AppColors.warning(isDark);
      case FileType.image:
        return AppColors.secondary(isDark);
      case FileType.text:
        return AppColors.textSecondary(isDark);
    }
  }
}

// ─── 文件数据模型 ──────────────────────────────────────────────
class _FileItem {
  final String name;
  final double size; // bytes
  final DateTime modifiedTime;
  final FileType type;

  _FileItem({
    required this.name,
    required this.size,
    required this.modifiedTime,
    required this.type,
  });

  String get sizeString {
    if (size < 1024) return '${size.toStringAsFixed(0)} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get timeString {
    final diff = DateTime.now().difference(modifiedTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${modifiedTime.month}/${modifiedTime.day}';
  }
}

// ============================================================================
// 小酥 v2 - 知识库列表页
// 从 KnowledgeRepository 获取知识库列表，支持创建、删除
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../data/models/knowledge_model.dart';
import '../theme/app_colors.dart';

/// 知识库列表页
class KnowledgeListScreen extends StatefulWidget {
  const KnowledgeListScreen({super.key});

  @override
  State<KnowledgeListScreen> createState() => _KnowledgeListScreenState();
}

class _KnowledgeListScreenState extends State<KnowledgeListScreen> {
  final KnowledgeRepository _repo = KnowledgeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<KnowledgeDataset> _datasets = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadKnowledge();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKnowledge() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repo.fetchKnowledgeListInternal(
      keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _datasets = result.data!;
      } else {
        _error = result.error ?? '加载失败';
      }
    });
  }

  Future<void> _createKnowledge() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    KnowledgeFormatType selectedType = KnowledgeFormatType.text;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创建知识库'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '知识库名称',
                    hintText: '请输入知识库名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '请输入知识库描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<KnowledgeFormatType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: '知识库类型',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: KnowledgeFormatType.text,
                      child: Text('文本知识库'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeFormatType.table,
                      child: Text('表格知识库'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeFormatType.image,
                      child: Text('图片知识库'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final createResult = await _repo.createKnowledgeInternal(
        name: nameController.text,
        description: descController.text,
        formatType: selectedType,
      );

      if (!mounted) return;

      if (createResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('知识库创建成功')),
        );
        _loadKnowledge();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult.error ?? '创建失败')),
        );
      }
    }
  }

  Future<void> _deleteKnowledge(KnowledgeDataset dataset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除知识库'),
        content: Text('确定要删除知识库「${dataset.name}」吗？\n其中包含的 ${dataset.documentCount} 个文档也将被删除。'),
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
      final result = await _repo.deleteKnowledgeInternal(dataset.id);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        _loadKnowledge();
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
        title: const Text('知识库管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadKnowledge,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchQuery = v;
                _loadKnowledge();
              },
              decoration: InputDecoration(
                hintText: '搜索知识库...',
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
          ),
          // 内容
          Expanded(child: _buildContent(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createKnowledge,
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadKnowledge,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_datasets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: AppColors.textHint(isDark)),
            const SizedBox(height: 16),
            Text(
              '暂无知识库',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮创建第一个知识库',
              style: TextStyle(fontSize: 13, color: AppColors.textHint(isDark)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKnowledge,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _datasets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ds = _datasets[index];
          return _KnowledgeCard(
            dataset: ds,
            isDark: isDark,
            onTap: () => context.pushNamed(
              'knowledge-detail',
              queryParameters: {'datasetId': ds.id, 'datasetName': ds.name},
            ),
            onDelete: () => _deleteKnowledge(ds),
          );
        },
      ),
    );
  }
}

/// 知识库卡片
class _KnowledgeCard extends StatelessWidget {
  final KnowledgeDataset dataset;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _KnowledgeCard({
    required this.dataset,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.menu_book, color: AppColors.info(isDark), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dataset.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dataset.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dataset.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error(isDark)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statChip(Icons.description, '${dataset.documentCount} 个文档', isDark),
                const SizedBox(width: 12),
                _statChip(Icons.data_usage, _formatSize(dataset.totalCharCount), isDark),
                const SizedBox(width: 12),
                _statChip(Icons.layers, '${dataset.sliceCount} 切片', isDark),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dataset.formatType.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint(isDark)),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark))),
      ],
    );
  }

  String _formatSize(int charCount) {
    if (charCount < 1000) return '$charCount 字符';
    if (charCount < 10000) return '${(charCount / 1000).toStringAsFixed(1)}K 字符';
    return '${(charCount / 10000).toStringAsFixed(1)}万 字符';
  }
}

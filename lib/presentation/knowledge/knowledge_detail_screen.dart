// ============================================================================
// 小酥 v2 - 知识库详情页
// 显示知识库中的文档列表，支持上传、删除文档
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../data/models/knowledge_model.dart';
import '../theme/app_colors.dart';

/// 知识库详情页
class KnowledgeDetailScreen extends StatefulWidget {
  final String datasetId;
  final String datasetName;

  const KnowledgeDetailScreen({
    super.key,
    required this.datasetId,
    required this.datasetName,
  });

  @override
  State<KnowledgeDetailScreen> createState() => _KnowledgeDetailScreenState();
}

class _KnowledgeDetailScreenState extends State<KnowledgeDetailScreen> {
  final KnowledgeRepository _repo = KnowledgeRepository();

  KnowledgeDataset? _dataset;
  List<KnowledgeDocument> _documents = [];
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;

  // 搜索功能
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<KnowledgeChunk>? _searchResults;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      _repo.fetchKnowledgeDetail(widget.datasetId),
      _repo.fetchDocumentList(widget.datasetId),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        _dataset = results[0].data as KnowledgeDataset?;
      }
      if (results[1].success && results[1].data != null) {
        _documents = results[1].data as List<KnowledgeDocument>? ?? [];
      }
      if (!results[0].success && !results[1].success) {
        _error = results[0].error ?? results[1].error ?? '加载失败';
      }
    });
  }

  Future<void> _uploadDocument() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    final urlController = TextEditingController();
    String docType = 'txt';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('上传文档'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '文档名称 *',
                    hintText: '请输入文档名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(
                    labelText: '文档类型',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'txt', child: Text('文本文件 (txt)')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF 文件')),
                    DropdownMenuItem(value: 'docx', child: Text('Word 文档')),
                    DropdownMenuItem(value: 'csv', child: Text('CSV 文件')),
                    DropdownMenuItem(value: 'url', child: Text('网页 URL')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => docType = v);
                  },
                ),
                const SizedBox(height: 12),
                if (docType == 'url')
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: '网页地址',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '文档内容',
                      hintText: '请输入文档内容（也可直接粘贴文本）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
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
              child: const Text('上传'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      setState(() => _isUploading = true);

      final uploadResult = await _repo.uploadDocument(
        widget.datasetId,
        fileName: nameController.text,
        fileContent: docType != 'url' ? contentController.text : null,
        fileUrl: docType == 'url' ? urlController.text : null,
        documentType: docType,
      );

      if (!mounted) return;

      setState(() => _isUploading = false);

      if (uploadResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文档上传成功，正在处理中...')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadResult.error ?? '上传失败')),
        );
      }
    }
  }

  Future<void> _deleteDocument(KnowledgeDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定要删除文档「${doc.name}」吗？'),
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
      final result = await _repo.deleteDocument(widget.datasetId, doc.id);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? '删除失败')),
        );
      }
    }
  }

  Future<void> _searchKnowledge() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }

    setState(() => _isSearching = true);

    final result = await _repo.searchKnowledge(widget.datasetId, query, topK: 10);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (result.success && result.data != null) {
        _searchResults = result.data!.chunks;
      } else {
        _searchResults = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.datasetName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isDark)
              : _buildContent(isDark),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadDocument,
        backgroundColor: AppColors.primary(isDark),
        child: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file, color: Colors.white),
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
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 知识库信息
        if (_dataset != null) _buildInfoCard(isDark),
        const SizedBox(height: 16),
        // 搜索区域
        _buildSearchBar(isDark),
        const SizedBox(height: 16),
        // 搜索结果 或 文档列表
        if (_searchResults != null)
          _buildSearchResults(isDark)
        else
          _buildDocumentList(isDark),
      ],
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
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
              Icon(Icons.menu_book, color: AppColors.info(isDark), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dataset!.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success(isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _dataset!.formatType.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success(isDark),
                  ),
                ),
              ),
            ],
          ),
          if (_dataset!.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _dataset!.description,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('${_dataset!.documentCount}', '文档', isDark),
              const SizedBox(width: 20),
              _stat('${_dataset!.sliceCount}', '切片', isDark),
              const SizedBox(width: 20),
              _stat(_formatCharCount(_dataset!.totalCharCount), '字符', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary(isDark),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _searchKnowledge(),
            decoration: InputDecoration(
              hintText: '输入关键词检索知识库...',
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
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isSearching ? null : _searchKnowledge,
          icon: _isSearching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          tooltip: '检索',
        ),
      ],
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchResults == null || _searchResults!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '未找到相关内容',
            style: TextStyle(color: AppColors.textSecondary(isDark)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '检索结果（${_searchResults!.length} 条）',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        ..._searchResults!.map((chunk) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider(isDark), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grade, size: 14, color: AppColors.warning(isDark)),
                      const SizedBox(width: 4),
                      Text(
                        '相似度: ${(chunk.score * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.warning(isDark),
                        ),
                      ),
                      if (chunk.documentName != null) ...[
                        const Spacer(),
                        Text(
                          chunk.documentName!,
                          style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chunk.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary(isDark),
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )),
        // 返回文档列表按钮
        TextButton(
          onPressed: () => setState(() => _searchResults = null),
          child: const Text('返回文档列表'),
        ),
      ],
    );
  }

  Widget _buildDocumentList(bool isDark) {
    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 48, color: AppColors.textHint(isDark)),
              const SizedBox(height: 12),
              Text(
                '暂无文档',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 4),
              Text(
                '点击右下角按钮上传文档',
                style: TextStyle(fontSize: 13, color: AppColors.textHint(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '文档列表（${_documents.length}）',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        ..._documents.map((doc) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider(isDark), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(_docIcon(doc.type), size: 20, color: AppColors.info(isDark)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
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
                            _docStatusChip(doc.status, isDark),
                            const SizedBox(width: 8),
                            if (doc.charCount > 0)
                              Text(
                                '${doc.charCount} 字符',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint(isDark),
                                ),
                              ),
                            if (doc.fileSize != null && doc.fileSize! > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatFileSize(doc.fileSize!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteDocument(doc),
                    icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error(isDark)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _docStatusChip(DocumentStatus status, bool isDark) {
    Color color;
    switch (status) {
      case DocumentStatus.completed:
        color = AppColors.success(isDark);
        break;
      case DocumentStatus.processing:
        color = AppColors.warning(isDark);
        break;
      case DocumentStatus.failed:
        color = AppColors.error(isDark);
        break;
      default:
        color = AppColors.textHint(isDark);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  IconData _docIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.article;
      case 'txt':
      case 'md':
        return Icons.note;
      case 'csv':
      case 'xlsx':
        return Icons.table_chart;
      case 'url':
      case 'html':
        return Icons.language;
      default:
        return Icons.description;
    }
  }

  String _formatCharCount(int count) {
    if (count < 1000) return '$count';
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 10000).toStringAsFixed(1)}万';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

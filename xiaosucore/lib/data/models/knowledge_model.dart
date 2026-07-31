// ============================================================================
// 小酥 v2 - 知识库数据模型
// Phase 5: 知识库对接 Coze Studio Knowledge API
// ============================================================================

/// 知识库类型
enum KnowledgeFormatType {
  text,    // 文本文档
  table,   // 表格数据
  image,   // 图片
  mixed,   // 混合
  unknown; // 未知

  static KnowledgeFormatType fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'text':
      case '0':
        return KnowledgeFormatType.text;
      case 'table':
      case '1':
        return KnowledgeFormatType.table;
      case 'image':
      case '2':
        return KnowledgeFormatType.image;
      case 'mixed':
        return KnowledgeFormatType.mixed;
      default:
        return KnowledgeFormatType.unknown;
    }
  }

  String get label {
    switch (this) {
      case KnowledgeFormatType.text:
        return '文本';
      case KnowledgeFormatType.table:
        return '表格';
      case KnowledgeFormatType.image:
        return '图片';
      case KnowledgeFormatType.mixed:
        return '混合';
      default:
        return '未知';
    }
  }
}

/// 文档处理状态
enum DocumentStatus {
  pending,     // 等待处理
  processing,  // 处理中（分片/向量化）
  completed,   // 处理完成
  failed,      // 处理失败
  deleted;     // 已删除

  static DocumentStatus fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'pending':
      case '0':
      case 'waiting':
        return DocumentStatus.pending;
      case 'processing':
      case '1':
      case 'indexing':
        return DocumentStatus.processing;
      case 'completed':
      case '2':
      case 'ready':
      case 'active':
        return DocumentStatus.completed;
      case 'failed':
      case '3':
      case 'error':
        return DocumentStatus.failed;
      case 'deleted':
      case '-1':
        return DocumentStatus.deleted;
      default:
        return DocumentStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case DocumentStatus.pending:
        return '待处理';
      case DocumentStatus.processing:
        return '处理中';
      case DocumentStatus.completed:
        return '已完成';
      case DocumentStatus.failed:
        return '失败';
      case DocumentStatus.deleted:
        return '已删除';
    }
  }

  bool get isReady => this == DocumentStatus.completed;
}

/// 知识库数据集
class KnowledgeDataset {
  final String id;
  final String name;
  final String description;
  final KnowledgeFormatType formatType;
  final int documentCount;
  final int totalCharCount;
  final int sliceCount;
  final String? spaceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? extra;

  const KnowledgeDataset({
    required this.id,
    required this.name,
    this.description = '',
    this.formatType = KnowledgeFormatType.text,
    this.documentCount = 0,
    this.totalCharCount = 0,
    this.sliceCount = 0,
    this.spaceId,
    this.createdAt,
    this.updatedAt,
    this.extra,
  });

  /// 从 OpenAPI v1 响应创建
  factory KnowledgeDataset.fromV1Api(Map<String, dynamic> json) {
    return KnowledgeDataset(
      id: json['dataset_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      formatType: KnowledgeFormatType.fromString(
        json['format_type']?.toString() ?? json['type']?.toString(),
      ),
      documentCount: _parseInt(json['document_count'] ?? json['doc_count']),
      totalCharCount: _parseInt(json['char_count'] ?? json['total_char_count']),
      sliceCount: _parseInt(json['slice_count']),
      spaceId: json['space_id']?.toString(),
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      extra: json,
    );
  }

  /// 从内部 API 响应创建
  factory KnowledgeDataset.fromInternalApi(Map<String, dynamic> json) {
    return KnowledgeDataset(
      id: json['dataset_id']?.toString() ?? json['knowledge_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      formatType: KnowledgeFormatType.fromString(
        json['format_type']?.toString() ?? json['type']?.toString() ?? json['knowledge_type']?.toString(),
      ),
      documentCount: _parseInt(json['document_count'] ?? json['doc_count']),
      totalCharCount: _parseInt(json['char_count'] ?? json['total_char_count']),
      sliceCount: _parseInt(json['slice_count'] ?? json['chunk_count']),
      spaceId: json['space_id']?.toString(),
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      extra: json,
    );
  }

  /// 转为创建知识库请求体
  Map<String, dynamic> toCreateBody({required String spaceId}) => {
    'space_id': spaceId,
    'name': name,
    'description': description,
    'format_type': formatType.index,
  };

  KnowledgeDataset copyWith({
    String? name,
    String? description,
    int? documentCount,
    int? totalCharCount,
    int? sliceCount,
  }) => KnowledgeDataset(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    formatType: formatType,
    documentCount: documentCount ?? this.documentCount,
    totalCharCount: totalCharCount ?? this.totalCharCount,
    sliceCount: sliceCount ?? this.sliceCount,
    spaceId: spaceId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: extra,
  );

  @override
  String toString() =>
      'KnowledgeDataset(id: $id, name: $name, docs: $documentCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeDataset && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 知识库文档
class KnowledgeDocument {
  final String id;
  final String name;
  final String? datasetId;
  final String type; // pdf / docx / txt / url / csv / xlsx
  final DocumentStatus status;
  final int charCount;
  final int sliceCount;
  final int? fileSize;
  final String? fileUrl;
  final String? errorMessage;
  final double? progress; // 处理进度 0.0 ~ 1.0
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? extra;

  const KnowledgeDocument({
    required this.id,
    required this.name,
    this.datasetId,
    this.type = 'txt',
    this.status = DocumentStatus.pending,
    this.charCount = 0,
    this.sliceCount = 0,
    this.fileSize,
    this.fileUrl,
    this.errorMessage,
    this.progress,
    this.createdAt,
    this.updatedAt,
    this.extra,
  });

  /// 从 API 响应创建
  factory KnowledgeDocument.fromApi(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['document_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['file_name']?.toString() ?? '',
      datasetId: json['dataset_id']?.toString() ?? json['knowledge_id']?.toString(),
      type: json['type']?.toString() ?? json['document_type']?.toString() ?? _inferType(json['name']?.toString() ?? json['file_name']?.toString() ?? ''),
      status: DocumentStatus.fromString(
        json['status']?.toString() ?? json['process_status']?.toString(),
      ),
      charCount: _parseInt(json['char_count'] ?? json['word_count']),
      sliceCount: _parseInt(json['slice_count'] ?? json['chunk_count']),
      fileSize: _parseInt(json['file_size'] ?? json['size']),
      fileUrl: json['file_url']?.toString() ?? json['url']?.toString(),
      errorMessage: json['error_message']?.toString() ?? json['error_msg']?.toString(),
      progress: json['progress'] is num ? (json['progress'] as num).toDouble() : null,
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      extra: json,
    );
  }

  static String _inferType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return 'pdf';
      case 'doc': case 'docx': return 'docx';
      case 'txt': return 'txt';
      case 'csv': return 'csv';
      case 'xlsx': case 'xls': return 'xlsx';
      case 'md': return 'md';
      case 'html': case 'htm': return 'html';
      default: return 'unknown';
    }
  }

  @override
  String toString() =>
      'KnowledgeDocument(id: $id, name: $name, status: ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeDocument && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 知识检索结果
class KnowledgeSearchResult {
  final List<KnowledgeChunk> chunks;
  final String query;
  final int totalCount;

  const KnowledgeSearchResult({
    required this.chunks,
    required this.query,
    this.totalCount = 0,
  });

  /// 从 API 响应创建
  factory KnowledgeSearchResult.fromApi(
    Map<String, dynamic> json, {
    required String query,
  }) {
    final chunksRaw = json['chunks'] ?? json['results'] ?? json['data'] ?? [];
    final chunks = <KnowledgeChunk>[];

    if (chunksRaw is List) {
      for (final c in chunksRaw) {
        if (c is Map<String, dynamic>) {
          chunks.add(KnowledgeChunk.fromApi(c));
        }
      }
    }

    // 按相似度降序排序
    chunks.sort((a, b) => b.score.compareTo(a.score));

    return KnowledgeSearchResult(
      chunks: chunks,
      query: query,
      totalCount: json['total'] is int ? json['total'] as int : chunks.length,
    );
  }
}

/// 知识切片/检索片段
class KnowledgeChunk {
  final String id;
  final String content;
  final double score; // 相似度分数
  final String? documentId;
  final String? documentName;
  final String? datasetId;
  final Map<String, dynamic>? metadata;
  final int? position; // 在文档中的位置

  const KnowledgeChunk({
    required this.id,
    required this.content,
    this.score = 0.0,
    this.documentId,
    this.documentName,
    this.datasetId,
    this.metadata,
    this.position,
  });

  /// 从 API 响应创建
  factory KnowledgeChunk.fromApi(Map<String, dynamic> json) {
    return KnowledgeChunk(
      id: json['chunk_id']?.toString() ?? json['slice_id']?.toString() ?? json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? json['text']?.toString() ?? json['chunk_content']?.toString() ?? '',
      score: json['score'] is num
          ? (json['score'] as num).toDouble()
          : (json['similarity'] is num ? (json['similarity'] as num).toDouble() : 0.0),
      documentId: json['document_id']?.toString(),
      documentName: json['document_name']?.toString() ?? json['file_name']?.toString(),
      datasetId: json['dataset_id']?.toString() ?? json['knowledge_id']?.toString(),
      metadata: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null,
      position: json['position'] is int ? json['position'] as int : null,
    );
  }

  @override
  String toString() =>
      'KnowledgeChunk(id: $id, score: ${score.toStringAsFixed(3)}, content: ${content.length > 50 ? "${content.substring(0, 50)}..." : content})';
}

// ============================================================================
// 工具方法
// ============================================================================

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    return value > 10000000000
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

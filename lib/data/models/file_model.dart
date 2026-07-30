// ============================================================================
// 小酥 - Coze Studio 文件模型
// Phase 6: 对接 Coze Studio 文件管理 API
// ============================================================================

/// 文件状态
enum CozeFileStatus {
  uploaded,   // 已上传
  processing, // 处理中
  ready,      // 就绪
  failed,     // 失败
}

/// Coze Studio 文件模型
class CozeFile {
  final String id;
  final String name;
  final int size;
  final String mimeType;
  final String url;
  final CozeFileStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CozeFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.url,
    this.status = CozeFileStatus.ready,
    required this.createdAt,
    this.updatedAt,
  });

  factory CozeFile.fromJson(Map<String, dynamic> json) {
    return CozeFile(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      url: json['url'] as String,
      status: CozeFileStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CozeFileStatus.ready,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'mime_type': mimeType,
        'url': url,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  CozeFile copyWith({
    String? id,
    String? name,
    int? size,
    String? mimeType,
    String? url,
    CozeFileStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CozeFile(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      url: url ?? this.url,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

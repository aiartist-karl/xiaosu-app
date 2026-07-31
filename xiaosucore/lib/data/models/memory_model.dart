// ============================================================================
// 小酥 - Coze Studio 记忆模型
// Phase 6: 对接 Coze Studio 记忆系统 API
// ============================================================================

/// 记忆类型
enum CozeMemoryType {
  shortTerm,  // 短期记忆
  longTerm,   // 长期记忆
  episodic,   // 情景记忆
  semantic,   // 语义记忆
}

/// Coze Studio 记忆模型
class CozeMemory {
  final String id;
  final String content;
  final CozeMemoryType type;
  final List<String> tags;
  final double importance;
  final String? botId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CozeMemory({
    required this.id,
    required this.content,
    this.type = CozeMemoryType.shortTerm,
    this.tags = const [],
    this.importance = 0.5,
    this.botId,
    required this.createdAt,
    this.updatedAt,
  });

  factory CozeMemory.fromJson(Map<String, dynamic> json) {
    return CozeMemory(
      id: json['id'] as String,
      content: json['content'] as String,
      type: CozeMemoryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CozeMemoryType.shortTerm,
      ),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      botId: json['bot_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'type': type.name,
        'tags': tags,
        'importance': importance,
        'bot_id': botId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  CozeMemory copyWith({
    String? id,
    String? content,
    CozeMemoryType? type,
    List<String>? tags,
    double? importance,
    String? botId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CozeMemory(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      importance: importance ?? this.importance,
      botId: botId ?? this.botId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

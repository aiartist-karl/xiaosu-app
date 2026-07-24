// ============================================================================
// 小酥 - 对话数据库模型
// ============================================================================

/// 对话数据库模型（用于SQLite存储）
class ConversationModel {
  final String id;
  final String title;
  final String systemPrompt;
  final String modelId;
  final String status;
  final int messageCount;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.title,
    this.systemPrompt = '',
    this.modelId = 'deepseek-chat',
    this.status = 'active',
    this.messageCount = 0,
    this.lastMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库Map创建
  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '新对话',
      systemPrompt: map['systemPrompt'] as String? ?? '',
      modelId: map['modelId'] as String? ?? 'deepseek-chat',
      status: map['status'] as String? ?? 'active',
      messageCount: map['messageCount'] as int? ?? 0,
      lastMessage: map['lastMessage'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// 转为数据库Map
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'systemPrompt': systemPrompt,
    'modelId': modelId,
    'status': status,
    'messageCount': messageCount,
    'lastMessage': lastMessage,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ConversationModel copyWith({
    String? id, String? title, String? systemPrompt, String? modelId,
    String? status, int? messageCount, String? lastMessage,
    DateTime? createdAt, DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelId: modelId ?? this.modelId,
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

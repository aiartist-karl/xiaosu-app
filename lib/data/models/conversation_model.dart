// ============================================================================
// 小酥 - 对话数据库模型
// Phase 3: 扩展支持 Coze Studio 会话字段
// ============================================================================

/// 对话数据库模型（用于SQLite存储 + Coze Studio 同步）
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

  // Phase 3: Coze Studio 扩展字段
  final String? botId;            // Coze Studio Bot ID
  final String? cozeConversationId; // Coze Studio 会话 ID（远程）
  final String? userId;           // 用户 ID

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
    this.botId,
    this.cozeConversationId,
    this.userId,
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
      botId: map['botId'] as String?,
      cozeConversationId: map['cozeConversationId'] as String?,
      userId: map['userId'] as String?,
    );
  }

  /// 从 Coze Studio API 响应创建
  factory ConversationModel.fromCozeApi(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? json['conversation_id'] as String? ?? '';
    final createdAt = json['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000)
        : DateTime.now();
    return ConversationModel(
      id: id,
      title: json['name'] as String? ?? json['title'] as String? ?? '新对话',
      modelId: json['model_id'] as String? ?? 'deepseek-chat',
      status: _mapCozeStatus(json['status'] as String? ?? ''),
      messageCount: json['message_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: createdAt,
      botId: json['bot_id'] as String?,
      cozeConversationId: id,
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
    'botId': botId,
    'cozeConversationId': cozeConversationId,
    'userId': userId,
  };

  ConversationModel copyWith({
    String? id, String? title, String? systemPrompt, String? modelId,
    String? status, int? messageCount, String? lastMessage,
    DateTime? createdAt, DateTime? updatedAt,
    String? botId, String? cozeConversationId, String? userId,
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
      botId: botId ?? this.botId,
      cozeConversationId: cozeConversationId ?? this.cozeConversationId,
      userId: userId ?? this.userId,
    );
  }

  static String _mapCozeStatus(String cozeStatus) {
    switch (cozeStatus.toLowerCase()) {
      case 'active':
      case 'created':
        return 'active';
      case 'archived':
        return 'archived';
      default:
        return 'active';
    }
  }
}

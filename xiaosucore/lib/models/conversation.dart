// ============================================================================
// 小酥 - 对话模型
// ============================================================================

import 'package:equatable/equatable.dart';

/// 对话状态
enum ConversationStatus {
  active,     // 活跃
  archived,   // 已归档
  deleted,    // 已删除
}

/// 对话模型
class Conversation extends Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ConversationStatus status;
  final String? systemPrompt;    // 系统提示词
  final String? modelId;         // 使用的模型ID
  final int messageCount;        // 消息数量
  final String? lastMessage;     // 最后一条消息摘要
  final Map<String, dynamic>? metadata;

  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.status = ConversationStatus.active,
    this.systemPrompt,
    this.modelId,
    this.messageCount = 0,
    this.lastMessage,
    this.metadata,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: ConversationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConversationStatus.active,
      ),
      systemPrompt: json['systemPrompt'] as String?,
      modelId: json['modelId'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      lastMessage: json['lastMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'systemPrompt': systemPrompt,
    'modelId': modelId,
    'messageCount': messageCount,
    'lastMessage': lastMessage,
    'metadata': metadata,
  };

  Conversation copyWith({
    String? id, String? title, DateTime? createdAt, DateTime? updatedAt,
    ConversationStatus? status, String? systemPrompt, String? modelId,
    int? messageCount, String? lastMessage, Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelId: modelId ?? this.modelId,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt, status];
}

// ============================================================================
// 小酥 (XiaoSu) - 对话模型
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'conversation.g.dart';

/// 对话模型
@JsonSerializable()
class Conversation {
  /// 对话唯一 ID
  final String id;

  /// 对话标题
  final String title;

  /// 角色设定（Persona）
  final String persona;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 关联的话题 ID（话题追踪任务关联的对话）
  @Default('')
  final String topicId;

  /// 消息总数
  @Default(0)
  final int messageCount;

  const Conversation({
    required this.id,
    required this.title,
    required this.persona,
    required this.createdAt,
    required this.updatedAt,
    this.topicId = '',
    this.messageCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  Conversation copyWith({
    String? id,
    String? title,
    String? persona,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? topicId,
    int? messageCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      persona: persona ?? this.persona,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      topicId: topicId ?? this.topicId,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

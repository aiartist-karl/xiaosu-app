// ============================================================================
// 小酥 (XiaoSu) - 聊天消息模型
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

/// 消息角色枚举
enum MessageRole {
  /// 用户消息
  user('user'),
  /// AI 助手回复
  assistant('assistant'),
  /// 系统消息（如技能调用结果）
  system('system'),
  /// 工具调用结果
  tool('tool');

  final String value;
  const MessageRole(this.value);
}

/// 聊天消息模型
@JsonSerializable()
class ChatMessage {
  /// 消息唯一 ID
  final String id;

  /// 所属对话 ID
  final String conversationId;

  /// 消息角色（user / assistant / system / tool）
  final MessageRole role;

  /// 消息文本内容
  final String content;

  /// 附件列表（图片路径、文件路径等）
  @Default([])
  final List<String> attachments;

  /// 消息时间戳
  final DateTime timestamp;

  /// Token 消耗数
  @Default(0)
  final int tokenCount;

  /// 关联的 tool_call_id（仅 role=tool 时有值）
  @Default('')
  final String toolCallId;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.attachments = const [],
    required this.timestamp,
    this.tokenCount = 0,
    this.toolCallId = '',
  });

  /// 从 JSON 反序列化
  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  /// 创建副本（用于更新字段）
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    List<String>? attachments,
    DateTime? timestamp,
    int? tokenCount,
    String? toolCallId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      tokenCount: tokenCount ?? this.tokenCount,
      toolCallId: toolCallId ?? this.toolCallId,
    );
  }
}

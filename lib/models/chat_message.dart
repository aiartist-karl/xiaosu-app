// ============================================================================
// 小酥 - 聊天消息模型（v3: 增加 toolCalls 支持）
// ============================================================================

import 'package:equatable/equatable.dart';
import '../presentation/chat/widgets/tool_call_card.dart';

/// 消息角色枚举
enum MessageRole {
  user('user'),
  assistant('assistant'),
  system('system'),
  tool('tool');

  final String value;
  const MessageRole(this.value);
}

/// 消息状态
enum MessageStatus {
  sending,    // 发送中
  sent,       // 已发送
  streaming,  // 流式接收中
  completed,  // 已完成
  error,      // 错误
}

/// 聊天消息模型
class ChatMessage extends Equatable {
  final String id;
  final String conversationId;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final MessageStatus status;
  final String? model;
  final int? tokenCount;
  final double? latency;
  final Map<String, dynamic>? metadata;
  final List<MessageAttachment>? attachments;
  final List<ToolCallInfo>? toolCalls;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.status = MessageStatus.completed,
    this.model,
    this.tokenCount,
    this.latency,
    this.metadata,
    this.attachments,
    this.toolCalls,
  });

  /// 从JSON创建
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      content: json['content'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.value == json['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.completed,
      ),
      model: json['model'] as String?,
      tokenCount: json['tokenCount'] as int?,
      latency: (json['latency'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 转为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'content': content,
      'role': role.value,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'model': model,
      'tokenCount': tokenCount,
      'latency': latency,
      'metadata': metadata,
    };
  }

  /// 转为LLM API格式
  Map<String, dynamic> toApiFormat() {
    return {
      'role': role.value,
      'content': content,
    };
  }

  /// 复制并修改
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    MessageStatus? status,
    String? model,
    int? tokenCount,
    double? latency,
    Map<String, dynamic>? metadata,
    List<MessageAttachment>? attachments,
    List<ToolCallInfo>? toolCalls,
    bool? clearToolCalls,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      model: model ?? this.model,
      tokenCount: tokenCount ?? this.tokenCount,
      latency: latency ?? this.latency,
      metadata: metadata ?? this.metadata,
      attachments: attachments ?? this.attachments,
      toolCalls: clearToolCalls == true ? null : (toolCalls ?? this.toolCalls),
    );
  }

  @override
  List<Object?> get props => [id, conversationId, content, role, timestamp, status, toolCalls];
}

/// 消息附件
class MessageAttachment extends Equatable {
  final String id;
  final String type; // image, file, audio, video
  final String url;
  final String? name;
  final int? size;
  final Map<String, dynamic>? extra;

  const MessageAttachment({
    required this.id,
    required this.type,
    required this.url,
    this.name,
    this.size,
    this.extra,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      name: json['name'] as String?,
      size: json['size'] as int?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'url': url,
        'name': name, 'size': size, 'extra': extra,
      };

  @override
  List<Object?> get props => [id, type, url, name, size];
}

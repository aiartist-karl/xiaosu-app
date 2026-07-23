// ============================================================================
// 小酥 AI 助手 - 对话数据模型
// ============================================================================
// 定义对话系统中的核心数据结构：消息、对话、会话
// 支持 JSON 序列化/反序列化，用于本地存储和 API 传输
// ============================================================================

import 'dart:convert';

// ============================================================================
// 消息角色枚举
// ============================================================================

/// 消息角色类型
/// 标识消息的发送者身份
enum MessageRole {
  /// 用户消息
  user('user'),

  /// AI 助手消息
  assistant('assistant'),

  /// 系统消息（系统提示、工具调用结果等）
  system('system');

  /// 角色的字符串标识
  final String value;

  const MessageRole(this.value);

  /// 从字符串解析角色
  static MessageRole fromString(String role) {
    return MessageRole.values.firstWhere(
      (r) => r.value == role.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}

// ============================================================================
// 消息元数据
// ============================================================================

/// 消息元数据
/// 存储消息的附加信息，如文件、图片、工具调用等
class MessageMetadata {
  /// 附件列表（文件路径、图片 URL 等）
  final List<String>? attachments;

  /// 工具调用信息
  final ToolCallInfo? toolCall;

  /// 工具调用结果
  final ToolCallResult? toolResult;

  /// 引用的消息 ID（回复消息时使用）
  final int? replyToId;

  /// 消息是否已编辑
  final bool? isEdited;

  /// 消息编辑时间
  final DateTime? editedAt;

  /// 自定义扩展字段
  final Map<String, dynamic>? extra;

  const MessageMetadata({
    this.attachments,
    this.toolCall,
    this.toolResult,
    this.replyToId,
    this.isEdited,
    this.editedAt,
    this.extra,
  });

  /// 从 JSON 反序列化
  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      toolCall: json['tool_call'] != null
          ? ToolCallInfo.fromJson(json['tool_call'])
          : null,
      toolResult: json['tool_result'] != null
          ? ToolCallResult.fromJson(json['tool_result'])
          : null,
      replyToId: json['reply_to_id'] as int?,
      isEdited: json['is_edited'] as bool?,
      editedAt: json['edited_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['edited_at'] as int)
          : null,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      if (attachments != null) 'attachments': attachments,
      if (toolCall != null) 'tool_call': toolCall!.toJson(),
      if (toolResult != null) 'tool_result': toolResult!.toJson(),
      if (replyToId != null) 'reply_to_id': replyToId,
      if (isEdited != null) 'is_edited': isEdited,
      if (editedAt != null) 'edited_at': editedAt!.millisecondsSinceEpoch,
      if (extra != null) 'extra': extra,
    };
  }

  /// 从 JSON 字符串解析
  factory MessageMetadata.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MessageMetadata.fromJson(json);
    } catch (e) {
      return const MessageMetadata();
    }
  }

  /// 序列化为 JSON 字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 复制并修改
  MessageMetadata copyWith({
    List<String>? attachments,
    ToolCallInfo? toolCall,
    ToolCallResult? toolResult,
    int? replyToId,
    bool? isEdited,
    DateTime? editedAt,
    Map<String, dynamic>? extra,
  }) {
    return MessageMetadata(
      attachments: attachments ?? this.attachments,
      toolCall: toolCall ?? this.toolCall,
      toolResult: toolResult ?? this.toolResult,
      replyToId: replyToId ?? this.replyToId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      extra: extra ?? this.extra,
    );
  }
}

// ============================================================================
// 工具调用信息
// ============================================================================

/// 工具调用信息
/// 记录 AI 助手发起的工具调用
class ToolCallInfo {
  /// 工具调用 ID
  final String callId;

  /// 调用的工具名称
  final String toolName;

  /// 工具参数
  final Map<String, dynamic> arguments;

  /// 调用时间
  final DateTime calledAt;

  const ToolCallInfo({
    required this.callId,
    required this.toolName,
    required this.arguments,
    required this.calledAt,
  });

  /// 从 JSON 反序列化
  factory ToolCallInfo.fromJson(Map<String, dynamic> json) {
    return ToolCallInfo(
      callId: json['call_id'] as String,
      toolName: json['tool_name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>,
      calledAt: DateTime.fromMillisecondsSinceEpoch(
          json['called_at'] as int),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'tool_name': toolName,
      'arguments': arguments,
      'called_at': calledAt.millisecondsSinceEpoch,
    };
  }
}

/// 工具调用结果
/// 记录工具执行的结果
class ToolCallResult {
  /// 工具调用 ID（关联 ToolCallInfo）
  final String callId;

  /// 是否成功
  final bool success;

  /// 结果内容
  final String content;

  /// 错误信息（失败时）
  final String? error;

  /// 执行耗时（毫秒）
  final int? durationMs;

  const ToolCallResult({
    required this.callId,
    required this.success,
    required this.content,
    this.error,
    this.durationMs,
  });

  /// 从 JSON 反序列化
  factory ToolCallResult.fromJson(Map<String, dynamic> json) {
    return ToolCallResult(
      callId: json['call_id'] as String,
      success: json['success'] as bool,
      content: json['content'] as String,
      error: json['error'] as String?,
      durationMs: json['duration_ms'] as int?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'success': success,
      'content': content,
      if (error != null) 'error': error,
      if (durationMs != null) 'duration_ms': durationMs,
    };
  }
}

// ============================================================================
// 消息模型
// ============================================================================

/// 消息模型
/// 对话系统中的最小单元，表示一条完整的消息
class Message {
  /// 消息 ID（数据库主键）
  final int? id;

  /// 所属会话 ID
  final int sessionId;

  /// 消息角色
  final MessageRole role;

  /// 消息内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// Token 数量
  final int tokens;

  /// 元数据
  final MessageMetadata metadata;

  const Message({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.tokens = 0,
    this.metadata = const MessageMetadata(),
  });

  /// 从 JSON 反序列化
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int?,
      sessionId: json['session_id'] as int,
      role: MessageRole.fromString(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['created_at'] as int),
      tokens: json['tokens'] as int? ?? 0,
      metadata: json['metadata'] != null
          ? MessageMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : const MessageMetadata(),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'role': role.value,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'tokens': tokens,
      'metadata': metadata.toJson(),
    };
  }

  /// 从 JSON 列表反序列化为消息列表
  static List<Message> listFromJson(List<dynamic> jsonList) {
    return jsonList
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 序列化为 JSON 列表
  static List<Map<String, dynamic>> listToJson(List<Message> messages) {
    return messages.map((msg) => msg.toJson()).toList();
  }

  /// 复制并修改
  Message copyWith({
    int? id,
    int? sessionId,
    MessageRole? role,
    String? content,
    DateTime? createdAt,
    int? tokens,
    MessageMetadata? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      tokens: tokens ?? this.tokens,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 是否是用户消息
  bool get isUser => role == MessageRole.user;

  /// 是否是助手消息
  bool get isAssistant => role == MessageRole.assistant;

  /// 是否是系统消息
  bool get isSystem => role == MessageRole.system;

  /// 是否有工具调用
  bool get hasToolCall => metadata.toolCall != null;

  /// 是否有附件
  bool get hasAttachments =>
      metadata.attachments != null && metadata.attachments!.isNotEmpty;

  /// 内容预览（截取前 100 字符）
  String get preview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  @override
  String toString() {
    return 'Message(id: $id, role: ${role.value}, '
        'content: $preview, tokens: $tokens)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.sessionId == sessionId &&
        other.role == role &&
        other.content == content &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, sessionId, role, content, createdAt);
  }
}

// ============================================================================
// 对话模型
// ============================================================================

/// 对话模型
/// 表示一次完整的对话交互（通常包含用户消息和助手回复）
class Conversation {
  /// 用户发送的消息
  final Message userMessage;

  /// AI 助手的回复消息
  final Message? assistantMessage;

  /// 对话时间
  final DateTime timestamp;

  /// 对话上下文（包含的工具调用消息等）
  final List<Message> contextMessages;

  const Conversation({
    required this.userMessage,
    this.assistantMessage,
    required this.timestamp,
    this.contextMessages = const [],
  });

  /// 对话是否完成（有助手回复）
  bool get isComplete => assistantMessage != null;

  /// 总 token 消耗
  int get totalTokens {
    int total = userMessage.tokens;
    if (assistantMessage != null) {
      total += assistantMessage!.tokens;
    }
    for (final msg in contextMessages) {
      total += msg.tokens;
    }
    return total;
  }

  /// 从 JSON 反序列化
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userMessage: Message.fromJson(json['user_message'] as Map<String, dynamic>),
      assistantMessage: json['assistant_message'] != null
          ? Message.fromJson(
              json['assistant_message'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int),
      contextMessages: json['context_messages'] != null
          ? Message.listFromJson(json['context_messages'] as List)
          : const [],
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'user_message': userMessage.toJson(),
      if (assistantMessage != null)
        'assistant_message': assistantMessage!.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'context_messages': Message.listToJson(contextMessages),
    };
  }

  @override
  String toString() {
    return 'Conversation(user: ${userMessage.preview}, '
        'assistant: ${assistantMessage?.preview ?? "无回复"})';
  }
}

// ============================================================================
// 会话模型
// ============================================================================

/// 会话模型
/// 表示一个完整的对话会话，包含多条消息
class ChatSession {
  /// 会话 ID
  final int? id;

  /// 会话标题
  final String title;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 关联的人设 ID
  final int? personaId;

  /// 会话中的消息数量（运行时计算，不持久化）
  final int? messageCount;

  /// 会话摘要（自动生成或用户编辑）
  final String? summary;

  const ChatSession({
    this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.personaId,
    this.messageCount,
    this.summary,
  });

  /// 从 JSON 反序列化
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as int?,
      title: json['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updated_at'] as int),
      personaId: json['persona_id'] as int?,
      messageCount: json['message_count'] as int?,
      summary: json['summary'] as String?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      if (personaId != null) 'persona_id': personaId,
      if (messageCount != null) 'message_count': messageCount,
      if (summary != null) 'summary': summary,
    };
  }

  /// 从 JSON 列表反序列化为会话列表
  static List<ChatSession> listFromJson(List<dynamic> jsonList) {
    return jsonList
        .map((json) => ChatSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 复制并修改
  ChatSession copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? personaId,
    int? messageCount,
    String? summary,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      personaId: personaId ?? this.personaId,
      messageCount: messageCount ?? this.messageCount,
      summary: summary ?? this.summary,
    );
  }

  /// 会话时长（毫秒）
  Duration get duration => updatedAt.difference(createdAt);

  /// 会话时长描述
  String get durationDescription {
    final dur = duration;
    if (dur.inHours > 0) return '${dur.inHours} 小时';
    if (dur.inMinutes > 0) return '${dur.inMinutes} 分钟';
    return '${dur.inSeconds} 秒';
  }

  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, '
        'messages: $messageCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ============================================================================
// 导出模型（用于历史记录导出）
// ============================================================================

/// 对话导出模型
/// 用于将整个会话导出为可分享的格式
class ConversationExport {
  /// 会话信息
  final ChatSession session;

  /// 所有消息
  final List<Message> messages;

  /// 导出时间
  final DateTime exportedAt;

  /// 导出格式版本
  final String version;

  const ConversationExport({
    required this.session,
    required this.messages,
    required this.exportedAt,
    this.version = '1.0',
  });

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exported_at': exportedAt.millisecondsSinceEpoch,
      'session': session.toJson(),
      'messages': Message.listToJson(messages),
    };
  }

  /// 序列化为 JSON 字符串（格式化）
  String toFormattedJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  /// 导出为 Markdown 格式
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# ${session.title}');
    buffer.writeln();
    buffer.writeln('> 导出时间：${exportedAt.toIso8601String()}');
    buffer.writeln('> 消息数量：${messages.length}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final msg in messages) {
      final roleLabel = switch (msg.role) {
        MessageRole.user => '👤 用户',
        MessageRole.assistant => '🤖 小酥',
        MessageRole.system => '⚙️ 系统',
      };
      buffer.writeln('### $roleLabel');
      buffer.writeln();
      buffer.writeln(msg.content);
      buffer.writeln();
      buffer.writeln('_${msg.createdAt.toIso8601String()}_');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 从 JSON 反序列化
  factory ConversationExport.fromJson(Map<String, dynamic> json) {
    return ConversationExport(
      session: ChatSession.fromJson(json['session'] as Map<String, dynamic>),
      messages: Message.listFromJson(json['messages'] as List),
      exportedAt: DateTime.fromMillisecondsSinceEpoch(
          json['exported_at'] as int),
      version: json['version'] as String? ?? '1.0',
    );
  }
}

/// ============================================================================
/// 小酥 AI 助手 — 通用数据模型
/// ============================================================================
/// 本文件定义整个核心层所需的公共数据模型，包括：
///   - 工具声明与结果 (ToolDeclaration / ToolResult)
///   - 角色设定 (PersonaConfig)
///   - 会话模型 (Session / Conversation)
///   - API 请求/响应 (ApiRequest / ApiResponse)
///   - 全局异常类 (CoreException)
/// ============================================================================

// ———————————————————————————————— 工具系统 ————————————————————————————————

/// 工具参数描述，符合 JSON Schema 子集
class ToolParameter {
  /// 参数类型 (string / integer / number / boolean / object / array)
  final String type;

  /// 参数说明
  final String description;

  /// 是否必填
  final bool required;

  /// 枚举可选值（可选）
  final List<String>? enumValues;

  /// 嵌套属性（当 type 为 object 时使用）
  final Map<String, ToolParameter>? properties;

  const ToolParameter({
    required this.type,
    required this.description,
    this.required = false,
    this.enumValues,
    this.properties,
  });

  /// 转为 JSON Map，便于序列化为 OpenAI function schema
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'description': description,
    };
    if (enumValues != null) {
      map['enum'] = enumValues;
    }
    if (properties != null) {
      map['properties'] = {
        for (final e in properties!.entries) e.key: e.value.toJson(),
      };
      map['required'] = properties!.entries
          .where((e) => e.value.required)
          .map((e) => e.key)
          .toList();
    }
    return map;
  }
}

/// 工具/函数声明
///
/// 描述 Agent 可调用的外部工具，包含名称、描述和参数 Schema。
/// 在 LLM 对话中以 Function Calling 形式传递给模型。
class ToolDeclaration {
  /// 工具唯一标识，同时也是 LLM function name
  final String name;

  /// 工具自然语言描述，供 LLM 理解何时调用
  final String description;

  /// 参数映射：参数名 → 参数描述
  final Map<String, ToolParameter> parameters;

  const ToolDeclaration({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  /// 转为 OpenAI function calling 格式的 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': {
            for (final e in parameters.entries) e.key: e.value.toJson(),
          },
        },
      },
    };
  }
}

/// 工具执行结果
///
/// 封装工具调用后的返回值，包括成功/失败状态。
sealed class ToolResult {
  /// 关联的工具名称
  final String toolName;

  /// 关联的调用 ID（与 LLM 请求中的 tool_call_id 对应）
  final String callId;

  const ToolResult({
    required this.toolName,
    required this.callId,
  });

  /// 转为 LLM 可消费的 JSON 字符串
  String toContentJson();
}

/// 工具执行成功
class ToolSuccess extends ToolResult {
  /// 返回内容（通常为 JSON 字符串）
  final String content;

  const ToolSuccess({
    required super.toolName,
    required super.callId,
    required this.content,
  });

  @override
  String toContentJson() => content;
}

/// 工具执行失败
class ToolFailure extends ToolResult {
  /// 错误信息
  final String error;

  const ToolFailure({
    required super.toolName,
    required super.callId,
    required this.error,
  });

  @override
  String toContentJson() => '{"error": "$error"}';
}

// ———————————————————————————————— 角色设定 ————————————————————————————————

/// 角色人格配置
///
/// 用于定义"小酥"的角色人格，包含名称、系统提示词、行为边界等。
/// 在每次对话初始化时注入到 SystemMessage 中。
class PersonaConfig {
  /// 角色名称，如"小酥"
  final String name;

  /// 系统提示词，定义角色的核心行为
  final String systemPrompt;

  /// 角色语气/说话风格提示
  final String toneHint;

  /// 禁止行为列表（安全边界）
  final List<String> forbiddenActions;

  /// 角色头像路径（本地资源或网络 URL）
  final String? avatarPath;

  /// 角色版本号，用于追踪提示词迭代
  final String version;

  const PersonaConfig({
    required this.name,
    required this.systemPrompt,
    this.toneHint = '',
    this.forbiddenActions = const [],
    this.avatarPath,
    this.version = '1.0.0',
  });

  /// 组装完整的系统提示词（含安全边界）
  String buildFullPrompt() {
    final buffer = StringBuffer(systemPrompt);
    if (toneHint.isNotEmpty) {
      buffer.writeln('\n\n## 说话风格\n$toneHint');
    }
    if (forbiddenActions.isNotEmpty) {
      buffer.writeln('\n\n## 安全边界（严禁违反）');
      for (final action in forbiddenActions) {
        buffer.writeln('- $action');
      }
    }
    return buffer.toString();
  }
}

// ———————————————————————————————— 会话模型 ————————————————————————————————

/// 单条消息记录
///
/// 表示会话中的一条消息，支持多种角色。
class ChatMessage {
  /// 消息角色：system / user / assistant / tool
  final String role;

  /// 消息文本内容
  final String content;

  /// 消息时间戳
  final DateTime timestamp;

  /// 关联的工具调用 ID（仅 tool 角色使用）
  final String? toolCallId;

  /// 关联的工具名称（仅 tool 角色使用）
  final String? toolName;

  /// 附加元数据（如 token 数、模型名等）
  final Map<String, dynamic> metadata;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCallId,
    this.toolName,
    this.metadata = const {},
  });

  /// 工厂：系统消息
  factory ChatMessage.system(String content) => ChatMessage(
        role: 'system',
        content: content,
        timestamp: DateTime.now(),
      );

  /// 工厂：用户消息
  factory ChatMessage.user(String content) => ChatMessage(
        role: 'user',
        content: content,
        timestamp: DateTime.now(),
      );

  /// 工厂：助手消息
  factory ChatMessage.assistant(String content, {Map<String, dynamic>? meta}) =>
      ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
        metadata: meta ?? const {},
      );

  /// 工厂：工具结果消息
  factory ChatMessage.tool({
    required String content,
    required String toolCallId,
    required String toolName,
  }) =>
      ChatMessage(
        role: 'tool',
        content: content,
        timestamp: DateTime.now(),
        toolCallId: toolCallId,
        toolName: toolName,
      );

  /// 转为 Map 便于 JSON 序列化
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (toolName != null) map['tool_name'] = toolName;
    if (metadata.isNotEmpty) map['metadata'] = metadata;
    return map;
  }
}

/// 对话会话
///
/// 表示一次完整的对话会话，包含一组消息和相关配置。
class Session {
  /// 会话唯一 ID
  final String id;

  /// 会话标题（可由 LLM 自动生成）
  final String title;

  /// 会话中的全部消息
  final List<ChatMessage> messages;

  /// 关联的角色设定
  final PersonaConfig? persona;

  /// 会话创建时间
  final DateTime createdAt;

  /// 最后活跃时间
  final DateTime updatedAt;

  /// 会话是否已归档
  final bool archived;

  const Session({
    required this.id,
    required this.title,
    this.messages = const [],
    this.persona,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  /// 创建副本，替换消息列表
  Session copyWith({List<ChatMessage>? messages, DateTime? updatedAt}) {
    return Session(
      id: id,
      title: title,
      messages: messages ?? this.messages,
      persona: persona,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived,
    );
  }
}

/// 对话（更高层概念，可包含多个 Session）
///
/// 用于表示一个"话题"或"项目"级别的对话上下文，
/// 一个 Conversation 下可以有多个 Session（如多次重试、分叉对话等）。
class Conversation {
  /// 对话唯一 ID
  final String id;

  /// 对话标题
  final String title;

  /// 关联的 Session 列表
  final List<Session> sessions;

  /// 标签（用于分类检索）
  final List<String> tags;

  /// 创建时间
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.title,
    this.sessions = const [],
    this.tags = const [],
    required this.createdAt,
  });
}

// ———————————————————————————————— API 请求/响应 ————————————————————————————————

/// 通用 API 请求封装
class ApiRequest {
  /// 请求 URL
  final String url;

  /// 请求头
  final Map<String, String> headers;

  /// 请求体
  final Map<String, dynamic> body;

  /// 是否使用流式响应
  final bool stream;

  /// 请求超时时间（毫秒）
  final int timeoutMs;

  const ApiRequest({
    required this.url,
    this.headers = const {},
    this.body = const {},
    this.stream = false,
    this.timeoutMs = 30000,
  });
}

/// 通用 API 响应封装
sealed class ApiResponse<T> {
  const ApiResponse();
}

/// 成功响应
class ApiSuccess<T> extends ApiResponse<T> {
  /// 响应数据
  final T data;

  /// HTTP 状态码
  final int statusCode;

  /// 响应头
  final Map<String, String> headers;

  const ApiSuccess({
    required this.data,
    required this.statusCode,
    this.headers = const {},
  });
}

/// 失败响应
class ApiError<T> extends ApiResponse<T> {
  /// 错误码
  final String code;

  /// 错误消息
  final String message;

  /// HTTP 状态码（如有）
  final int? statusCode;

  /// 原始异常
  final Object? originalError;

  const ApiError({
    required this.code,
    required this.message,
    this.statusCode,
    this.originalError,
  });
}

// ———————————————————————————————— 异常类 ————————————————————————————————

/// 核心层异常基类
sealed class CoreException implements Exception {
  /// 错误消息
  final String message;

  /// 原始异常（可选）
  final Object? originalError;

  const CoreException(this.message, [this.originalError]);

  @override
  String toString() => '$runtimeType: $message';
}

/// 网络请求异常
class NetworkException extends CoreException {
  /// HTTP 状态码
  final int? statusCode;

  const NetworkException(super.message, [this.statusCode, super.originalError]);
}

/// LLM 调用异常
class LlmException extends CoreException {
  /// 使用的模型 ID
  final String? modelId;

  const LlmException(super.message, [this.modelId, super.originalError]);
}

/// 工具执行异常
class ToolException extends CoreException {
  /// 工具名称
  final String toolName;

  const ToolException(this.toolName, super.message, [super.originalError]);
}

/// 记忆系统异常
class MemoryException extends CoreException {
  const MemoryException(super.message, [super.originalError]);
}

/// Agent 执行异常
class AgentException extends CoreException {
  /// Agent 标识
  final String agentId;

  const AgentException(this.agentId, super.message, [super.originalError]);
}

/// 配置错误异常
class ConfigException extends CoreException {
  const ConfigException(super.message, [super.originalError]);
}

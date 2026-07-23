/// ============================================================================
/// 小酥 AI 助手 — LLM Provider 抽象接口
/// ============================================================================
/// 本文件定义 LLM 调用层的抽象接口和数据模型，包括：
///   - Message 层次模型 (SystemMessage / UserMessage / AssistantMessage / ToolMessage)
///   - 流式响应模型 (ChatChunk / ChatResponse)
///   - FunctionCall 模型
///   - MemoryStrategy 枚举
///   - LLMProvider 抽象类
/// ============================================================================

import '../common/models.dart';

// ———————————————————————————————— 消息模型 ————————————————————————————————

/// 消息 sealed 基类
///
/// 所有发送给 LLM 的消息都继承自此类，使用 sealed class 确保
/// pattern matching 的完备性检查。
sealed class LlmMessage {
  /// 消息角色标识
  String get role;

  /// 消息文本内容
  String get content;

  /// 转为 OpenAI API 格式的 Map
  Map<String, dynamic> toMap();
}

/// 系统消息 — 设定 LLM 角色和行为边界
class SystemMessage extends LlmMessage {
  @override
  final String content;

  SystemMessage(this.content);

  @override
  String get role => 'system';

  @override
  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

/// 用户消息 — 来自用户的输入
class UserMessage extends LlmMessage {
  @override
  final String content;

  UserMessage(this.content);

  @override
  String get role => 'user';

  @override
  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

/// 助手消息 — LLM 的回复
class AssistantMessage extends LlmMessage {
  @override
  final String content;

  /// 助手发起的工具调用列表（Function Calling）
  final List<FunctionCall> toolCalls;

  /// 完成原因：stop / tool_calls / length / content_filter
  final String? finishReason;

  /// 本次回复消耗的 token 数
  final int? usageTokens;

  AssistantMessage({
    required this.content,
    this.toolCalls = const [],
    this.finishReason,
    this.usageTokens,
  });

  @override
  String get role => 'assistant';

  /// 是否包含工具调用
  bool get hasToolCalls => toolCalls.isNotEmpty;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCalls.isNotEmpty) {
      map['tool_calls'] = toolCalls.map((tc) => tc.toMap()).toList();
    }
    return map;
  }
}

/// 工具结果消息 — 工具执行后回传给 LLM 的结果
class ToolMessage extends LlmMessage {
  @override
  final String content;

  /// 关联的工具调用 ID
  final String toolCallId;

  /// 工具名称
  final String name;

  ToolMessage({
    required this.content,
    required this.toolCallId,
    required this.name,
  });

  @override
  String get role => 'tool';

  @override
  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
        'tool_call_id': toolCallId,
        'name': name,
      };
}

// ———————————————————————————————— Function Call 模型 ————————————————————————————————

/// 函数调用
///
/// 表示 LLM 返回的一次函数/工具调用请求。
class FunctionCall {
  /// 调用 ID，用于关联后续的 ToolMessage
  final String id;

  /// 函数名称
  final String name;

  /// 函数参数（JSON 字符串）
  final String arguments;

  const FunctionCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// 解析参数为 Map
  Map<String, dynamic> get parsedArguments {
    try {
      // 注意：实际项目中应使用 dart:convert 的 jsonDecode
      // 此处简化处理，在完整项目中需导入 import 'dart:convert';
      return _parseJson(arguments);
    } catch (_) {
      return {};
    }
  }

  /// 简易 JSON 解析（实际项目请使用 dart:convert）
  static Map<String, dynamic> _parseJson(String json) {
    // 占位：实际项目使用 jsonDecode
    return {};
  }

  /// 转为 API 格式
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': arguments,
        },
      };

  @override
  String toString() => 'FunctionCall(id: $id, name: $name, args: $arguments)';
}

// ———————————————————————————————— 响应模型 ————————————————————————————————

/// 流式响应块
///
/// SSE 流中每个 data 事件解析后的中间结果。
/// 增量内容，需要调用方自行拼接。
class ChatChunk {
  /// 增量文本内容
  final String deltaContent;

  /// 增量工具调用（可能只有部分参数）
  final List<FunctionCall> deltaToolCalls;

  /// 完成原因（仅最后一个 chunk 有值）
  final String? finishReason;

  /// 原始数据（调试用）
  final Map<String, dynamic>? rawData;

  const ChatChunk({
    this.deltaContent = '',
    this.deltaToolCalls = const [],
    this.finishReason,
    this.rawData,
  });

  /// 是否为终止块
  bool get isDone => finishReason != null;
}

/// 完整对话响应
///
/// 非流式调用返回的完整结果。
class ChatResponse {
  /// 助手回复的完整消息
  final AssistantMessage message;

  /// 本次请求的 token 用量
  final TokenUsage usage;

  /// 原始响应数据（调试用）
  final Map<String, dynamic>? rawData;

  const ChatResponse({
    required this.message,
    required this.usage,
    this.rawData,
  });
}

/// Token 用量统计
class TokenUsage {
  /// 提示词 token 数
  final int promptTokens;

  /// 补全 token 数
  final int completionTokens;

  /// 总 token 数
  final int totalTokens;

  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  const TokenUsage.empty()
      : promptTokens = 0,
        completionTokens = 0,
        totalTokens = 0;
}

// ———————————————————————————————— 记忆策略 ————————————————————————————————

/// 记忆策略枚举
///
/// 决定对话历史如何被管理和裁剪，以适配不同模型的上下文窗口。
enum MemoryStrategy {
  /// 滑动窗口 — 只保留最近 N 轮对话
  slidingWindow,

  /// Token 截断 — 按 token 预算截断较早的消息
  tokenBudget,

  /// 摘要压缩 — 将旧对话压缩为摘要后拼入系统提示
  summaryCompression,

  /// RAG 检索 — 从长期记忆中检索相关片段注入上下文
  ragRetrieval,

  /// 混合策略 — 结合多种策略
  hybrid,
}

// ———————————————————————————————— LLM Provider 抽象类 ————————————————————————————————

/// LLM 提供者抽象接口
///
/// 所有 LLM 后端（OpenAI、通义千问、本地模型等）都必须实现此接口。
/// 支持流式和非流式两种调用方式，以及 Function Calling。
abstract class LlmProvider {
  /// Provider 唯一标识，如 "openai" / "qwen" / "local"
  String get providerId;

  /// 当前使用的模型 ID，如 "gpt-4o" / "qwen-max"
  String get modelId;

  /// 模型最大上下文 token 数
  int get maxContextTokens;

  /// 是否支持 Function Calling
  bool get supportsFunctionCalling;

  /// 是否支持流式输出
  bool get supportsStreaming;

  /// 当前 Provider 是否可用（检查 API Key、网络等）
  bool get isAvailable;

  /// 非流式对话调用
  ///
  /// [messages] 对话历史
  /// [tools] 可用工具列表（可选）
  /// [temperature] 温度参数 0.0~2.0
  /// [maxTokens] 最大输出 token 数
  /// [stop] 停止词列表
  Future<ChatResponse> chat({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
  });

  /// 流式对话调用
  ///
  /// 返回 Stream<ChatChunk>，每个元素为增量响应块。
  /// 调用方需要自行拼接 deltaContent 得到完整回复。
  Stream<ChatChunk> streamChat({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
  });

  /// 释放资源（关闭连接、清理缓存等）
  Future<void> dispose();

  @override
  String toString() => 'LlmProvider($providerId/$modelId)';
}

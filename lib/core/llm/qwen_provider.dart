/// ============================================================================
/// 小酥 AI 助手 — 通义千问 Provider 实现
/// ============================================================================
/// 基于阿里云 DashScope API 的 LLM Provider 实现，支持：
///   - qwen-max / qwen-plus / qwen-turbo 等模型
///   - 兼容 OpenAI 格式的 API 调用
///   - 流式输出 (SSE)
///   - Function Calling
/// 使用 Dio 作为 HTTP 客户端
/// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../common/models.dart';
import 'llm_provider.dart';

// TODO: 实际项目中需要导入 dio 包
// import 'package:dio/dio.dart';

/// 通义千问 API Provider
///
/// 封装阿里云 DashScope 的 OpenAI 兼容接口。
/// DashScope 支持 OpenAI 兼容格式，因此请求/响应格式与 OpenAI 高度一致，
/// 但在以下方面存在差异：
///   - API 地址：https://dashscope.aliyuncs.com/compatible-mode/v1
///   - 认证方式：Bearer <api-key>
///   - 模型名称：qwen-max, qwen-plus, qwen-turbo 等
///   - 部分参数命名可能略有差异
///
/// 支持模型（2024 年）：
///   - qwen-max          (32K context, 旗舰)
///   - qwen-max-longcontext (1M context)
///   - qwen-plus         (128K context, 性价比)
///   - qwen-turbo        (128K context, 快速)
class QwenProvider extends LlmProvider {
  // ———————— 配置字段 ————————

  @override
  final String providerId = 'qwen';

  @override
  final String modelId;

  @override
  final int maxContextTokens;

  @override
  bool get supportsFunctionCalling => true;

  @override
  bool get supportsStreaming => true;

  /// DashScope API 地址（OpenAI 兼容模式）
  final String baseUrl;

  /// DashScope API Key
  final String apiKey;

  /// 请求超时时间（毫秒）
  final int timeoutMs;

  // TODO: 实际项目中应为 Dio 实例
  // final Dio _dio;

  /// 模型上下文长度配置
  static const Map<String, int> _modelContextLimits = {
    'qwen-max': 32768,
    'qwen-max-longcontext': 1000000,
    'qwen-plus': 131072,
    'qwen-turbo': 131072,
    'qwen2.5-72b-instruct': 131072,
    'qwen2.5-32b-instruct': 131072,
    'qwen2.5-7b-instruct': 131072,
  };

  QwenProvider({
    required this.apiKey,
    this.modelId = 'qwen-plus',
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.timeoutMs = 60000,
    int? maxContextTokens,
  }) : maxContextTokens = maxContextTokens ??
            _modelContextLimits[modelId] ??
            131072;

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  // ———————————————————————————————— 请求构建 ————————————————————————————————

  /// 构建请求头
  ///
  /// DashScope 使用与 OpenAI 相同的 Bearer Token 认证。
  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// 构建请求体
  ///
  /// 通义千问 OpenAI 兼容模式的请求体格式与 OpenAI 基本一致。
  Map<String, dynamic> _buildRequestBody({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
    bool stream = false,
  }) {
    final body = <String, dynamic>{
      'model': modelId,
      'messages': messages.map((m) => m.toMap()).toList(),
      'temperature': temperature,
      'stream': stream,
    };

    // 通义千问支持 incremental_output 参数控制流式增量输出
    if (stream) {
      body['stream_options'] = {'include_usage': true};
    }

    // 工具声明（通义千问兼容 OpenAI function calling 格式）
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
      // 通义千问的 tool_choice 支持 "auto" / "none" / 指定函数
      body['tool_choice'] = 'auto';
    }

    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    if (stop != null && stop.isNotEmpty) {
      body['stop'] = stop;
    }

    return body;
  }

  // ———————————————————————————————— 非流式调用 ————————————————————————————————

  @override
  Future<ChatResponse> chat({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
  }) async {
    final body = _buildRequestBody(
      messages: messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      stop: stop,
      stream: false,
    );

    try {
      // TODO: 实际项目中使用 Dio 发送请求
      // final response = await _dio.post(
      //   '$baseUrl/chat/completions',
      //   options: Options(
      //     headers: _buildHeaders(),
      //     sendTimeout: Duration(milliseconds: timeoutMs),
      //     receiveTimeout: Duration(milliseconds: timeoutMs),
      //   ),
      //   data: body,
      // );
      // return _parseChatResponse(response.data);

      throw LlmException(
        '通义千问 API 调用尚未实际连接，需要配置 Dio 客户端',
        modelId,
      );
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException(
        '通义千问 API 调用失败: ${e.toString()}',
        modelId,
        e,
      );
    }
  }

  /// 解析通义千问非流式响应
  ///
  /// 响应格式与 OpenAI 兼容，但有些字段可能有差异。
  ChatResponse _parseChatResponse(Map<String, dynamic> json) {
    final choices = json['choices'] as List;
    if (choices.isEmpty) {
      throw LlmException('通义千问返回空 choices', modelId);
    }

    final choice = choices[0] as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    // 文本内容
    final content = message['content'] as String? ?? '';

    // 工具调用
    final toolCallsRaw = message['tool_calls'] as List?;
    final toolCalls = <FunctionCall>[];
    if (toolCallsRaw != null) {
      for (final tc in toolCallsRaw) {
        final tcMap = tc as Map<String, dynamic>;
        toolCalls.add(FunctionCall(
          id: tcMap['id'] as String,
          name: (tcMap['function'] as Map)['name'] as String,
          arguments: (tcMap['function'] as Map)['arguments'] as String,
        ));
      }
    }

    // Token 用量
    final usage = json['usage'] as Map<String, dynamic>?;

    return ChatResponse(
      message: AssistantMessage(
        content: content,
        toolCalls: toolCalls,
        finishReason: choice['finish_reason'] as String?,
      ),
      usage: usage != null
          ? TokenUsage(
              promptTokens: usage['prompt_tokens'] as int? ?? 0,
              completionTokens: usage['completion_tokens'] as int? ?? 0,
              totalTokens: usage['total_tokens'] as int? ?? 0,
            )
          : const TokenUsage.empty(),
      rawData: json,
    );
  }

  // ———————————————————————————————— 流式调用 ————————————————————————————————

  @override
  Stream<ChatChunk> streamChat({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
  }) {
    final controller = StreamController<ChatChunk>();

    _startStreamRequest(
      controller: controller,
      messages: messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      stop: stop,
    );

    return controller.stream;
  }

  /// 发起 SSE 流式请求
  Future<void> _startStreamRequest({
    required StreamController<ChatChunk> controller,
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    double temperature = 0.7,
    int? maxTokens,
    List<String>? stop,
  }) async {
    try {
      // TODO: 实际项目中使用 Dio 或 HttpClient 建立 SSE 连接
      // 实现方式与 OpenAI 类似：
      //
      // final response = await _dio.post(
      //   '$baseUrl/chat/completions',
      //   options: Options(
      //     headers: _buildHeaders(),
      //     responseType: ResponseType.stream,
      //   ),
      //   data: _buildRequestBody(
      //     messages: messages,
      //     tools: tools,
      //     temperature: temperature,
      //     maxTokens: maxTokens,
      //     stop: stop,
      //     stream: true,
      //   ),
      // );
      //
      // 逐行解析 SSE 事件...

      // 占位
      controller.add(ChatChunk(
        deltaContent: '[通义千问流式调用尚未实际连接]',
        finishReason: 'stop',
      ));
      await controller.close();
    } catch (e) {
      controller.addError(LlmException(
        '通义千问流式调用失败: ${e.toString()}',
        modelId,
        e,
      ));
      await controller.close();
    }
  }

  /// 解析 SSE 数据块
  ChatChunk _parseSSEChunk(Map<String, dynamic> json) {
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return const ChatChunk();
    }

    final choice = choices[0] as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>? ?? {};
    final finishReason = choice['finish_reason'] as String?;

    final content = delta['content'] as String? ?? '';

    // 工具调用增量
    final toolCallsRaw = delta['tool_calls'] as List?;
    final toolCalls = <FunctionCall>[];
    if (toolCallsRaw != null) {
      for (final tc in toolCallsRaw) {
        final tcMap = tc as Map<String, dynamic>;
        final func = tcMap['function'] as Map<String, dynamic>?;
        if (func != null) {
          toolCalls.add(FunctionCall(
            id: tcMap['id'] as String? ?? '',
            name: func['name'] as String? ?? '',
            arguments: func['arguments'] as String? ?? '',
          ));
        }
      }
    }

    return ChatChunk(
      deltaContent: content,
      deltaToolCalls: toolCalls,
      finishReason: finishReason,
      rawData: json,
    );
  }

  // ———————————————————————————————— 生命周期 ————————————————————————————————

  @override
  Future<void> dispose() async {
    // TODO: 释放 Dio 客户端
  }

  @override
  String toString() => 'QwenProvider(model=$modelId)';
}

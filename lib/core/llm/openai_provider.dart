/// ============================================================================
/// 小酥 AI 助手 — OpenAI Provider 实现
/// ============================================================================
/// 基于 OpenAI API 的 LLM Provider 实现，支持：
///   - GPT-4o / GPT-4o-mini 等模型
///   - 流式输出 (SSE)
///   - Function Calling
///   - Token 用量统计
/// 使用 Dio 作为 HTTP 客户端
/// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../common/models.dart';
import 'llm_provider.dart';

// TODO: 实际项目中需要导入 dio 包
// import 'package:dio/dio.dart';

/// OpenAI API Provider
///
/// 封装 OpenAI Chat Completions API 的调用细节，
/// 统一实现 [LlmProvider] 接口，供上层 Agent 使用。
///
/// 支持模型：
///   - gpt-4o          (128K context)
///   - gpt-4o-mini     (128K context)
///   - gpt-4-turbo     (128K context)
///   - gpt-3.5-turbo   (16K context)
class OpenAiProvider extends LlmProvider {
  // ———————— 配置字段 ————————

  @override
  final String providerId = 'openai';

  @override
  final String modelId;

  @override
  final int maxContextTokens;

  @override
  bool get supportsFunctionCalling => true;

  @override
  bool get supportsStreaming => true;

  /// API Base URL（默认 OpenAI 官方地址，可替换为兼容的第三方地址）
  final String baseUrl;

  /// API Key
  final String apiKey;

  /// 组织 ID（可选）
  final String? organizationId;

  /// 请求超时时间（毫秒）
  final int timeoutMs;

  // TODO: 实际项目中应为 Dio 实例
  // final Dio _dio;

  /// 预设模型配置表
  static const Map<String, int> _modelContextLimits = {
    'gpt-4o': 128000,
    'gpt-4o-mini': 128000,
    'gpt-4-turbo': 128000,
    'gpt-4': 8192,
    'gpt-3.5-turbo': 16385,
  };

  OpenAiProvider({
    required this.apiKey,
    this.modelId = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
    this.organizationId,
    this.timeoutMs = 60000,
    int? maxContextTokens,
  }) : maxContextTokens = maxContextTokens ??
            _modelContextLimits[modelId] ??
            128000;

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  // ———————————————————————————————— 请求构建 ————————————————————————————————

  /// 构建请求头
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (organizationId != null) {
      headers['OpenAI-Organization'] = organizationId!;
    }
    return headers;
  }

  /// 构建请求体
  ///
  /// [messages] 对话消息列表
  /// [tools] 工具声明列表
  /// [temperature] 温度参数
  /// [maxTokens] 最大输出 token
  /// [stop] 停止词
  /// [stream] 是否流式
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

    // 流式模式下请求增量输出
    if (stream) {
      body['stream_options'] = {'include_usage': true};
    }

    // 工具声明
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
      body['tool_choice'] = 'auto';
    }

    // 最大输出 token
    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    // 停止词
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
      //   options: Options(headers: _buildHeaders()),
      //   data: body,
      // );
      // return _parseChatResponse(response.data);

      // 占位：抛出未实现异常
      throw LlmException(
        'OpenAI API 调用尚未实际连接，需要配置 Dio 客户端',
        modelId,
      );
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException(
        'OpenAI API 调用失败: ${e.toString()}',
        modelId,
        e,
      );
    }
  }

  /// 解析非流式响应 JSON
  ChatResponse _parseChatResponse(Map<String, dynamic> json) {
    final choices = json['choices'] as List;
    if (choices.isEmpty) {
      throw LlmException('OpenAI 返回空 choices', modelId);
    }

    final choice = choices[0] as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    // 解析文本内容
    final content = message['content'] as String? ?? '';

    // 解析工具调用
    final toolCallsRaw = message['tool_calls'] as List?;
    final toolCalls = <FunctionCall>[];
    if (toolCallsRaw != null) {
      for (final tc in toolCallsRaw) {
        final tcMap = tc as Map<String, dynamic>;
        toolCalls.add(FunctionCall(
          id: tcMap['id'] as String,
          name: (tcMap['function'] as Map<String, dynamic>)['name'] as String,
          arguments:
              (tcMap['function'] as Map<String, dynamic>)['arguments'] as String,
        ));
      }
    }

    // 解析 token 用量
    final usage = json['usage'] as Map<String, dynamic>?;

    return ChatResponse(
      message: AssistantMessage(
        content: content,
        toolCalls: toolCalls,
        finishReason: choice['finish_reason'] as String?,
      ),
      usage: usage != null
          ? TokenUsage(
              promptTokens: usage['prompt_tokens'] as int,
              completionTokens: usage['completion_tokens'] as int,
              totalTokens: usage['total_tokens'] as int,
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
  ///
  /// 使用 Dio 的 ResponseType.stream 或 HttpClient 建立 SSE 连接，
  /// 逐行解析 "data: {...}" 格式的事件数据。
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
      // 示例伪代码：
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
      // final stream = (response.data as ResponseBody).stream;
      // final buffer = StringBuffer();
      //
      // await for (final chunk in stream.transform(utf8.decoder)) {
      //   buffer.write(chunk);
      //   final lines = buffer.toString().split('\n');
      //   buffer.clear();
      //   buffer.write(lines.last); // 保留不完整的行
      //
      //   for (final line in lines.sublist(0, lines.length - 1)) {
      //     final trimmed = line.trim();
      //     if (trimmed.isEmpty || trimmed == 'data: [DONE]') continue;
      //     if (!trimmed.startsWith('data: ')) continue;
      //
      //     final jsonStr = trimmed.substring(6);
      //     final event = _parseSSEChunk(jsonDecode(jsonStr));
      //     controller.add(event);
      //
      //     if (event.isDone) {
      //       await controller.close();
      //       return;
      //     }
      //   }
      // }

      // 占位：发送一个模拟事件后关闭
      controller.add(ChatChunk(
        deltaContent: '[OpenAI 流式调用尚未实际连接]',
        finishReason: 'stop',
      ));
      await controller.close();
    } catch (e) {
      controller.addError(LlmException(
        'OpenAI 流式调用失败: ${e.toString()}',
        modelId,
        e,
      ));
      await controller.close();
    }
  }

  /// 解析 SSE 流中的单个数据块
  ///
  /// OpenAI SSE 格式：
  /// ```json
  /// {
  ///   "id": "chatcmpl-xxx",
  ///   "choices": [{
  ///     "delta": { "content": "Hello" },
  ///     "finish_reason": null
  ///   }]
  /// }
  /// ```
  ChatChunk _parseSSEChunk(Map<String, dynamic> json) {
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return const ChatChunk();
    }

    final choice = choices[0] as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>? ?? {};
    final finishReason = choice['finish_reason'] as String?;

    // 解析增量内容
    final content = delta['content'] as String? ?? '';

    // 解析增量工具调用
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
    // _dio.close();
  }

  @override
  String toString() => 'OpenAiProvider(model=$modelId)';
}

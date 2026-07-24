// ============================================================================
// 小酥 - LLM Provider 基础接口 + Agent Provider + DeepSeek直连
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

/// LLM流式响应块
class LLMStreamChunk {
  final String content;
  final bool isDone;
  final String? finishReason;
  final int? tokenCount;

  const LLMStreamChunk({
    required this.content,
    this.isDone = false,
    this.finishReason,
    this.tokenCount,
  });
}

/// LLM完成结果
class LLMCompletionResult {
  final String content;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double latencyMs;

  const LLMCompletionResult({
    required this.content,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.latencyMs = 0,
  });

  int get totalTokensSum => totalTokens > 0 ? totalTokens : promptTokens + completionTokens;
}

/// 向后兼容的类型别名
typedef LlmProvider = BaseLlmProvider;

/// LLM Provider 基础接口
abstract class BaseLlmProvider {
  String get providerId;
  String get modelId;

  Future<LLMCompletionResult> complete({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
  });

  Stream<LLMStreamChunk> completeStream({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
  });

  Future<void> dispose() async {}
}

/// DeepSeek Provider（直连，保留兼容）
class AliyunDeepSeekProvider extends BaseLlmProvider {
  static final AliyunDeepSeekProvider instance = AliyunDeepSeekProvider._();
  AliyunDeepSeekProvider._();

  final http.Client _client = http.Client();

  @override
  String get providerId => 'deepseek';

  @override
  String get modelId => AppConfig.llmModel;

  String get _endpoint => AppConfig.llmEndpoint;
  String get _apiKey => AppConfig.llmApiKey;

  @override
  Future<LLMCompletionResult> complete({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
  }) async {
    final allMessages = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final body = {
      'model': modelId,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
      ...?extraParams,
    };

    final startTime = DateTime.now();
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (response.statusCode != 200) {
      throw Exception('LLM请求失败: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final choice = (data['choices'] as List).first;
    final usage = data['usage'] as Map<String, dynamic>?;

    return LLMCompletionResult(
      content: choice['message']['content'] as String,
      model: data['model'] as String? ?? modelId,
      promptTokens: usage?['prompt_tokens'] as int? ?? 0,
      completionTokens: usage?['completion_tokens'] as int? ?? 0,
      totalTokens: usage?['total_tokens'] as int? ?? 0,
      latencyMs: latency,
    );
  }

  @override
  Stream<LLMStreamChunk> completeStream({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
  }) async* {
    final allMessages = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final body = {
      'model': modelId,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
      ...?extraParams,
    };

    final request = http.Request('POST', Uri.parse(_endpoint));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    });
    request.body = jsonEncode(body);

    final response = await _client.send(request);

    final controller = StreamController<LLMStreamChunk>();

    response.stream.transform(utf8.decoder).listen(
      (data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr == '[DONE]') {
              controller.add(const LLMStreamChunk(content: '', isDone: true));
              continue;
            }
            try {
              final chunk = jsonDecode(jsonStr);
              final choices = chunk['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices.first['delta'];
                final content = delta?['content'] as String? ?? '';
                final finishReason = choices.first['finish_reason'] as String?;
                controller.add(LLMStreamChunk(
                  content: content,
                  isDone: finishReason != null,
                  finishReason: finishReason,
                ));
              }
            } catch (_) {}
          }
        }
      },
      onError: (error) {
        controller.addError(error);
      },
      onDone: () {
        controller.close();
      },
    );

    yield* controller.stream;
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

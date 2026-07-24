// ============================================================================
// 小酥 - OpenAI Provider
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

/// OpenAI兼容API Provider
class OpenAIProvider extends BaseLlmProvider {
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final http.Client _client = http.Client();

  OpenAIProvider({
    required String apiKey,
    String baseUrl = 'https://api.openai.com/v1',
    String model = 'gpt-3.5-turbo',
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _model = model;

  @override
  String get providerId => 'openai';

  @override
  String get modelId => _model;

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
      'model': _model,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
      ...?extraParams,
    };

    final startTime = DateTime.now();
    final response = await _client.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (response.statusCode != 200) {
      throw Exception('OpenAI请求失败: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final choice = (data['choices'] as List).first;
    final usage = data['usage'] as Map<String, dynamic>?;

    return LLMCompletionResult(
      content: choice['message']['content'] as String,
      model: data['model'] as String? ?? _model,
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
      'model': _model,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
      ...?extraParams,
    };

    final request = http.Request('POST', Uri.parse('$_baseUrl/chat/completions'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    });
    request.body = jsonEncode(body);

    final streamedResponse = await _client.send(request);
    final controller = StreamController<LLMStreamChunk>();

    streamedResponse.stream.transform(utf8.decoder).listen(
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
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    yield* controller.stream;
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

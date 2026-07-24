// ============================================================================
// 小酥 - 本地LLM引擎（Ollama/llama.cpp支持）
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../llm/llm_provider.dart';

/// 本地LLM引擎 - 支持Ollama和llama.cpp
class LocalLlmEngine {
  static final LocalLlmEngine instance = LocalLlmEngine._();
  LocalLlmEngine._();

  final http.Client _client = http.Client();

  /// 引擎类型
  String _engineType = 'none'; // none, ollama, llama_cpp
  String _baseUrl = '';
  bool _available = false;

  /// 引擎类型
  String get engineType => _engineType;

  /// 是否可用
  bool get isAvailable => _available;

  /// 检测Ollama是否可用
  Future<bool> detectOllama({String baseUrl = 'http://localhost:11434'}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _engineType = 'ollama';
        _baseUrl = baseUrl;
        _available = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 获取可用模型列表
  Future<List<String>> listModels() async {
    if (!_available) return [];

    try {
      if (_engineType == 'ollama') {
        final response = await _client.get(Uri.parse('$_baseUrl/api/tags'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = (data['models'] as List?)
              ?.map((m) => m['name'] as String)
              .toList();
          return models ?? [];
        }
      }
    } catch (_) {}
    return [];
  }

  /// 通过Ollama发送请求
  Future<LLMCompletionResult> complete({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
  }) async {
    if (_engineType != 'ollama') {
      throw Exception('本地LLM不可用');
    }

    final startTime = DateTime.now();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'stream': false,
        'options': {
          'temperature': temperature,
        },
      }),
    );

    final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (response.statusCode != 200) {
      throw Exception('本地LLM请求失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return LLMCompletionResult(
      content: data['message']?['content'] as String? ?? '',
      model: model,
      latencyMs: latency,
    );
  }

  /// 关闭
  void dispose() {
    _client.close();
    _available = false;
    _engineType = 'none';
  }
}

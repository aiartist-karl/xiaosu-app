// ============================================================================
// TTS Service (simplified - no flutter_tts dependency)
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../core/gateway/api_gateway.dart';

/// TTS voice service - uses remote TTS API
class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final ApiGateway _api = ApiGateway.instance;
  bool _useRemote = true;

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    final cleanText = _stripMarkdown(text);
    if (cleanText.isEmpty) return;
    if (_useRemote) {
      try {
        await _remoteSynthesize(cleanText);
      } catch (_) {}
    }
  }

  Future<void> stop() async {}

  Future<String> _remoteSynthesize(String text) async {
    try {
      final response = await _api.post(
        '/api/tts',
        body: {'text': text, 'voice': 'female_1', 'speed': 1.0},
        headers: {'Authorization': 'Bearer \${AppConfig.agentAuthToken}'},
      );
      if (response.success && response.data != null) {
        return response.data!['url'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }

  String _stripMarkdown(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r'\`\`\`[\s\S]*?\`\`\`'), '');
    result = result.replaceAll(RegExp(r'\`[^\`]+\`'), '');
    result = result.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    result = result.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(.*?\)'), (m) => m.group(1) ?? '');
    result = result.replaceAll(RegExp(r'^#+\s*'), '');
    result = result.replaceAll(RegExp(r'\*+([^*]+)\*+'), r'\$1');
    result = result.replaceAll(RegExp(r'^[-*+]\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\d+\.\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    return result.trim();
  }

  void dispose() {}
}

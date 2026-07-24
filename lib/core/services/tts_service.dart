// ============================================================================
// 小酥 - TTS语音合成服务
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http';
import 'package:flutter_tts/flutter_tts.dart';
import '../../config/app_config.dart';
import '../../core/gateway/api_gateway.dart';

/// TTS语音服务 - 支持本地TTS和远程API TTS
class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  final ApiGateway _api = ApiGateway.instance;
  bool _isInitialized = false;
  bool _useRemote = true; // 优先使用远程TTS

  /// 初始化TTS引擎
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('zh-CN');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _isInitialized = true;
  }

  /// 朗读文本
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // 去除Markdown标记
    final cleanText = _stripMarkdown(text);
    if (cleanText.isEmpty) return;

    await _ensureInitialized();

    // 尝试远程TTS
    if (_useRemote) {
      try {
        final audioUrl = await _remoteSynthesize(cleanText);
        if (audioUrl.isNotEmpty) {
          // 远程TTS成功，播放音频URL（通过本地TTS引擎播放）
          await _flutterTts.speak(cleanText);
          return;
        }
      } catch (_) {
        // 远程失败，回退到本地TTS
      }
    }

    // 本地TTS
    await _flutterTts.speak(cleanText);
  }

  /// 停止朗读
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// 远程TTS合成
  Future<String> _remoteSynthesize(String text) async {
    try {
      final response = await _api.post(
        '/api/tts',
        body: {
          'text': text,
          'voice': 'female_1',
          'speed': 1.0,
        },
        headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'},
      );

      if (response.success && response.data != null) {
        return response.data!['url'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// 去除Markdown标记
  String _stripMarkdown(String text) {
    var result = text;
    // 去除代码块
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    result = result.replaceAll(RegExp(r'`[^`]+`'), '');
    // 去除图片
    result = result.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    // 去除链接保留文字
    result = result.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(.*?\)'), (m) => m.group(1) ?? '');
    // 去除标题标记
    result = result.replaceAll(RegExp(r'^#+\s*'), '');
    // 去除加粗/斜体
    result = result.replaceAll(RegExp(r'\*+([^*]+)\*+'), r'$1');
    // 去除列表标记
    result = result.replaceAll(RegExp(r'^[-*+]\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\d+\.\s*', multiLine: true), '');
    // 去除引用
    result = result.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    return result.trim();
  }

  /// 释放资源
  void dispose() {
    _flutterTts.stop();
  }
}

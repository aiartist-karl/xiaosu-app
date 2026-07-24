// ============================================================================
// 小酥 - Agent API 服务（SSE流式 + 全量API）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../models/agent_message.dart';

/// Agent API 服务 - 处理与后端Agent的所有通信
class AgentApiService {
  static final AgentApiService instance = AgentApiService._();
  AgentApiService._();

  final http.Client _client = http.Client();
  final Set<String> _activeRequests = {};

  String get _base => AppConfig.agentApiBase;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AppConfig.agentAuthToken}',
  };

  // ==================== 聊天 SSE ====================

  Stream<AgentMessage> sendMessage({
    required String conversationId,
    required String message,
    List<Map<String, dynamic>>? history,
    List<String>? filePaths,
    String? replyTo,
  }) async* {
    final requestId = '${conversationId}_${message.hashCode}';
    if (_activeRequests.contains(requestId)) {
      yield AgentMessage(
        id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
        type: AgentMessageType.error,
        content: '',
        timestamp: DateTime.now(),
        errorMessage: '请求重复，已自动拦截',
      );
      return;
    }
    _activeRequests.add(requestId);

    try {
      final body = <String, dynamic>{
        'conversation_id': conversationId,
        'message': message,
        if (history != null) 'history': history,
        if (filePaths != null && filePaths.isNotEmpty) 'file_paths': filePaths,
        if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
      };

      final request = http.Request('POST', Uri.parse(AppConfig.agentChatEndpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Authorization': 'Bearer ${AppConfig.agentAuthToken}',
      });
      request.body = jsonEncode(body);

      late http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(AppConfig.connectTimeout);
      } catch (e) {
        yield AgentMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: AgentMessageType.error,
          content: '',
          timestamp: DateTime.now(),
          errorMessage: '连接失败: ${e.toString()}',
        );
        return;
      }

      if (response.statusCode != 200) {
        final errorBody = await response.stream.transform(utf8.decoder).join();
        yield AgentMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: AgentMessageType.error,
          content: '',
          timestamp: DateTime.now(),
          errorMessage: '服务端错误 (${response.statusCode}): $errorBody',
        );
        return;
      }

      String buffer = '';
      String currentEventType = '';

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(AppConfig.receiveTimeout, onTimeout: (sink) {
        sink.addError(TimeoutException('响应超时，请稍后重试'));
      })) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) { currentEventType = ''; continue; }
          if (trimmed.startsWith('event:')) { currentEventType = trimmed.substring(6).trim(); continue; }
          if (trimmed.startsWith('data:')) {
            final dataStr = trimmed.substring(5).trim();
            if (dataStr == '[DONE]') {
              yield AgentMessage(id: 'done_${DateTime.now().millisecondsSinceEpoch}', type: AgentMessageType.done, content: '', timestamp: DateTime.now());
              return;
            }
            try {
              final jsonData = jsonDecode(dataStr) as Map<String, dynamic>;
              final msg = _createMessage(currentEventType, jsonData);
              if (msg != null) yield msg;
            } catch (_) { continue; }
          }
        }
      }

      yield AgentMessage(id: 'done_${DateTime.now().millisecondsSinceEpoch}', type: AgentMessageType.done, content: '', timestamp: DateTime.now());
    } finally {
      _activeRequests.remove(requestId);
    }
  }

  AgentMessage? _createMessage(String eventType, Map<String, dynamic> json) {
    final now = DateTime.now();
    switch (eventType) {
      case 'thinking':
        return AgentMessage(id: 'thinking_${now.millisecondsSinceEpoch}', type: AgentMessageType.thinking, content: json['content'] as String? ?? '', timestamp: now);
      case 'text_delta':
        final content = json['content'] as String? ?? '';
        if (content.isEmpty) return null;
        return AgentMessage(id: 'delta_${now.millisecondsSinceEpoch}', type: AgentMessageType.answer, content: content, timestamp: now);
      case 'tool_call':
        return AgentMessage(id: json['id'] as String? ?? 'tool_${now.millisecondsSinceEpoch}', type: AgentMessageType.toolCall, content: '', timestamp: now, toolName: json['name'] as String? ?? 'unknown', toolArgs: json['arguments'] as Map<String, dynamic>?, callId: json['id'] as String?, toolStatus: ToolCallStatus.running);
      case 'tool_result':
        return AgentMessage(id: json['id'] as String? ?? 'result_${now.millisecondsSinceEpoch}', type: AgentMessageType.toolResult, content: '', timestamp: now, callId: json['id'] as String?, toolStatus: ToolCallStatus.success, toolResult: json['result'], toolName: json['name'] as String?);
      case 'tool_retry':
        return AgentMessage(id: 'retry_${now.millisecondsSinceEpoch}', type: AgentMessageType.toolCall, content: '', timestamp: now, toolName: json['name'] as String?, toolStatus: ToolCallStatus.running);
      case 'error':
        return AgentMessage(id: 'error_${now.millisecondsSinceEpoch}', type: AgentMessageType.error, content: '', timestamp: now, errorMessage: json['content'] as String? ?? json['error'] as String? ?? '未知错误');
      case 'done':
        return AgentMessage(id: 'done_${now.millisecondsSinceEpoch}', type: AgentMessageType.done, content: '', timestamp: now);
      case 'session':
        return null;
      default:
        final type = json['type'] as String?;
        if (type != null) {
          return AgentMessage(id: '${type}_${now.millisecondsSinceEpoch}', type: AgentMessageType.fromString(type), content: json['content'] as String? ?? '', timestamp: now);
        }
        return null;
    }
  }

  // ==================== 文件 API ====================

  Future<Map<String, dynamic>> getFiles({String path = ''}) async {
    try {
      final uri = Uri.parse('$_base/api/files').replace(queryParameters: {'path': path});
      final resp = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String getFileDownloadUrl(String filename) {
    return '$_base/api/files/download/${Uri.encodeComponent(filename)}';
  }

  Future<Map<String, dynamic>> uploadFile(String filePath, {String? fileName}) async {
    try {
      final uri = Uri.parse('$_base/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Authorization': 'Bearer ${AppConfig.agentAuthToken}'});
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      final response = await _client.send(request).timeout(const Duration(seconds: 60));
      final body = await response.stream.transform(utf8.decoder).join();
      if (response.statusCode == 200) return jsonDecode(body) as Map<String, dynamic>;
      throw Exception('上传失败: ${response.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Agent API ====================

  Future<Map<String, dynamic>> getAgents() async {
    try {
      final resp = await _client.get(Uri.parse('$_base/api/agents'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createAgent({required String name, String description = '', String systemPrompt = ''}) async {
    try {
      final resp = await _client.post(Uri.parse('$_base/api/agents'), headers: _headers,
        body: jsonEncode({'name': name, 'description': description, 'system_prompt': systemPrompt}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAgent(String agentId) async {
    try {
      final resp = await _client.delete(Uri.parse('$_base/api/agents/$agentId'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Memory API ====================

  Future<Map<String, dynamic>> getMemories() async {
    try {
      final resp = await _client.get(Uri.parse('$_base/api/memory'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> searchMemory(String query) async {
    try {
      final uri = Uri.parse('$_base/api/memory/search').replace(queryParameters: {'query': query});
      final resp = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveMemory({required String key, required String content, List<String>? tags}) async {
    try {
      final resp = await _client.post(Uri.parse('$_base/api/memory'), headers: _headers,
        body: jsonEncode({'key': key, 'content': content, if (tags != null) 'tags': tags}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMemory(String key) async {
    try {
      final resp = await _client.delete(Uri.parse('$_base/api/memory/$key'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Calendar API ====================

  Future<Map<String, dynamic>> getCalendar({int days = 7}) async {
    try {
      final uri = Uri.parse('$_base/api/calendar').replace(queryParameters: {'days': '$days'});
      final resp = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createCalendarEvent({required String title, required String dtstart, String? dtend, String? description}) async {
    try {
      final resp = await _client.post(Uri.parse('$_base/api/calendar'), headers: _headers,
        body: jsonEncode({'title': title, 'dtstart': dtstart, if (dtend != null) 'dtend': dtend, if (description != null) 'description': description}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCalendarEvent(String eventId) async {
    try {
      final resp = await _client.delete(Uri.parse('$_base/api/calendar/$eventId'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Tools API ====================

  Future<Map<String, dynamic>> executeTool({required String name, Map<String, dynamic>? arguments}) async {
    try {
      final resp = await _client.post(Uri.parse('$_base/api/tools/execute'), headers: _headers,
        body: jsonEncode({'name': name, 'arguments': arguments ?? {}}),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getBackendTools() async {
    try {
      final resp = await _client.get(Uri.parse('$_base/api/tools'), headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Health & Utility ====================

  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(Uri.parse('$_base/health'), headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'}).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _client.close();
    _activeRequests.clear();
  }
}

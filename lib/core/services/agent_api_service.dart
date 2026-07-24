// ============================================================================
// 小酥 - Agent API 服务（SSE流式通信）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../models/agent_message.dart';

/// Agent API 服务 - 处理与后端Agent的SSE通信
class AgentApiService {
  static final AgentApiService instance = AgentApiService._();
  AgentApiService._();

  final http.Client _client = http.Client();

  /// 发送聊天请求（SSE流式）
  Stream<AgentMessage> sendMessage({
    required String conversationId,
    required String message,
    List<Map<String, dynamic>>? history,
  }) async* {
    final body = {
      'conversation_id': conversationId,
      'message': message,
      if (history != null) 'history': history,
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

    // 解析SSE流
    String buffer = '';
    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .timeout(AppConfig.receiveTimeout, onTimeout: (sink) {
      sink.addError(TimeoutException('响应超时，请稍后重试'));
    })) {
      buffer += chunk;
      
      final lines = buffer.split('\n');
      // 最后一行可能不完整
      buffer = lines.removeLast();
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        if (trimmed.startsWith('data:')) {
          final dataStr = trimmed.substring(5).trim();
          
          if (dataStr == '[DONE]') {
            yield AgentMessage(
              id: 'done_${DateTime.now().millisecondsSinceEpoch}',
              type: AgentMessageType.done,
              content: '',
              timestamp: DateTime.now(),
            );
            return;
          }
          
          try {
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            yield AgentMessage.fromSSE(json);
          } catch (_) {
            continue;
          }
        }
      }
    }
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('${AppConfig.agentApiBase}/health'),
              headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'})
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 关闭连接
  void dispose() {
    _client.close();
  }
}

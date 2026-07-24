// ============================================================================
// 小酥 - Agent API 服务（SSE流式通信）- 防重复修复版
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
  
  // 防止重复请求的锁
  final Set<String> _activeRequests = {};

  /// 发送聊天请求（SSE流式）
  Stream<AgentMessage> sendMessage({
    required String conversationId,
    required String message,
    List<Map<String, dynamic>>? history,
    List<String>? filePaths,
  }) async* {
    // 生成请求唯一ID，防止重复
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
      final body = {
        'conversation_id': conversationId,
        'message': message,
        if (history != null) 'history': history,
        if (filePaths != null && filePaths.isNotEmpty) 'file_paths': filePaths,
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

      // 解析SSE流（修复：基于内容去重）
      String buffer = '';
      final Set<String> processedContentHashes = {};
      String lastContent = '';
      
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(AppConfig.receiveTimeout, onTimeout: (sink) {
        sink.addError(TimeoutException('响应超时，请稍后重试'));
      })) {
        buffer += chunk;
        
        final lines = buffer.split('\n');
        // 最后一行可能不完整，保留到下次处理
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
              final msg = AgentMessage.fromSSE(json);
              
              // 基于内容去重：跳过完全相同的text_delta
              if (msg.type.name == 'text_delta' && msg.content.isNotEmpty) {
                final contentHash = msg.content.hashCode.toString();
                if (processedContentHashes.contains(contentHash)) {
                  continue; // 跳过重复内容
                }
                processedContentHashes.add(contentHash);
                lastContent = msg.content;
              }
              
              yield msg;
            } catch (_) {
              continue;
            }
          }
        }
      }
    } finally {
      _activeRequests.remove(requestId);
    }
  }

  /// 上传文件到后端
  Future<Map<String, dynamic>> uploadFile(String filePath, {String? fileName}) async {
    try {
      final uri = Uri.parse('${AppConfig.agentApiBase}/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer ${AppConfig.agentAuthToken}',
      });
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      
      final response = await _client.send(request).timeout(const Duration(seconds: 60));
      final body = await response.stream.transform(utf8.decoder).join();
      
      if (response.statusCode == 200) {
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        throw Exception('上传失败: ${response.statusCode} - $body');
      }
    } catch (e) {
      throw Exception('上传失败: ${e.toString()}');
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
    _activeRequests.clear();
  }
}

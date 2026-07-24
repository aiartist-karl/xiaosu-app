// ============================================================================
// 小酥 - Agent API 服务（SSE流式通信）- 彻底重写版
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

      // 解析SSE流 - 正确解析 event: 和 data: 行
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
          
          // SSE事件边界（空行）
          if (trimmed.isEmpty) {
            currentEventType = '';
            continue;
          }
          
          // 解析 event: 行 - 获取真实的事件类型
          if (trimmed.startsWith('event:')) {
            currentEventType = trimmed.substring(6).trim();
            continue;
          }
          
          // 解析 data: 行
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
              final jsonData = jsonDecode(dataStr) as Map<String, dynamic>;
              final msg = _createMessage(currentEventType, jsonData);
              if (msg != null) {
                yield msg;
              }
            } catch (_) {
              continue;
            }
          }
        }
      }
      
      // 流结束但没收到done事件
      yield AgentMessage(
        id: 'done_${DateTime.now().millisecondsSinceEpoch}',
        type: AgentMessageType.done,
        content: '',
        timestamp: DateTime.now(),
      );
    } finally {
      _activeRequests.remove(requestId);
    }
  }

  /// 根据SSE event类型创建AgentMessage
  AgentMessage? _createMessage(String eventType, Map<String, dynamic> json) {
    final now = DateTime.now();
    
    switch (eventType) {
      case 'thinking':
        return AgentMessage(
          id: 'thinking_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.thinking,
          content: json['content'] as String? ?? '',
          timestamp: now,
        );

      case 'text_delta':
        final content = json['content'] as String? ?? '';
        if (content.isEmpty) return null;
        return AgentMessage(
          id: 'delta_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.answer,
          content: content,
          timestamp: now,
        );

      case 'tool_call':
        return AgentMessage(
          id: json['id'] as String? ?? 'tool_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.toolCall,
          content: '',
          timestamp: now,
          toolName: json['name'] as String? ?? 'unknown',
          toolArgs: json['arguments'] as Map<String, dynamic>?,
          callId: json['id'] as String?,
          toolStatus: ToolCallStatus.running,
        );

      case 'tool_result':
        return AgentMessage(
          id: json['id'] as String? ?? 'result_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.toolResult,
          content: '',
          timestamp: now,
          callId: json['id'] as String?,
          toolStatus: ToolCallStatus.success,
          toolResult: json['result'],
          toolName: json['name'] as String?,
        );

      case 'tool_retry':
        return AgentMessage(
          id: 'retry_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.toolCall,
          content: '',
          timestamp: now,
          toolName: json['name'] as String?,
          toolStatus: ToolCallStatus.running,
        );

      case 'error':
        return AgentMessage(
          id: 'error_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.error,
          content: '',
          timestamp: now,
          errorMessage: json['content'] as String? ?? json['error'] as String? ?? '未知错误',
        );

      case 'done':
        return AgentMessage(
          id: 'done_${now.millisecondsSinceEpoch}',
          type: AgentMessageType.done,
          content: '',
          timestamp: now,
        );

      case 'session':
        return null;

      default:
        final type = json['type'] as String?;
        if (type != null) {
          return AgentMessage(
            id: '${type}_${now.millisecondsSinceEpoch}',
            type: AgentMessageType.fromString(type),
            content: json['content'] as String? ?? '',
            timestamp: now,
          );
        }
        return null;
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

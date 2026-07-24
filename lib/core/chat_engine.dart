import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// 聊天引擎 - 管理SSE流式对话
class ChatEngine {
  static final ChatEngine _instance = ChatEngine._internal();
  factory ChatEngine() => _instance;
  ChatEngine._internal();

  final StreamController<ChatEvent> _eventController = 
      StreamController<ChatEvent>.broadcast();
  
  Stream<ChatEvent> get eventStream => _eventController.stream;
  
  String? _currentSessionId;
  bool _isStreaming = false;
  
  bool get isStreaming => _isStreaming;
  String? get sessionId => _currentSessionId;

  /// 发送消息并接收SSE流式回复
  Future<void> sendMessage(String message, {String? sessionId, String? replyTo}) async {
    if (_isStreaming) return;
    _isStreaming = true;
    
    final url = '${AppConfig.baseUrl}/chat';
    final body = jsonEncode({
      'message': message,
      'session_id': sessionId ?? _currentSessionId,
      if (replyTo != null) 'reply_to': replyTo,
      'stream': true,
    });

    try {
      final request = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.authToken}',
        },
        body: body,
      );

      if (request.statusCode != 200) {
        _eventController.add(ChatEvent.error('请求失败: ${request.statusCode}'));
        _isStreaming = false;
        return;
      }

      // 解析SSE流
      final lines = request.body.split('\n');
      String assistantContent = '';
      
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            _eventController.add(ChatEvent.done(assistantContent));
            break;
          }
          
          try {
            final event = jsonDecode(data);
            final type = event['type'] as String?;
            final eventData = event['data'] as Map<String, dynamic>?;
            
            if (type == null || eventData == null) continue;
            
            switch (type) {
              case 'text_delta':
                final content = eventData['content'] as String? ?? '';
                assistantContent += content;
                _eventController.add(ChatEvent.textDelta(content));
                break;
              case 'done':
                _eventController.add(ChatEvent.done(assistantContent));
                break;
              case 'error':
                final error = eventData['content'] as String? ?? '未知错误';
                _eventController.add(ChatEvent.error(error));
                break;
              // thinking, tool_call, tool_result - 不再处理，后端已不发送
              default:
                break;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
      
      if (!assistantContent.isEmpty && _isStreaming) {
        _eventController.add(ChatEvent.done(assistantContent));
      }
    } catch (e) {
      _eventController.add(ChatEvent.error('网络错误: $e'));
    } finally {
      _isStreaming = false;
    }
  }

  /// 获取历史消息
  Future<List<Map<String, dynamic>>> getHistory(String sessionId) async {
    final url = '${AppConfig.baseUrl}/history/$sessionId';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${AppConfig.authToken}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  void dispose() {
    _eventController.close();
  }
}

/// 聊天事件
class ChatEvent {
  final String type;
  final String content;
  
  ChatEvent._(this.type, this.content);
  
  factory ChatEvent.textDelta(String content) => ChatEvent._('text_delta', content);
  factory ChatEvent.done(String content) => ChatEvent._('done', content);
  factory ChatEvent.error(String content) => ChatEvent._('error', content);
}

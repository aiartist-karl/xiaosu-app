// ============================================================================
// 小酥 - Coze Studio LLM Provider
// 通过 Coze Studio 后端进行对话，支持 SSE 流式响应
// Phase 2: 使用 Session Cookie 认证
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../gateway/credential_manager.dart';
import 'llm_provider.dart';

/// Coze Studio 对话状态
enum CozeChatStatus {
  created,
  inProgress,
  completed,
  failed,
  requiresAction,
}

/// Coze Studio SSE 事件类型
enum CozeSSEEventType {
  conversationCreated, // Conversation.chat.created
  chatCreated,         // Conversation.chat.created
  messageDelta,        // Conversation.message.delta
  messageCompleted,    // Conversation.message.completed
  chatCompleted,       // Conversation.chat.completed
  error,               // Error
  done,                // Done
  unknown,
}

/// Coze Studio LLM Provider
/// 通过 Coze Studio 的 /v3/chat 接口发送消息
class CozeStudioProvider extends BaseLlmProvider {
  static final CozeStudioProvider instance = CozeStudioProvider._();
  CozeStudioProvider._();

  final http.Client _client = http.Client();

  // 当前会话 ID（多轮对话）
  String? _conversationId;
  
  // Session Key（认证凭证）
  String? _sessionKey;

  // Bot ID
  String get _botId => AppConfig.cozeStudioBotId;
  
  // User ID
  String get _userId => AppConfig.cozeStudioUserId;

  // 基础 URL
  String get _baseUrl => AppConfig.cozeStudioHost;

  @override
  String get providerId => 'coze_studio';

  @override
  String get modelId => AppConfig.deepseekModelIdInCoze;

  // ==========================================================================
  // 认证管理
  // ==========================================================================

  /// 初始化：从 CredentialManager 恢复 Session Key
  Future<void> init() async {
    final savedSession = await CredentialManager.instance.getCozeSessionKey();
    if (savedSession != null && savedSession.isNotEmpty) {
      _sessionKey = savedSession;
    }
  }

  /// 设置 Session Key
  void setSessionKey(String key) {
    _sessionKey = key;
    CredentialManager.instance.saveCozeSessionKey(key);
  }

  /// 获取当前 Session Key
  String? get sessionKey => _sessionKey;

  /// 检查是否已认证
  bool get isAuthenticated => _sessionKey != null && _sessionKey!.isNotEmpty;

  // ==========================================================================
  // 会话管理
  // ==========================================================================

  /// 获取当前会话 ID
  String? get conversationId => _conversationId;

  /// 设置会话 ID（用于多轮对话）
  void setConversationId(String id) {
    _conversationId = id;
  }

  /// 清除会话（开始新对话）
  void clearConversation() {
    _conversationId = null;
  }

  /// 创建新的会话
  Future<String?> createConversation() async {
    final url = Uri.parse('$_baseUrl${AppConfig.v1ConversationCreate}');
    final body = {
      'bot_id': _botId,
      'messages': [],
    };

    try {
      final response = await _client.post(
        url,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convId = data['data']?['id'] as String? ?? data['id'] as String?;
        if (convId != null) {
          _conversationId = convId;
        }
        return convId;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ==========================================================================
  // 核心对话接口
  // ==========================================================================

  @override
  Future<LLMCompletionResult> complete({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
    Map<String, dynamic>? extraParams,
  }) async {
    // 提取最后一条用户消息
    final userMessage = _extractLastUserMessage(messages);
    if (userMessage.isEmpty) {
      throw Exception('没有有效的用户消息');
    }

    // 确保有会话
    if (_conversationId == null) {
      await createConversation();
    }

    final startTime = DateTime.now();

    // 调用 /v3/chat（非流式）
    final url = Uri.parse('$_baseUrl${AppConfig.v3Chat}');
    final body = {
      'bot_id': _botId,
      'user_id': _userId,
      'conversation_id': _conversationId,
      'additional_messages': [
        {
          'role': 'user',
          'content': userMessage,
          'content_type': 'text',
        }
      ],
      'stream': false,
      ...?extraParams,
    };

    final response = await _client.post(
      url,
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );

    final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (response.statusCode != 200) {
      throw Exception('Coze Studio 请求失败: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final chatData = data['data'] ?? data;

    // 提取回复内容
    final chatId = chatData['id'] as String?;
    final status = chatData['status'] as String?;

    // 获取消息列表以获取助手回复
    if (chatId != null && _conversationId != null) {
      final messages = await _fetchMessages(chatId);
      final assistantMessage = messages.lastWhere(
        (m) => m['role'] == 'assistant',
        orElse: () => <String, dynamic>{},
      );

      return LLMCompletionResult(
        content: assistantMessage['content'] as String? ?? '',
        model: modelId,
        promptTokens: chatData['usage']?['token_count'] as int? ?? 0,
        completionTokens: 0,
        totalTokens: chatData['usage']?['token_count'] as int? ?? 0,
        latencyMs: latency,
      );
    }

    return LLMCompletionResult(
      content: '',
      model: modelId,
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
    // 提取最后一条用户消息
    final userMessage = _extractLastUserMessage(messages);
    if (userMessage.isEmpty) {
      yield const LLMStreamChunk(content: '', isDone: true);
      return;
    }

    // 确保有会话
    if (_conversationId == null) {
      await createConversation();
    }

    // 调用 /v3/chat（流式 SSE）
    final url = Uri.parse('$_baseUrl${AppConfig.v3Chat}');
    final body = {
      'bot_id': _botId,
      'user_id': _userId,
      'conversation_id': _conversationId,
      'additional_messages': [
        {
          'role': 'user',
          'content': userMessage,
          'content_type': 'text',
        }
      ],
      'stream': true,
      ...?extraParams,
    };

    final request = http.Request('POST', url);
    request.headers.addAll({
      ..._buildHeaders(),
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode(body);

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception('Coze Studio 流式请求失败: ${streamedResponse.statusCode} $errorBody');
    }

    final controller = StreamController<LLMStreamChunk>();
    final buffer = StringBuffer();

    streamedResponse.stream
        .transform(utf8.decoder)
        .listen(
      (data) {
        buffer.write(data);
        final content = buffer.toString();
        final lines = content.split('\n');

        // 保留最后一行（可能不完整）
        if (lines.isNotEmpty && !lines.last.endsWith('\n')) {
          buffer.clear();
          buffer.write(lines.last);
          lines.removeLast();
        } else {
          buffer.clear();
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          // SSE 格式: "event: xxx\ndata: {...}\n\n"
          if (trimmed.startsWith('data:')) {
            final jsonStr = trimmed.substring(5).trim();
            if (jsonStr.isEmpty) continue;

            try {
              final event = jsonDecode(jsonStr);
              final eventType = _parseSSEEventType(event);

              switch (eventType) {
                case CozeSSEEventType.messageDelta:
                  // 增量内容
                  final deltaContent = event['content'] as String? ?? '';
                  if (deltaContent.isNotEmpty) {
                    controller.add(LLMStreamChunk(content: deltaContent));
                  }
                  break;

                case CozeSSEEventType.messageCompleted:
                  // 消息完成
                  final fullContent = event['content'] as String? ?? '';
                  controller.add(LLMStreamChunk(
                    content: '',
                    isDone: true,
                    finishReason: 'stop',
                  ));
                  break;

                case CozeSSEEventType.chatCompleted:
                  // 对话完成
                  controller.add(const LLMStreamChunk(
                    content: '',
                    isDone: true,
                    finishReason: 'stop',
                  ));
                  break;

                case CozeSSEEventType.error:
                  final errorMsg = event['message'] ?? event['msg'] ?? '未知错误';
                  controller.addError(Exception('Coze Studio 错误: $errorMsg'));
                  break;

                case CozeSSEEventType.done:
                  controller.add(const LLMStreamChunk(
                    content: '',
                    isDone: true,
                    finishReason: 'stop',
                  ));
                  break;

                default:
                  break;
              }
            } catch (_) {
              // 忽略 JSON 解析错误（可能是部分数据）
            }
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    yield* controller.stream;
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 构建认证头（使用 Session Cookie）
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_sessionKey != null) {
      headers['Cookie'] = 'session_key=$_sessionKey';
    }
    return headers;
  }

  /// 从消息列表中提取最后一条用户消息
  String _extractLastUserMessage(List<Map<String, dynamic>> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i]['role'] == 'user') {
        return messages[i]['content'] as String? ?? '';
      }
    }
    // 如果没有 user 角色，取最后一条
    if (messages.isNotEmpty) {
      return messages.last['content'] as String? ?? '';
    }
    return '';
  }

  /// 获取对话消息列表
  Future<List<Map<String, dynamic>>> _fetchMessages(String chatId) async {
    if (_conversationId == null) return [];

    final url = Uri.parse('$_baseUrl${AppConfig.v3ChatMessageList}').replace(
      queryParameters: {
        'conversation_id': _conversationId!,
        'chat_id': chatId,
      },
    );

    try {
      final response = await _client.get(url, headers: _buildHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messagesList = data['data']?['messages'] as List? ?? [];
        return messagesList
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 解析 SSE 事件类型
  CozeSSEEventType _parseSSEEventType(Map<String, dynamic> event) {
    final eventStr = event['event'] as String? ?? '';
    final lowerEvent = eventStr.toLowerCase();

    if (lowerEvent.contains('conversation.created') || lowerEvent.contains('conversation.chat.created')) {
      return CozeSSEEventType.conversationCreated;
    } else if (lowerEvent.contains('message.delta') || lowerEvent.contains('conversation.message.delta')) {
      return CozeSSEEventType.messageDelta;
    } else if (lowerEvent.contains('message.completed') || lowerEvent.contains('conversation.message.completed')) {
      return CozeSSEEventType.messageCompleted;
    } else if (lowerEvent.contains('chat.completed') || lowerEvent.contains('conversation.chat.completed')) {
      return CozeSSEEventType.chatCompleted;
    } else if (lowerEvent.contains('error')) {
      return CozeSSEEventType.error;
    } else if (lowerEvent.contains('done')) {
      return CozeSSEEventType.done;
    }
    return CozeSSEEventType.unknown;
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

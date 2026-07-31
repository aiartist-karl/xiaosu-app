// ============================================================================
// 小酥 - Coze Studio LLM Provider
// 通过 Coze Studio 后端进行对话，支持 SSE 流式响应
// Phase 2: 使用 Session Cookie 认证
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
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
  conversationCreated,    // Conversation.chat.created
  conversationInProgress, // Conversation.chat.in_progress
  chatCreated,            // Conversation.chat.created
  messageDelta,           // Conversation.message.delta
  messageCompleted,       // Conversation.message.completed
  chatCompleted,          // Conversation.chat.completed
  error,                  // Error
  done,                   // Done
  unknown,
}

/// Coze Studio LLM Provider
/// 通过 Coze Studio 的 /v3/chat 接口发送消息
/// v3/v1 OpenAPI 使用 PAT Bearer Token 认证
/// 内部 API 使用 Session Cookie 认证
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
  // 平台感知 HTTP 方法（解决 Flutter Web http包 bodyBytes 为空/编码错误问题）
  // Web 端：dart:html HttpRequest + arraybuffer → 手动 utf8.decode
  // Native 端：http.Client
  // ==========================================================================

  /// POST JSON 请求，返回 (statusCode, bodyText)
  Future<(int?, String)> _postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    String acceptHeader = 'application/json',
  }) async {
    if (kIsWeb) {
      // 用 blob responseType 获取原始字节，避免浏览器默认 Latin-1 解码
      final completer = Completer<String>();
      final xhr = html.HttpRequest();
      xhr.open('POST', url.toString());
      xhr.responseType = 'blob';
      for (final entry in headers.entries) {
        xhr.setRequestHeader(entry.key, entry.value);
      }
      xhr.setRequestHeader('Accept', acceptHeader);
      xhr.onLoad.listen((_) {
        final blob = xhr.response as html.Blob;
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) {
          final text = reader.result as String;
          completer.complete(text);
        });
        reader.readAsText(blob, 'utf-8');
      });
      xhr.onError.listen((_) {
        completer.completeError(Exception('HTTP request failed'));
      });
      xhr.send(body);
      final text = await completer.future;
      return (xhr.status, text);
    } else {
      final resp = await _client.post(url, headers: headers, body: body);
      final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
      return (resp.statusCode, text);
    }
  }

  /// GET JSON 请求，返回 (statusCode, bodyText)
  Future<(int?, String)> _getJson(
    Uri url, {
    required Map<String, String> headers,
    String acceptHeader = 'application/json',
  }) async {
    if (kIsWeb) {
      final completer = Completer<String>();
      final xhr = html.HttpRequest();
      xhr.open('GET', url.toString());
      xhr.responseType = 'blob';
      for (final entry in headers.entries) {
        xhr.setRequestHeader(entry.key, entry.value);
      }
      xhr.setRequestHeader('Accept', acceptHeader);
      xhr.onLoad.listen((_) {
        final blob = xhr.response as html.Blob;
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) {
          final text = reader.result as String;
          completer.complete(text);
        });
        reader.readAsText(blob, 'utf-8');
      });
      xhr.onError.listen((_) {
        completer.completeError(Exception('HTTP request failed'));
      });
      xhr.send();
      final text = await completer.future;
      return (xhr.status, text);
    } else {
      final resp = await _client.get(url, headers: headers);
      final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
      return (resp.statusCode, text);
    }
  }

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

  /// 创建新的会话（v1 API，PAT 认证）
  Future<String?> createConversation() async {
    final url = Uri.parse('$_baseUrl${AppConfig.v1ConversationCreate}');
    final body = {
      'bot_id': _botId,
      'messages': [],
    };

    try {
      final (status, bodyText) = await _postJson(
        url,
        headers: _buildHeaders(usePAT: true),
        body: jsonEncode(body),
      );

      if (status == 200) {
        final data = jsonDecode(bodyText);
        final convId = data['data']?['id'];
        if (convId != null) {
          _conversationId = convId.toString();
        }
        return convId?.toString();
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

    // 调用 /v3/chat（非流式）— PAT 认证
    // 注意：bot_id 和 conversation_id 必须以字符串发送（Hertz JSON 绑定对 int64 有 bug）
    final url = Uri.parse('$_baseUrl${AppConfig.v3Chat}');
    final body = <String, dynamic>{
      'bot_id': _botId,
      'user_id': _userId,
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
    if (_conversationId != null) {
      body['conversation_id'] = _conversationId;
    }

    final (statusCode, responseText) = await _postJson(
      url,
      headers: _buildHeaders(usePAT: true),
      body: jsonEncode(body),
    );

    final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (statusCode != 200) {
      throw Exception('Coze Studio 请求失败: $statusCode $responseText');
    }

    final data = jsonDecode(responseText);
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

    // 调用 /v3/chat（流式 SSE）— PAT 认证
    // bot_id / conversation_id 以字符串发送（Hertz JSON 绑定 bug）
    final url = Uri.parse('$_baseUrl${AppConfig.v3Chat}');
    final body = <String, dynamic>{
      'bot_id': _botId,
      'user_id': _userId,
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
    if (_conversationId != null) {
      body['conversation_id'] = _conversationId;
    }

    // ── SSE 请求处理（兼容 Web 和 Native）──────────────────────────
    // Web 端：dart:html HttpRequest + arraybuffer，手动 utf8.decode
    // Native 端：http.Client.post + utf8.decode(bodyBytes)
    final headers = {
      ..._buildHeaders(usePAT: true),
      'Accept': 'text/event-stream',
    };

    final (statusCode, bodyText) = await _postJson(
      url,
      headers: headers,
      body: jsonEncode(body),
      acceptHeader: 'text/event-stream',
    );

    if (statusCode != 200) {
      throw Exception('Coze Studio 请求失败: $statusCode $bodyText');
    }

    // 从完整响应体解析 SSE 事件
    final lines = bodyText.split('\n');
    String? lastEventName; // 记录上一个 event: 头的名称

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 捕获 event: 头
      if (trimmed.startsWith('event:')) {
        lastEventName = trimmed.substring(6).trim();
        continue;
      }

      // 处理 data: 行
      if (!trimmed.startsWith('data:')) continue;

      final jsonStr = trimmed.substring(5).trim();
      if (jsonStr.isEmpty) continue;

      try {
        final event = jsonDecode(jsonStr);
        final eventType = _parseSSEEventType(event, lastEventName);
        lastEventName = null; // 已消费，重置

        switch (eventType) {
          case CozeSSEEventType.messageDelta:
            // http.post 模式：响应已全部缓冲，delta 仅用于保持流式感觉
            // 但为避免与 messageCompleted 重复，这里不 yield content
            // （ChatEngine 的 buffer 会在 messageCompleted 时收到完整内容）
            break;

          case CozeSSEEventType.messageCompleted:
            // 只处理 answer 类型，过滤 follow_up / verbose 等内部消息
            if (event['type'] == 'answer') {
              final fullContent = event['content'] as String? ?? '';
              if (fullContent.isNotEmpty) {
                yield LLMStreamChunk(content: fullContent);
              }
            }
            break;

          case CozeSSEEventType.chatCompleted:
          case CozeSSEEventType.done:
            yield const LLMStreamChunk(
              content: '',
              isDone: true,
              finishReason: 'stop',
            );
            return;

          case CozeSSEEventType.error:
            final errorMsg = event['message'] ?? event['msg'] ?? '未知错误';
            throw Exception('Coze Studio 错误: $errorMsg');

          default:
            break;
        }
      } catch (e) {
        if (e is Exception) rethrow;
        // 忽略 JSON 解析错误
      }
    }

    // 如果遍历完所有事件仍未返回，发送完成信号
    yield const LLMStreamChunk(content: '', isDone: true, finishReason: 'stop');
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 构建认证头
  /// v3/v1 OpenAPI 使用 PAT Bearer Token；内部 API 使用 Session Cookie
  Map<String, String> _buildHeaders({bool usePAT = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (usePAT) {
      // v3/v1 OpenAPI 使用 PAT Bearer Token 认证
      headers['Authorization'] = 'Bearer ${AppConfig.patToken}';
    } else if (_sessionKey != null) {
      // 内部 API 使用 Session Cookie
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
      final (status, bodyText) = await _getJson(
        url,
        headers: _buildHeaders(usePAT: true),
      );
      if (status == 200) {
        final data = jsonDecode(bodyText);
        final messagesList = data['data']?['messages'] as List? ?? [];
        return messagesList
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 解析 SSE 事件类型
  CozeSSEEventType _parseSSEEventType(Map<String, dynamic> event, String? eventName) {
    // 优先使用 SSE event: 头（非流式模式下 JSON 中不含 event 字段）
    final effectiveEvent = eventName ?? (event['event'] as String? ?? '');
    final lowerEvent = effectiveEvent.toLowerCase();

    if (lowerEvent.contains('conversation.created') || lowerEvent.contains('conversation.chat.created')) {
      return CozeSSEEventType.conversationCreated;
    } else if (lowerEvent.contains('in_progress') && !lowerEvent.contains('message')) {
      return CozeSSEEventType.conversationInProgress;
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

// ============================================================================
// 小酥 - Coze Studio LLM Provider
// 通过 Coze Studio 后端进行对话，支持 SSE 流式响应
// Phase 2: 使用 Session Cookie 认证 + PAT Token 认证
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
  
  // 当前 chat ID（用于取消）
  String? _currentChatId;
  
  // Session Key（认证凭证）
  String? _sessionKey;

  // 流式取消标志
  bool _streamCancelled = false;

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
      // Web 端：用 responseType='arraybuffer' 获取原始字节流
      // 再用 Uint8List + utf8.decode 手动解码，绕过浏览器默认 Latin-1
      final xhr = html.HttpRequest();
      xhr.open('POST', url.toString());
      xhr.responseType = 'arraybuffer';
      for (final entry in headers.entries) {
        xhr.setRequestHeader(entry.key, entry.value);
      }
      xhr.setRequestHeader('Accept', acceptHeader);

      final completer = Completer<(int?, String)>();
      xhr.onLoad.first.then((_) {
        final buffer = xhr.response;
        if (buffer is! ByteBuffer) {
          completer.completeError(Exception('XHR: not ArrayBuffer, got ${buffer.runtimeType}'));
          return;
        }
        final bytes = Uint8List.view(buffer);
        final text = utf8.decode(bytes, allowMalformed: true);
        completer.complete((xhr.status, text));
      });
      xhr.onError.first.then((_) {
        completer.completeError(Exception('XHR onError: ${xhr.statusText}'));
      });
      xhr.onAbort.first.then((_) {
        completer.completeError(Exception('XHR onAbort'));
      });

      xhr.send(body);
      return completer.future;
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
      final xhr = html.HttpRequest();
      xhr.open('GET', url.toString());
      xhr.responseType = 'arraybuffer';
      for (final entry in headers.entries) {
        xhr.setRequestHeader(entry.key, entry.value);
      }
      xhr.setRequestHeader('Accept', acceptHeader);
      final loadFuture = xhr.onLoad.first;
      xhr.send();
      await loadFuture;
      final buffer = xhr.response;
      if (buffer is! ByteBuffer) {
        throw Exception('XHR response is not ArrayBuffer, got ${buffer.runtimeType}');
      }
      final bytes = Uint8List.view(buffer);
      final text = utf8.decode(bytes, allowMalformed: true);
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

    // 获取消息列表以获取助手回复
    if (chatId != null && _conversationId != null) {
      final msgs = await _fetchMessages(chatId);
      final assistantMessage = msgs.lastWhere(
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

    final headers = {
      ..._buildHeaders(usePAT: true),
      'Accept': 'text/event-stream',
    };
    final bodyJson = jsonEncode(body);

    // 使用真正的流式读取
    _streamCancelled = false;
    final controller = StreamController<LLMStreamChunk>();

    if (kIsWeb) {
      _streamViaWebSSE(controller, url, headers, bodyJson);
    } else {
      _streamViaNativeSSE(controller, url, headers, bodyJson);
    }

    yield* controller.stream;
  }

  /// Web 端真正的流式 SSE 实现
  void _streamViaWebSSE(
    StreamController<LLMStreamChunk> controller,
    Uri url,
    Map<String, String> headers,
    String bodyJson,
  ) {
    final request = html.HttpRequest();
    request
      ..open('POST', url.toString())
      ..responseType = 'text'
      ..withCredentials = false;
    headers.forEach((key, value) {
      request.setRequestHeader(key, value);
    });
    request.setRequestHeader('Accept', 'text/event-stream');

    var lastLength = 0;
    var sseBuffer = StringBuffer();

    request.onProgress.listen((event) {
      if (_streamCancelled) {
        request.abort();
        if (!controller.isClosed) controller.close();
        return;
      }
      final responseText = request.responseText ?? '';
      if (responseText.length > lastLength) {
        final newData = responseText.substring(lastLength);
        lastLength = responseText.length;
        sseBuffer.write(newData);
        _processSSEBuffer(sseBuffer, controller);
      }
    });

    request.onLoad.listen((_) {
      // 处理最后可能剩余的数据
      _processSSEBuffer(sseBuffer, controller, isFinal: true);
      if (!controller.isClosed) controller.close();
    });

    request.onError.listen((e) {
      if (!controller.isClosed) {
        controller.addError(Exception('Web SSE 连接错误: $e'));
        controller.close();
      }
    });

    request.send(bodyJson);
  }

  /// Native 端真正的流式 SSE 实现（使用 http 包的 StreamedRequest）
  Future<void> _streamViaNativeSSE(
    StreamController<LLMStreamChunk> controller,
    Uri url,
    Map<String, String> headers,
    String bodyJson,
  ) async {
    final request = http.StreamedRequest(
      'POST',
      url,
    );
    headers.forEach((key, value) {
      request.headers[key] = value;
    });
    request.headers['Accept'] = 'text/event-stream';
    request.contentLength = bodyJson.length;

    try {
      // 发送请求体
      request.sink.add(utf8.encode(bodyJson));
      request.sink.close();

      // 获取流式响应
      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        controller.addError(Exception('HTTP ${streamedResponse.statusCode}: $errorBody'));
        controller.close();
        return;
      }

      // 真正的流式读取
      final sseBuffer = StringBuffer();
      await for (final bytes in streamedResponse.stream) {
        if (_streamCancelled) break;
        final chunk = utf8.decode(bytes, allowMalformed: true);
        sseBuffer.write(chunk);
        _processSSEBuffer(sseBuffer, controller);
      }

      // 处理最后剩余的数据
      _processSSEBuffer(sseBuffer, controller, isFinal: true);
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(Exception('Native SSE 连接错误: $e'));
      }
    } finally {
      if (!controller.isClosed) {
        controller.close();
      }
    }
  }

  /// 处理 SSE 缓冲区，提取完整事件并 yield
  void _processSSEBuffer(
    StringBuffer buffer,
    StreamController<LLMStreamChunk> controller, {
    bool isFinal = false,
  }) {
    final content = buffer.toString();
    // SSE 事件以双换行分隔
    final parts = content.split('\n\n');
    
    // 如果不是最后一次处理，保留最后一个可能不完整的部分
    final processCount = isFinal ? parts.length : parts.length - 1;
    
    for (var i = 0; i < processCount; i++) {
      final eventText = parts[i].trim();
      if (eventText.isEmpty) continue;

      String? eventName;
      final dataLines = <String>[];

      for (final line in eventText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('event:')) {
          eventName = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          dataLines.add(trimmed.substring(5).trim());
        }
      }

      final dataStr = dataLines.join('\n');
      if (dataStr.isEmpty) continue;

      try {
        final event = jsonDecode(dataStr) as Map<String, dynamic>;
        final sseType = _parseSSEEventType(event, eventName);
        final chunk = _mapSSEEventToChunk(sseType, event);
        if (chunk != null && !controller.isClosed) {
          controller.add(chunk);
        }
      } catch (_) {
        // JSON 解析失败，跳过
      }
    }

    // 更新缓冲区：保留未处理的部分
    buffer.clear();
    if (!isFinal && parts.isNotEmpty) {
      buffer.write(parts.last);
    }
  }

  /// 将 SSE 事件映射为 LLMStreamChunk
  LLMStreamChunk? _mapSSEEventToChunk(CozeSSEEventType type, Map<String, dynamic> event) {
    switch (type) {
      case CozeSSEEventType.messageDelta:
        // 实时输出 delta 内容
        final deltaContent = event['content'] as String? ?? '';
        if (deltaContent.isNotEmpty) {
          return LLMStreamChunk(content: deltaContent);
        }
        return null;

      case CozeSSEEventType.messageCompleted:
        // 记录 chat_id 用于取消
        final chatId = event['chat_id'] as String?;
        if (chatId != null) {
          _currentChatId = chatId;
        }
        // 对于 answer 类型，如果 delta 没有输出内容，这里兜底
        final completedContent = event['content'] as String? ?? '';
        if (completedContent.isNotEmpty && event['type'] == 'answer') {
          return LLMStreamChunk(content: completedContent);
        }
        return null;

      case CozeSSEEventType.chatCompleted:
      case CozeSSEEventType.done:
        return const LLMStreamChunk(
          content: '',
          isDone: true,
          finishReason: 'stop',
        );

      case CozeSSEEventType.error:
        final errorMsg = event['message'] ?? event['msg'] ?? '未知错误';
        throw Exception('Coze Studio 错误: $errorMsg');

      default:
        return null;
    }
  }

  @override
  Future<void> cancelStream() async {
    _streamCancelled = true;
    if (_conversationId == null || _currentChatId == null) return;
    final url = Uri.parse('$_baseUrl${AppConfig.v3ChatCancel}');
    final body = jsonEncode({
      'conversation_id': _conversationId,
      'chat_id': _currentChatId,
    });
    try {
      await _postJson(url, headers: _buildHeaders(usePAT: true), body: body);
    } catch (_) {}
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

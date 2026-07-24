// ============================================================================
// 小酥 - 对话引擎（支持Agent模式 + 直连模式 + 多会话管理）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import '../models/chat_message.dart';
import '../models/agent_message.dart';
import '../core/services/agent_api_service.dart';
import '../core/llm/llm_provider.dart';
import '../core/llm/llm_router.dart';
import '../core/memory/memory_center.dart';
import '../config/app_config.dart';
import 'common/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

/// 对话引擎 - 管理多轮对话、上下文和LLM交互
class ChatEngine {
  static final ChatEngine instance = ChatEngine._();
  ChatEngine._();

  final LlmRouter _router = LlmRouter.instance;
  final MemoryCenterService _memory = MemoryCenterService.instance;
  final AgentApiService _agentApi = AgentApiService.instance;

  final Map<String, List<ChatMessage>> _histories = {};
  final Map<String, List<AgentMessage>> _agentMessages = {};
  String? _activeConversationId;
  String _systemPrompt = '你是小酥，一个智能AI助手。你友好、聪明、乐于助人。请用中文回答用户的问题。';
  static const String _convStorageKey = 'xiaosu_conversations';

  void Function(ChatMessage message)? onMessageReceived;
  void Function(String error)? onError;
  void Function(AgentMessage message)? onAgentMessage;
  VoidCallback? onConversationsChanged;

  void initialize({dynamic llmProvider, dynamic memoryCenter, dynamic skillRegistry}) {
    _router.initialize();
    _memory.initialize();
  }

  void setSystemPrompt(String prompt) { _systemPrompt = prompt; }
  void setActiveConversation(String conversationId) {
    _activeConversationId = conversationId;
    _histories.putIfAbsent(conversationId, () => []);
  }
  List<ChatMessage> getHistory(String conversationId) => List.from(_histories[conversationId] ?? []);
  List<AgentMessage> getAgentMessages(String messageId) => _agentMessages[messageId] ?? [];
  List<String> get conversationIds => _histories.keys.toList();
  Map<String, int> get conversationSummary => _histories.map((k, v) => MapEntry(k, v.length));

  /// 发送消息（流式）
  Stream<ChatMessage> sendMessageStream({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
    List<String>? filePaths,
  }) async* {
    _histories.putIfAbsent(conversationId, () => []);
    final history = _histories[conversationId]!;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    history.add(userMsg);
    yield userMsg;
    _updateConversationMetadata(conversationId, content);

    if (AppConfig.useAgentMode) {
      yield* _sendAgentStream(conversationId: conversationId, content: content, history: history, filePaths: filePaths);
    } else {
      yield* _sendDirectStream(conversationId: conversationId, content: content, history: history, modelId: modelId, temperature: temperature);
    }
  }

  /// Agent模式 - 正确处理SSE事件流
  Stream<ChatMessage> _sendAgentStream({
    required String conversationId,
    required String content,
    required List<ChatMessage> history,
    List<String>? filePaths,
  }) async* {
    final msgId = 'agent_${DateTime.now().millisecondsSinceEpoch}';
    _agentMessages[msgId] = [];
    
    final answerBuffer = StringBuffer();
    final Set<String> processedToolCallIds = {};
    bool isCompleted = false;

    try {
      await for (final agentMsg in _agentApi.sendMessage(
        conversationId: conversationId,
        message: content,
        history: _buildApiHistory(history),
        filePaths: filePaths,
      )) {
        if (isCompleted) continue;
        _agentMessages[msgId]!.add(agentMsg);
        onAgentMessage?.call(agentMsg);

        switch (agentMsg.type) {
          case AgentMessageType.thinking:
            // 思考内容 - 通过metadata通知UI显示
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(), 'has_thinking': true},
            );
            break;

          case AgentMessageType.toolCall:
            // 工具调用 - 去重防止同一个工具调用重复推送
            final callId = agentMsg.callId ?? agentMsg.id;
            if (!processedToolCallIds.contains(callId)) {
              processedToolCallIds.add(callId);
              yield ChatMessage(
                id: msgId,
                conversationId: conversationId,
                content: answerBuffer.toString(),
                role: MessageRole.assistant,
                timestamp: DateTime.now(),
                status: MessageStatus.streaming,
                metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(), 'has_tool_call': true},
              );
            }
            break;

          case AgentMessageType.toolResult:
            // 工具结果 - 更新状态
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
            );
            break;

          case AgentMessageType.answer:
            // 文本增量 - 直接追加（后端发送的是text_delta增量内容）
            if (agentMsg.content.isNotEmpty) {
              answerBuffer.write(agentMsg.content);
            }
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
            );
            break;

          case AgentMessageType.error:
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.isNotEmpty ? answerBuffer.toString() : '⚠️ ${agentMsg.errorMessage ?? '发生错误'}',
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.error,
              metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
            );
            isCompleted = true;
            if (answerBuffer.isNotEmpty) {
              history.add(ChatMessage(
                id: msgId,
                conversationId: conversationId,
                content: answerBuffer.toString(),
                role: MessageRole.assistant,
                timestamp: DateTime.now(),
                status: MessageStatus.error,
                metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
              ));
            }
            break;

          case AgentMessageType.done:
            // 完成信号 - 不追加内容
            isCompleted = true;
            break;
        }
      }

      // 流结束 - 保存完整回复到历史
      if (answerBuffer.isNotEmpty && !isCompleted) {
        isCompleted = true;
      }
      
      if (answerBuffer.isNotEmpty) {
        final alreadyAdded = history.any((m) => m.id == msgId);
        if (!alreadyAdded) {
          history.add(ChatMessage(
            id: msgId,
            conversationId: conversationId,
            content: answerBuffer.toString(),
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            status: MessageStatus.completed,
            metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
          ));
        }
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        id: msgId,
        conversationId: conversationId,
        content: '⚠️ 错误：${e.toString()}',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      if (!history.any((m) => m.id == msgId)) {
        history.add(errorMsg);
      }
      yield errorMsg;
    }
  }

  /// 直连模式
  Stream<ChatMessage> _sendDirectStream({
    required String conversationId,
    required String content,
    required List<ChatMessage> history,
    String? modelId,
    double temperature = 0.7,
  }) async* {
    try {
      final complexity = _router.analyzeComplexity(content);
      final provider = _router.route(complexity: complexity, preferredModelId: modelId);
      final buffer = StringBuffer();
      final msgId = 'direct_${DateTime.now().millisecondsSinceEpoch}';

      await for (final chunk in provider.completeStream(
        messages: _buildMessages(history),
        temperature: temperature,
        systemPrompt: _systemPrompt,
      )) {
        if (chunk.isDone) break;
        buffer.write(chunk.content);
        yield ChatMessage(id: msgId, conversationId: conversationId, content: buffer.toString(), role: MessageRole.assistant, timestamp: DateTime.now(), status: MessageStatus.streaming);
      }

      final finalMsg = ChatMessage(id: msgId, conversationId: conversationId, content: buffer.toString(), role: MessageRole.assistant, timestamp: DateTime.now(), status: MessageStatus.completed);
      history.add(finalMsg);
      yield finalMsg;
    } catch (e) {
      yield ChatMessage(id: 'error_${DateTime.now().millisecondsSinceEpoch}', conversationId: conversationId, content: '错误：${e.toString()}', role: MessageRole.assistant, timestamp: DateTime.now(), status: MessageStatus.error);
    }
  }

  List<Map<String, dynamic>> _buildApiHistory(List<ChatMessage> history, {int maxContext = 20}) {
    final recent = history.length > maxContext ? history.sublist(history.length - maxContext) : history;
    return recent.map((msg) => msg.toApiFormat()).toList();
  }

  List<Map<String, dynamic>> _buildMessages(List<ChatMessage> history, {int maxContext = 20}) {
    final recent = history.length > maxContext ? history.sublist(history.length - maxContext) : history;
    return recent.map((msg) => msg.toApiFormat()).toList();
  }

  Future<void> _updateConversationMetadata(String conversationId, String lastMessage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_convStorageKey);
      List<dynamic> list = [];
      if (raw != null) { list = jsonDecode(raw) as List; }
      final idx = list.indexWhere((e) => (e as Map)['id'] == conversationId);
      final now = DateTime.now().toIso8601String();
      final msgCount = _histories[conversationId]?.length ?? 0;
      final userMsgs = _histories[conversationId]?.where((m) => m.role == MessageRole.user).toList() ?? [];
      final firstUserMsg = userMsgs.isNotEmpty ? userMsgs.first : null;
      String title = firstUserMsg != null && firstUserMsg.content.isNotEmpty
          ? (firstUserMsg.content.length > 30 ? '${firstUserMsg.content.substring(0, 30)}...' : firstUserMsg.content)
          : '新对话';
      
      if (idx >= 0) {
        list[idx] = {...Map<String, dynamic>.from(list[idx] as Map), 'updatedAt': now, 'messageCount': msgCount, 'lastMessage': lastMessage.length > 50 ? lastMessage.substring(0, 50) : lastMessage, 'title': title};
      } else {
        list.add({'id': conversationId, 'title': title, 'systemPrompt': '', 'modelId': 'deepseek-chat', 'status': 'active', 'messageCount': msgCount, 'lastMessage': lastMessage.length > 50 ? lastMessage.substring(0, 50) : lastMessage, 'createdAt': now, 'updatedAt': now});
      }
      await prefs.setString(_convStorageKey, jsonEncode(list));
      onConversationsChanged?.call();
    } catch (_) {}
  }

  void clearHistory(String conversationId) { _histories[conversationId]?.clear(); _agentMessages.removeWhere((k, _) => true); }
  void deleteConversation(String conversationId) {
    _histories.remove(conversationId);
    _agentMessages.removeWhere((k, _) => true);
    _deleteConversationFromStorage(conversationId);
  }

  Future<void> _deleteConversationFromStorage(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_convStorageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        list.removeWhere((e) => (e as Map)['id'] == conversationId);
        await prefs.setString(_convStorageKey, jsonEncode(list));
        onConversationsChanged?.call();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    _histories.clear();
    _agentMessages.clear();
    _agentApi.dispose();
    await _router.dispose();
  }
}

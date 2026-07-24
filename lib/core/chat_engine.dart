// ============================================================================
// 小酥 - 对话引擎（支持Agent模式 + 直连模式）
// ============================================================================

import 'dart:async';
import '../models/chat_message.dart';
import '../models/agent_message.dart';
import '../core/services/agent_api_service.dart';
import '../core/llm/llm_provider.dart';
import '../core/llm/llm_router.dart';
import '../core/memory/memory_center.dart';
import '../config/app_config.dart';
import 'common/models.dart';

/// 对话引擎 - 管理多轮对话、上下文和LLM交互
class ChatEngine {
  static final ChatEngine instance = ChatEngine._();
  ChatEngine._();

  final LlmRouter _router = LlmRouter.instance;
  final MemoryCenterService _memory = MemoryCenterService.instance;
  final AgentApiService _agentApi = AgentApiService.instance;

  // 每个对话的消息历史
  final Map<String, List<ChatMessage>> _histories = {};
  
  // Agent消息缓存（每个对话的最近一轮agent消息）
  final Map<String, List<AgentMessage>> _agentMessages = {};

  // 当前活跃的对话ID
  String? _activeConversationId;

  // 系统提示词
  String _systemPrompt = '你是小酥，一个智能AI助手。你友好、聪明、乐于助人。请用中文回答用户的问题。';

  // 回调
  void Function(ChatMessage message)? onMessageReceived;
  void Function(String error)? onError;
  void Function(AgentMessage message)? onAgentMessage;

  /// 初始化引擎
  void initialize({
    dynamic llmProvider,
    dynamic memoryCenter,
    dynamic skillRegistry,
  }) {
    _router.initialize();
    _memory.initialize();
  }

  /// 设置系统提示词
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  /// 设置活跃对话
  void setActiveConversation(String conversationId) {
    _activeConversationId = conversationId;
    _histories.putIfAbsent(conversationId, () => []);
  }

  /// 获取对话历史
  List<ChatMessage> getHistory(String conversationId) {
    return _histories[conversationId] ?? [];
  }

  /// 获取Agent消息
  List<AgentMessage> getAgentMessages(String messageId) {
    return _agentMessages[messageId] ?? [];
  }

  /// 发送消息（流式，支持Agent模式）
  Stream<ChatMessage> sendMessageStream({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
  }) async* {
    _histories.putIfAbsent(conversationId, () => []);
    final history = _histories[conversationId]!;

    // 创建用户消息
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    history.add(userMsg);
    yield userMsg;

    // 判断是否使用Agent模式
    if (AppConfig.useAgentMode) {
      yield* _sendAgentStream(conversationId: conversationId, content: content, history: history);
    } else {
      yield* _sendDirectStream(conversationId: conversationId, content: content, history: history, modelId: modelId, temperature: temperature);
    }
  }

  /// Agent模式：通过后端Agent API发送
  Stream<ChatMessage> _sendAgentStream({
    required String conversationId,
    required String content,
    required List<ChatMessage> history,
  }) async* {
    final msgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    _agentMessages[msgId] = [];
    
    final answerBuffer = StringBuffer();
    ChatMessage? lastYielded;

    try {
      await for (final agentMsg in _agentApi.sendMessage(
        conversationId: conversationId,
        message: content,
        history: _buildApiHistory(history),
      )) {
        // 缓存Agent消息
        _agentMessages[msgId]!.add(agentMsg);
        onAgentMessage?.call(agentMsg);

        // 处理不同类型
        switch (agentMsg.type) {
          case AgentMessageType.thinking:
            // 思考消息：更新状态为streaming
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

          case AgentMessageType.toolCall:
          case AgentMessageType.toolResult:
            // 工具调用消息：更新状态
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
            answerBuffer.write(agentMsg.content);
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
              content: answerBuffer.isNotEmpty
                  ? answerBuffer.toString()
                  : '⚠️ ${agentMsg.errorMessage ?? '发生错误'}',
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.error,
              metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
            );
            break;

          case AgentMessageType.done:
            break;
        }
      }

      // 完成
      final finalMsg = ChatMessage(
        id: msgId,
        conversationId: conversationId,
        content: answerBuffer.toString(),
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.completed,
        metadata: {'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList()},
      );
      history.add(finalMsg);
      yield finalMsg;
    } catch (e) {
      yield ChatMessage(
        id: msgId,
        conversationId: conversationId,
        content: '⚠️ 错误：${e.toString()}',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
    }
  }

  /// 直连模式：直接调用LLM
  Stream<ChatMessage> _sendDirectStream({
    required String conversationId,
    required String content,
    required List<ChatMessage> history,
    String? modelId,
    double temperature = 0.7,
  }) async* {
    try {
      final complexity = _router.analyzeComplexity(content);
      final provider = _router.route(
        complexity: complexity,
        preferredModelId: modelId,
      );

      final buffer = StringBuffer();
      final msgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();

      await for (final chunk in provider.completeStream(
        messages: _buildMessages(history),
        temperature: temperature,
        systemPrompt: _systemPrompt,
      )) {
        if (chunk.isDone) break;
        buffer.write(chunk.content);
        yield ChatMessage(
          id: msgId,
          conversationId: conversationId,
          content: buffer.toString(),
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          status: MessageStatus.streaming,
        );
      }

      final finalMsg = ChatMessage(
        id: msgId,
        conversationId: conversationId,
        content: buffer.toString(),
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.completed,
      );
      history.add(finalMsg);
      yield finalMsg;
    } catch (e) {
      yield ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        conversationId: conversationId,
        content: '错误：${e.toString()}',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
    }
  }

  /// 构建API历史消息
  List<Map<String, dynamic>> _buildApiHistory(List<ChatMessage> history, {int maxContext = 20}) {
    final recent = history.length > maxContext
        ? history.sublist(history.length - maxContext)
        : history;
    return recent.map((msg) => msg.toApiFormat()).toList();
  }

  /// 构建发送给LLM的消息列表
  List<Map<String, dynamic>> _buildMessages(List<ChatMessage> history, {int maxContext = 20}) {
    final recent = history.length > maxContext
        ? history.sublist(history.length - maxContext)
        : history;
    return recent.map((msg) => msg.toApiFormat()).toList();
  }

  /// 清空对话历史
  void clearHistory(String conversationId) {
    _histories[conversationId]?.clear();
    _agentMessages.removeWhere((k, _) => true);
  }

  /// 删除对话
  void deleteConversation(String conversationId) {
    _histories.remove(conversationId);
    _agentMessages.removeWhere((k, _) => true);
  }

  /// 获取所有对话ID
  List<String> get conversationIds => _histories.keys.toList();

  /// 释放资源
  Future<void> dispose() async {
    _histories.clear();
    _agentMessages.clear();
    _agentApi.dispose();
    await _router.dispose();
  }
}

// ============================================================================
// 小酥 - 对话引擎
// ============================================================================

import 'dart:async';
import '../models/chat_message.dart';
import '../core/llm/llm_provider.dart';
import '../core/llm/llm_router.dart';
import '../core/memory/memory_center.dart';
import 'common/models.dart';

/// 对话引擎 - 管理多轮对话、上下文和LLM交互
class ChatEngine {
  static final ChatEngine instance = ChatEngine._();
  ChatEngine._();

  final LlmRouter _router = LlmRouter.instance;
  final MemoryCenterService _memory = MemoryCenterService.instance;

  // 每个对话的消息历史
  final Map<String, List<ChatMessage>> _histories = {};
  
  // 当前活跃的对话ID
  String? _activeConversationId;

  // 系统提示词
  String _systemPrompt = '你是小酥，一个智能AI助手。你友好、聪明、乐于助人。请用中文回答用户的问题。';

  // 回调
  void Function(ChatMessage message)? onMessageReceived;
  void Function(String error)? onError;

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

  /// 发送消息（非流式）
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
  }) async {
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

    // 存储到短期记忆
    await _memory.addMemory(
      content: '用户: $content',
      type: MemoryType.shortTerm,
    );

    // 构建消息列表
    final messages = _buildMessages(history);

    try {
      // 路由到合适的的模型
      final complexity = _router.analyzeComplexity(content);
      final provider = _router.route(
        complexity: complexity,
        preferredModelId: modelId,
      );

      // 调用LLM
      final result = await provider.complete(
        messages: messages,
        temperature: temperature,
        systemPrompt: _systemPrompt,
      );

      // 创建助手消息
      final assistantMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        conversationId: conversationId,
        content: result.content,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        model: result.model,
        tokenCount: result.totalTokensSum,
        latency: result.latencyMs,
      );
      history.add(assistantMsg);

      // 存储到短期记忆
      await _memory.addMemory(
        content: '助手: ${result.content.substring(0, result.content.length.clamp(0, 200))}',
        type: MemoryType.shortTerm,
      );

      onMessageReceived?.call(assistantMsg);
      return assistantMsg;
    } catch (e) {
      final errorMsg = '抱歉，出现了错误：${e.toString()}';
      final errorMsgObj = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        conversationId: conversationId,
        content: errorMsg,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      history.add(errorMsgObj);
      onError?.call(e.toString());
      return errorMsgObj;
    }
  }

  /// 发送消息（流式）
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

    // 构建消息列表
    final messages = _buildMessages(history);

    try {
      final complexity = _router.analyzeComplexity(content);
      final provider = _router.route(
        complexity: complexity,
        preferredModelId: modelId,
      );

      final buffer = StringBuffer();
      final msgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();

      await for (final chunk in provider.completeStream(
        messages: messages,
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

      // 完成
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
  }

  /// 删除对话
  void deleteConversation(String conversationId) {
    _histories.remove(conversationId);
  }

  /// 获取所有对话ID
  List<String> get conversationIds => _histories.keys.toList();

  /// 释放资源
  Future<void> dispose() async {
    _histories.clear();
    await _router.dispose();
  }
}

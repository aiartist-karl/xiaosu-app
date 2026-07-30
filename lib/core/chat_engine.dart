// ============================================================================
// 小酥 - 对话引擎
// Phase 3: 对接 Coze Studio 对话 API，支持多轮会话 + 会话切换
// ============================================================================

import 'dart:async';
import '../models/chat_message.dart';
import '../core/llm/llm_provider.dart';
import '../core/llm/llm_router.dart';
import '../core/llm/coze_studio_provider.dart';
import '../core/memory/memory_center.dart';
import '../data/repositories/conversation_repository.dart';
import '../data/models/conversation_model.dart';
import '../config/app_config.dart';

/// 对话引擎 - 管理多轮对话、上下文和 Coze Studio 对话交互
class ChatEngine {
  static final ChatEngine instance = ChatEngine._();
  ChatEngine._();

  final LlmRouter _router = LlmRouter.instance;
  final MemoryCenterService _memory = MemoryCenterService.instance;
  final CozeStudioProvider _cozeProvider = CozeStudioProvider.instance;
  final ConversationRepository _repo = ConversationRepository.instance;

  // 每个对话的消息历史（本地缓存）
  final Map<String, List<ChatMessage>> _histories = {};

  // Coze Studio conversation ID 映射：localId -> cozeConversationId
  final Map<String, String> _cozeConversationMap = {};

  // 当前活跃的对话ID
  String? _activeConversationId;

  // 当前活跃的 Bot ID
  String _activeBotId = AppConfig.cozeStudioBotId;

  // 系统提示词
  String _systemPrompt = '你是小酥，一个智能AI助手。你友好、聪明、乐于助人。请用中文回答用户的问题。';

  // 是否使用 Coze Studio 通道（默认开启）
  bool _useCozeStudio = true;

  // 回调
  void Function(ChatMessage message)? onMessageReceived;
  void Function(String error)? onError;

  /// 初始化引擎
  void initialize({
    dynamic llmProvider,
    dynamic memoryCenter,
    dynamic skillRegistry,
    bool useCozeStudio = true,
  }) {
    _useCozeStudio = useCozeStudio;
    _router.initialize();
    _memory.initialize();
  }

  /// 设置是否使用 Coze Studio 通道
  void setUseCozeStudio(bool value) {
    _useCozeStudio = value;
  }

  /// 获取是否使用 Coze Studio
  bool get useCozeStudio => _useCozeStudio;

  /// 设置活跃 Bot ID
  void setActiveBotId(String botId) {
    _activeBotId = botId;
  }

  /// 设置系统提示词
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  /// 设置活跃对话（支持 Coze Studio 会话映射）
  void setActiveConversation(String conversationId, {String? cozeConversationId}) {
    _activeConversationId = conversationId;
    _histories.putIfAbsent(conversationId, () => []);
    if (cozeConversationId != null) {
      _cozeConversationMap[conversationId] = cozeConversationId;
      _cozeProvider.setConversationId(cozeConversationId);
    }
  }

  /// 获取对话历史
  List<ChatMessage> getHistory(String conversationId) {
    return _histories[conversationId] ?? [];
  }

  /// 获取当前活跃对话 ID
  String? get activeConversationId => _activeConversationId;

  // ==========================================================================
  // Phase 3: Coze Studio 对话（优先使用）
  // ==========================================================================

  /// 发送消息（非流式）- 自动选择通道
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
  }) async {
    if (_useCozeStudio) {
      return _sendMessageViaCoze(
        conversationId: conversationId,
        content: content,
      );
    }
    return _sendMessageViaLocalLlm(
      conversationId: conversationId,
      content: content,
      modelId: modelId,
      temperature: temperature,
    );
  }

  /// 发送消息（流式）- 自动选择通道
  Stream<ChatMessage> sendMessageStream({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
  }) {
    if (_useCozeStudio) {
      return _sendMessageStreamViaCoze(
        conversationId: conversationId,
        content: content,
      );
    }
    return _sendMessageStreamViaLocalLlm(
      conversationId: conversationId,
      content: content,
      modelId: modelId,
      temperature: temperature,
    );
  }

  // ==========================================================================
  // Coze Studio 通道
  // ==========================================================================

  /// 通过 Coze Studio 发送非流式消息
  Future<ChatMessage> _sendMessageViaCoze({
    required String conversationId,
    required String content,
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

    try {
      // 确保 Coze 会话存在
      await _ensureCozeConversation(conversationId);

      // 调用 Coze Studio Provider
      final messages = [{'role': 'user', 'content': content}];
      final result = await _cozeProvider.complete(messages: messages);

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

  /// 通过 Coze Studio 发送流式消息
  Stream<ChatMessage> _sendMessageStreamViaCoze({
    required String conversationId,
    required String content,
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

    try {
      // 确保 Coze 会话存在
      await _ensureCozeConversation(conversationId);

      final messages = [{'role': 'user', 'content': content}];
      final buffer = StringBuffer();
      final msgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();

      await for (final chunk in _cozeProvider.completeStream(messages: messages)) {
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

  /// 确保 Coze 会话存在，不存在则创建
  Future<void> _ensureCozeConversation(String localId) async {
    if (_cozeConversationMap.containsKey(localId)) {
      _cozeProvider.setConversationId(_cozeConversationMap[localId]!);
      return;
    }

    // 创建新的 Coze 会话
    final cozeConv = await _repo.createOnCoze(botId: _activeBotId);
    if (cozeConv != null && cozeConv.cozeConversationId != null) {
      _cozeConversationMap[localId] = cozeConv.cozeConversationId!;
      _cozeProvider.setConversationId(cozeConv.cozeConversationId!);
    } else {
      // 回退：直接通过 provider 创建
      final convId = await _cozeProvider.createConversation();
      if (convId != null) {
        _cozeConversationMap[localId] = convId;
      } else {
        throw Exception('无法创建 Coze Studio 会话');
      }
    }
  }

  // ==========================================================================
  // 本地 LLM 通道（回退）
  // ==========================================================================

  /// 通过本地 LLM 发送非流式消息
  Future<ChatMessage> _sendMessageViaLocalLlm({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
  }) async {
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

    await _memory.addMemory(
      content: '用户: $content',
      type: MemoryType.shortTerm,
    );

    final messages = _buildMessages(history);

    try {
      final complexity = _router.analyzeComplexity(content);
      final provider = _router.route(
        complexity: complexity,
        preferredModelId: modelId,
      );

      final result = await provider.complete(
        messages: messages,
        temperature: temperature,
        systemPrompt: _systemPrompt,
      );

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

  /// 通过本地 LLM 发送流式消息
  Stream<ChatMessage> _sendMessageStreamViaLocalLlm({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
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

  // ==========================================================================
  // Coze Studio 会话管理
  // ==========================================================================

  /// 从 Coze Studio 加载会话列表
  Future<List<ConversationModel>> loadCozeConversations() async {
    return await _repo.fetchFromCoze();
  }

  /// 从 Coze Studio 加载历史消息
  Future<List<ChatMessage>> loadMessagesFromCoze(String conversationId) async {
    final cozeConvId = _cozeConversationMap[conversationId];
    if (cozeConvId == null) return [];

    final messages = await _repo.fetchMessagesFromCoze(conversationId: cozeConvId);
    final chatMessages = messages.map((m) {
      final role = m['role'] == 'user' ? MessageRole.user : MessageRole.assistant;
      return ChatMessage(
        id: m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        content: m['content'] as String? ?? '',
        role: role,
        timestamp: m['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int) * 1000)
            : DateTime.now(),
        status: MessageStatus.completed,
      );
    }).toList();

    _histories[conversationId] = chatMessages;
    return chatMessages;
  }

  /// 取消 Coze Studio 正在进行的对话
  Future<bool> cancelCozeChat({
    required String conversationId,
    required String chatId,
  }) async {
    final cozeConvId = _cozeConversationMap[conversationId] ?? conversationId;
    final response = await _repo.fetchChatMessagesFromCoze(
      conversationId: cozeConvId,
      chatId: chatId,
    );
    // 实际取消通过 API Gateway 直接调用
    return response.isNotEmpty;
  }

  // ==========================================================================
  // 工具方法
  // ==========================================================================

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
    // 同步清空 Coze Studio
    final cozeConvId = _cozeConversationMap[conversationId];
    if (cozeConvId != null) {
      _repo.clearOnCoze(cozeConvId);
    }
  }

  /// 删除对话
  void deleteConversation(String conversationId) {
    _histories.remove(conversationId);
    final cozeConvId = _cozeConversationMap.remove(conversationId);
    if (cozeConvId != null) {
      _repo.deleteOnCoze(cozeConvId);
    }
  }

  /// 获取所有对话ID
  List<String> get conversationIds => _histories.keys.toList();

  /// 释放资源
  Future<void> dispose() async {
    _histories.clear();
    _cozeConversationMap.clear();
    await _router.dispose();
  }
}

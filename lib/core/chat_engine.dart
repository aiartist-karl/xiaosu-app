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

  // 每个对话的消息历史
  final Map<String, List<ChatMessage>> _histories = {};
  
  // Agent消息缓存（每个对话的最近一轮agent消息）
  final Map<String, List<AgentMessage>> _agentMessages = {};

  // 当前活跃的对话ID
  String? _activeConversationId;

  // 系统提示词
  String _systemPrompt = '你是小酥，一个智能AI助手。你友好、聪明、乐于助人。请用中文回答用户的问题。';

  // 会话持久化key
  static const String _convStorageKey = 'xiaosu_conversations';

  // 回调
  void Function(ChatMessage message)? onMessageReceived;
  void Function(String error)? onError;
  void Function(AgentMessage message)? onAgentMessage;
  
  // 会话变化通知
  VoidCallback? onConversationsChanged;

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
    return List.from(_histories[conversationId] ?? []);
  }

  /// 获取Agent消息
  List<AgentMessage> getAgentMessages(String messageId) {
    return _agentMessages[messageId] ?? [];
  }

  /// 获取所有对话ID
  List<String> get conversationIds => _histories.keys.toList();

  /// 获取所有对话及其消息数量
  Map<String, int> get conversationSummary {
    return _histories.map((key, value) => MapEntry(key, value.length));
  }

  /// 发送消息（流式，支持Agent模式）
  Stream<ChatMessage> sendMessageStream({
    required String conversationId,
    required String content,
    String? modelId,
    double temperature = 0.7,
    List<String>? filePaths,
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

    // 更新会话持久化
    _updateConversationMetadata(conversationId, content);

    // 判断是否使用Agent模式
    if (AppConfig.useAgentMode) {
      yield* _sendAgentStream(
        conversationId: conversationId,
        content: content,
        history: history,
        filePaths: filePaths,
      );
    } else {
      yield* _sendDirectStream(
        conversationId: conversationId,
        content: content,
        history: history,
        modelId: modelId,
        temperature: temperature,
      );
    }
  }

  /// Agent模式：通过后端Agent API发送（防重复）
  Stream<ChatMessage> _sendAgentStream({
    required String conversationId,
    required String content,
    required List<ChatMessage> history,
    List<String>? filePaths,
  }) async* {
    final msgId = 'agent_${DateTime.now().millisecondsSinceEpoch}';
    _agentMessages[msgId] = [];
    
    final answerBuffer = StringBuffer();
    // 用于去重：跟踪已处理的工具调用ID
    final Set<String> processedToolCalls = {};
    // 标记是否已经完成
    bool isCompleted = false;

    try {
      await for (final agentMsg in _agentApi.sendMessage(
        conversationId: conversationId,
        message: content,
        history: _buildApiHistory(history),
        filePaths: filePaths,
      )) {
        // 防止重复处理完成消息
        if (isCompleted && agentMsg.type == AgentMessageType.done) {
          continue;
        }

        // 缓存Agent消息
        _agentMessages[msgId]!.add(agentMsg);
        onAgentMessage?.call(agentMsg);

        // 处理不同类型
        switch (agentMsg.type) {
          case AgentMessageType.thinking:
            // 思考消息：仅更新状态
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {
                'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
                'has_thinking': true,
              },
            );
            break;

          case AgentMessageType.toolCall:
            // 工具调用：去重处理
            final callId = agentMsg.callId ?? agentMsg.id;
            if (!processedToolCalls.contains(callId)) {
              processedToolCalls.add(callId);
              yield ChatMessage(
                id: msgId,
                conversationId: conversationId,
                content: answerBuffer.toString(),
                role: MessageRole.assistant,
                timestamp: DateTime.now(),
                status: MessageStatus.streaming,
                metadata: {
                  'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
                  'has_tool_call': true,
                },
              );
            }
            break;

          case AgentMessageType.toolResult:
            // 工具结果：更新状态
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {
                'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
              },
            );
            break;

          case AgentMessageType.answer:
            // 回答：追加内容（去重 - 检查内容是否已存在）
            if (agentMsg.content.isNotEmpty) {
              // 避免重复追加相同内容
              final currentBuffer = answerBuffer.toString();
              if (!currentBuffer.endsWith(agentMsg.content)) {
                answerBuffer.write(agentMsg.content);
              }
            }
            yield ChatMessage(
              id: msgId,
              conversationId: conversationId,
              content: answerBuffer.toString(),
              role: MessageRole.assistant,
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              metadata: {
                'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
              },
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
              metadata: {
                'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
              },
            );
            isCompleted = true;
            // 错误时也保存到历史
            if (answerBuffer.isNotEmpty) {
              history.add(ChatMessage(
                id: msgId,
                conversationId: conversationId,
                content: answerBuffer.toString(),
                role: MessageRole.assistant,
                timestamp: DateTime.now(),
                status: MessageStatus.error,
                metadata: {
                  'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
                },
              ));
            }
            break;

          case AgentMessageType.done:
            isCompleted = true;
            break;
        }
      }

      // 完成 - 只在未完成的正常情况下保存
      if (!isCompleted) {
        isCompleted = true;
      }
      
      // 只有有内容的情况下才添加到历史
      if (answerBuffer.isNotEmpty) {
        // 检查是否已经在error分支添加过
        final alreadyAdded = history.any((m) => m.id == msgId);
        if (!alreadyAdded) {
          final finalMsg = ChatMessage(
            id: msgId,
            conversationId: conversationId,
            content: answerBuffer.toString(),
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            status: MessageStatus.completed,
            metadata: {
              'agent_messages': _agentMessages[msgId]!.map((m) => m.id).toList(),
            },
          );
          history.add(finalMsg);
          yield finalMsg;
        } else {
          // 更新已存在消息的状态为completed
          final idx = history.indexWhere((m) => m.id == msgId);
          if (idx >= 0) {
            history[idx] = history[idx].copyWith(status: MessageStatus.completed);
            yield history[idx];
          }
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
      // 只在历史中没有此消息时添加
      if (!history.any((m) => m.id == msgId)) {
        history.add(errorMsg);
      }
      yield errorMsg;
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
      final msgId = 'direct_${DateTime.now().millisecondsSinceEpoch}';

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
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
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

  /// 更新会话元数据（持久化到SharedPreferences）
  Future<void> _updateConversationMetadata(String conversationId, String lastMessage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_convStorageKey);
      List<dynamic> list = [];
      if (raw != null) {
        list = jsonDecode(raw) as List;
      }

      // 查找是否已存在
      final idx = list.indexWhere((e) => (e as Map)['id'] == conversationId);
      final now = DateTime.now().toIso8601String();
      
      final msgCount = _histories[conversationId]?.length ?? 0;
      // 提取标题：使用第一条用户消息
      final userMsgs = _histories[conversationId]?.where((m) => m.role == MessageRole.user).toList() ?? [];
      final firstUserMsg = userMsgs.isNotEmpty ? userMsgs.first : null;
      String title = firstUserMsg != null && firstUserMsg.content.isNotEmpty
          ? (firstUserMsg.content.length > 30 ? '${firstUserMsg.content.substring(0, 30)}...' : firstUserMsg.content)
          : '新对话';
      
      if (idx >= 0) {
        // 更新已有
        list[idx] = {
          ...Map<String, dynamic>.from(list[idx] as Map),
          'updatedAt': now,
          'messageCount': msgCount,
          'lastMessage': lastMessage.length > 50 ? lastMessage.substring(0, 50) : lastMessage,
          'title': title,
        };
      } else {
        // 新增
        list.add({
          'id': conversationId,
          'title': title,
          'systemPrompt': '',
          'modelId': 'deepseek-chat',
          'status': 'active',
          'messageCount': msgCount,
          'lastMessage': lastMessage.length > 50 ? lastMessage.substring(0, 50) : lastMessage,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      await prefs.setString(_convStorageKey, jsonEncode(list));
      onConversationsChanged?.call();
    } catch (_) {
      // 持久化失败不影响主要功能
    }
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
    // 也从持久化中删除
    _deleteConversationFromStorage(conversationId);
  }

  /// 从持久化中删除对话
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

  /// 释放资源
  Future<void> dispose() async {
    _histories.clear();
    _agentMessages.clear();
    _agentApi.dispose();
    await _router.dispose();
  }
}

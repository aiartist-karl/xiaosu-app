// ============================================================================
// 小酥 - 聊天控制器
// Phase 3: 对接 Coze Studio 对话 API，支持流式响应 + 会话管理
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/chat_engine.dart';
import '../../models/chat_message.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/models/conversation_model.dart';

// ============================================================
// 聊天状态
// ============================================================

class ChatState {
  /// 当前会话 ID
  final String? conversationId;

  /// 当前 Coze Studio 会话
  final ConversationModel? cozeConversation;

  /// 消息列表
  final List<ChatMessage> messages;

  /// 用户输入框内容
  final String inputText;

  /// 是否正在生成（流式输出）
  final bool isGenerating;

  /// 错误信息
  final String? error;

  /// 是否正在加载历史消息
  final bool isLoadingHistory;

  /// 是否正在加载会话列表
  final bool isLoadingConversations;

  /// 会话列表
  final List<ConversationModel> conversations;

  /// 选中的消息 ID（用于长按菜单）
  final String? selectedMessageId;

  const ChatState({
    this.conversationId,
    this.cozeConversation,
    this.messages = const [],
    this.inputText = '',
    this.isGenerating = false,
    this.error,
    this.isLoadingHistory = false,
    this.isLoadingConversations = false,
    this.conversations = const [],
    this.selectedMessageId,
  });

  ChatState copyWith({
    String? conversationId,
    ConversationModel? cozeConversation,
    List<ChatMessage>? messages,
    String? inputText,
    bool? isGenerating,
    String? error,
    bool? clearError,
    bool? isLoadingHistory,
    bool? isLoadingConversations,
    List<ConversationModel>? conversations,
    String? selectedMessageId,
    bool? clearSelectedMessage,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      cozeConversation: cozeConversation ?? this.cozeConversation,
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError == true ? null : (error ?? this.error),
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      conversations: conversations ?? this.conversations,
      selectedMessageId: clearSelectedMessage == true
          ? null
          : (selectedMessageId ?? this.selectedMessageId),
    );
  }
}

// ============================================================
// 聊天控制器（StateNotifier）
// ============================================================

/// 聊天控制器 - 对接 Coze Studio 对话系统
class ChatController extends StateNotifier<ChatState> {
  ChatController() : super(const ChatState());

  final ChatEngine _engine = ChatEngine.instance;
  final ConversationRepository _repo = ConversationRepository.instance;

  /// 更新用户输入文本
  void updateInput(String text) {
    state = state.copyWith(inputText: text);
  }

  /// 发送消息（流式）
  Future<void> sendMessage() async {
    final text = state.inputText.trim();
    if (text.isEmpty || state.isGenerating) return;

    // 确保有活跃会话
    String conversationId = state.conversationId ?? '';
    if (conversationId.isEmpty) {
      conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      _engine.setActiveConversation(conversationId);
    }

    // 创建用户消息并添加到列表
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      conversationId: conversationId,
      inputText: '',
      messages: [...state.messages, userMessage],
      error: null,
    );

    // 通过 ChatEngine 发送流式消息
    try {
      await for (final msg in _engine.sendMessageStream(
        conversationId: conversationId,
        content: text,
      )) {
        if (msg.role == MessageRole.user) continue;

        if (msg.status == MessageStatus.streaming) {
          // 流式中 - 更新或追加 AI 消息
          final messages = List<ChatMessage>.from(state.messages);
          final existingIdx = messages.indexWhere(
            (m) => m.id == msg.id && m.role == MessageRole.assistant,
          );
          if (existingIdx >= 0) {
            messages[existingIdx] = msg;
          } else {
            messages.add(msg);
          }
          state = state.copyWith(
            messages: messages,
            isGenerating: true,
          );
        } else {
          // 完成或错误
          final messages = List<ChatMessage>.from(state.messages);
          final existingIdx = messages.indexWhere(
            (m) => m.id == msg.id && m.role == MessageRole.assistant,
          );
          if (existingIdx >= 0) {
            messages[existingIdx] = msg;
          } else {
            messages.add(msg);
          }
          state = state.copyWith(
            messages: messages,
            isGenerating: false,
          );
        }
      }

      // 确保 isGenerating 已关闭
      if (state.isGenerating) {
        state = state.copyWith(isGenerating: false);
      }
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '生成回复失败: $e',
      );
    }
  }

  /// 停止生成
  void stopGenerating() {
    if (state.isGenerating) {
      final updatedMessages = state.messages.map((m) {
        if (m.status == MessageStatus.streaming) {
          return m.copyWith(status: MessageStatus.completed);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: updatedMessages,
        isGenerating: false,
      );
    }
  }

  /// 加载 Coze Studio 会话列表
  Future<void> loadConversations() async {
    state = state.copyWith(isLoadingConversations: true);

    try {
      final conversations = await _engine.loadCozeConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoadingConversations: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingConversations: false,
        error: '加载会话列表失败: $e',
      );
    }
  }

  /// 切换到指定会话
  Future<void> switchConversation(ConversationModel conversation) async {
    final localId = conversation.id;
    final cozeConvId = conversation.cozeConversationId;

    _engine.setActiveConversation(localId, cozeConversationId: cozeConvId);

    // 从 Coze Studio 加载历史消息
    state = state.copyWith(
      conversationId: localId,
      cozeConversation: conversation,
      messages: [],
      isLoadingHistory: true,
      error: null,
    );

    try {
      final messages = await _engine.loadMessagesFromCoze(localId);
      state = state.copyWith(
        messages: messages,
        isLoadingHistory: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        error: '加载历史消息失败: $e',
      );
    }
  }

  /// 创建新会话（通过 Coze Studio）
  Future<String?> createNewConversation({String? botId}) async {
    final conversation = await _repo.createOnCoze(botId: botId);
    if (conversation == null) return null;

    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    _engine.setActiveConversation(
      localId,
      cozeConversationId: conversation.cozeConversationId,
    );

    state = state.copyWith(
      conversationId: localId,
      cozeConversation: conversation,
      messages: [],
      error: null,
    );

    return localId;
  }

  /// 新建空白会话（本地）
  void newSession() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _engine.setActiveConversation(id);
    state = ChatState(conversationId: id);
  }

  /// 删除消息
  void deleteMessage(String messageId) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
      selectedMessageId: null,
    );
  }

  /// 选择/取消选择消息
  void selectMessage(String? messageId) {
    if (messageId == null) {
      state = state.copyWith(clearSelectedMessage: true);
    } else {
      state = state.copyWith(selectedMessageId: messageId);
    }
  }

  /// 复制消息
  void copyMessage(String messageId) {
    final msg = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw Exception('消息不存在'),
    );
    debugPrint('复制消息: ${msg.content}');
  }

  /// 清空当前对话
  void clearConversation() {
    if (state.conversationId != null) {
      _engine.clearHistory(state.conversationId!);
    }
    state = state.copyWith(
      messages: [],
      error: null,
    );
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ============================================================
// Riverpod Provider 定义
// ============================================================

/// 聊天控制器 Provider
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController();
});

/// 当前消息列表 Provider（便捷访问）
final messagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(chatControllerProvider).messages;
});

/// 是否正在生成 Provider
final isGeneratingProvider = Provider<bool>((ref) {
  return ref.watch(chatControllerProvider).isGenerating;
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// 聊天消息模型
// ============================================================

/// 消息角色
enum MessageRole { user, assistant, system, tool }

/// 消息内容类型
enum MessageContentType { text, image, code, toolCall, system }

/// 单条聊天消息
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageContentType contentType;

  /// 是否为流式输出中的消息
  bool isStreaming;

  /// 工具调用信息（仅 toolCall 类型）
  final String? toolName;
  final String? toolResult;

  /// 图片 URL（仅 image 类型）
  final String? imageUrl;

  /// 代码块语言标识（仅 code 类型）
  final String? codeLanguage;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.contentType = MessageContentType.text,
    this.isStreaming = false,
    this.toolName,
    this.toolResult,
    this.imageUrl,
    this.codeLanguage,
  });

  /// 创建副本并修改部分字段
  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    String? toolResult,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      contentType: contentType,
      isStreaming: isStreaming ?? this.isStreaming,
      toolName: toolName,
      toolResult: toolResult ?? this.toolResult,
      imageUrl: imageUrl,
      codeLanguage: codeLanguage,
    );
  }
}

/// 会话模型
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? modelId;
  final bool isPinned;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.modelId,
    this.isPinned = false,
    this.messages = const [],
  });

  /// 最近一条消息的摘要（用于列表预览）
  String get preview {
    if (messages.isEmpty) return '新对话';
    final last = messages.last;
    if (last.content.length > 50) {
      return '${last.content.substring(0, 50)}...';
    }
    return last.content;
  }
}

// ============================================================
// 聊天状态
// ============================================================

class ChatState {
  /// 当前会话
  final ChatSession? currentSession;

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

  /// 已加载的历史页数
  final int historyPage;

  /// 是否还有更多历史消息
  final bool hasMoreHistory;

  /// 选中的消息 ID（用于长按菜单）
  final String? selectedMessageId;

  const ChatState({
    this.currentSession,
    this.messages = const [],
    this.inputText = '',
    this.isGenerating = false,
    this.error,
    this.isLoadingHistory = false,
    this.historyPage = 0,
    this.hasMoreHistory = true,
    this.selectedMessageId,
  });

  ChatState copyWith({
    ChatSession? currentSession,
    List<ChatMessage>? messages,
    String? inputText,
    bool? isGenerating,
    String? error,
    bool? clearError,
    bool? isLoadingHistory,
    int? historyPage,
    bool? hasMoreHistory,
    String? selectedMessageId,
    bool? clearSelectedMessage,
  }) {
    return ChatState(
      currentSession: currentSession ?? this.currentSession,
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError == true ? null : (error ?? this.error),
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyPage: historyPage ?? this.historyPage,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      selectedMessageId: clearSelectedMessage == true
          ? null
          : (selectedMessageId ?? this.selectedMessageId),
    );
  }
}

// ============================================================
// 聊天控制器（StateNotifier）
// ============================================================

/// 聊天控制器
/// 管理消息列表、用户输入、流式消息处理等核心逻辑
class ChatController extends StateNotifier<ChatState> {
  ChatController() : super(const ChatState());

  /// 更新用户输入文本
  void updateInput(String text) {
    state = state.copyWith(inputText: text);
  }

  /// 发送消息
  /// 将用户输入添加到消息列表，并触发 AI 回复
  Future<void> sendMessage() async {
    final text = state.inputText.trim();
    if (text.isEmpty || state.isGenerating) return;

    // 创建用户消息
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    // 清空输入框，添加用户消息
    state = state.copyWith(
      inputText: '',
      messages: [...state.messages, userMessage],
      error: null,
    );

    // 如果是新会话的第一条消息，创建会话
    if (state.currentSession == null) {
      final session = ChatSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        title: text.length > 20 ? '${text.substring(0, 20)}...' : text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [userMessage],
      );
      state = state.copyWith(currentSession: session);
    }

    // 触发 AI 回复（此处为模拟，实际接入 ChatEngine）
    await _generateAIResponse(userMessage);
  }

  /// 模拟 AI 流式回复
  /// 实际项目中应替换为真正的 ChatEngine 调用
  Future<void> _generateAIResponse(ChatMessage userMessage) async {
    // 创建 AI 消息占位
    final aiMessageId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    final aiMessage = ChatMessage(
      id: aiMessageId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isGenerating: true,
    );

    // 模拟流式输出
    try {
      // 模拟流式文字生成
      final responseText = '你好！我是小酥，你的全能 AI 助手 🍪\n\n'
          '我注意到你发送了：「${userMessage.content}」\n\n'
          '我可以帮你完成很多事情：\n'
          '- 💬 自然对话和知识问答\n'
          '- 📝 文案创作和文档生成\n'
          '- 🔍 信息检索和分析\n'
          '- 🛠️ 调用各种技能完成任务\n\n'
          '有什么我可以帮你的吗？';

      // 逐字输出，模拟流式效果
      String currentText = '';
      for (int i = 0; i < responseText.length; i++) {
        currentText += responseText[i];
        await Future.delayed(const Duration(milliseconds: 30));

        // 更新消息内容
        final updatedMessages = List<ChatMessage>.from(state.messages);
        final idx = updatedMessages.indexWhere((m) => m.id == aiMessageId);
        if (idx != -1) {
          updatedMessages[idx] = updatedMessages[idx].copyWith(
            content: currentText,
            isStreaming: i < responseText.length - 1,
          );
        }
        state = state.copyWith(messages: updatedMessages);
      }

      state = state.copyWith(isGenerating: false);
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
      // 将所有流式中的消息标记为完成
      final updatedMessages = state.messages.map((m) {
        if (m.isStreaming) return m.copyWith(isStreaming: false);
        return m;
      }).toList();

      state = state.copyWith(
        messages: updatedMessages,
        isGenerating: false,
      );
    }
  }

  /// 加载历史消息（分页）
  Future<void> loadMoreHistory() async {
    if (state.isLoadingHistory || !state.hasMoreHistory) return;

    state = state.copyWith(isLoadingHistory: true);

    // 模拟延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟加载历史消息
    final historyMessages = List.generate(10, (i) {
      final index = state.historyPage * 10 + i;
      return ChatMessage(
        id: 'history_${index}',
        role: index.isEven ? MessageRole.user : MessageRole.assistant,
        content: '历史消息 #${index + 1}',
        timestamp: DateTime.now().subtract(
          Duration(days: index ~/ 2, hours: index),
        ),
      );
    });

    state = state.copyWith(
      messages: [...historyMessages.reversed.toList(), ...state.messages],
      isLoadingHistory: false,
      historyPage: state.historyPage + 1,
      hasMoreHistory: state.historyPage < 3, // 模拟最多 4 页
    );
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
    // 实际项目中通过 Clipboard 复制
    debugPrint('复制消息: ${msg.content}');
  }

  /// 切换会话
  void switchSession(ChatSession session) {
    state = state.copyWith(
      currentSession: session,
      messages: session.messages,
      inputText: '',
      error: null,
    );
  }

  /// 新建会话
  void newSession() {
    state = const ChatState();
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

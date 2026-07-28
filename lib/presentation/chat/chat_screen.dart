// ============================================================================
// 小酥 v2 - 聊天界面（动态状态栏 + 工具调用卡片 + 后台任务指示器）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/chat_engine.dart';
import '../../models/chat_message.dart';
import '../theme/app_colors.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';
import 'widgets/dynamic_status_bar.dart';
import 'widgets/tool_call_card.dart';
import 'widgets/background_task_indicator.dart';

/// 聊天界面
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? botName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.botName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatEngine _engine = ChatEngine.instance;
  final List<ChatMessage> _messages = [];
  final List<BackgroundTask> _backgroundTasks = [];
  final ScrollController _scrollController = ScrollController();

  StatusBarState _statusBarState = StatusBarState.idle;
  bool _isLoading = false;
  bool _isStreaming = false;
  String _selectedModel = 'Auto';
  String? _currentTaskName;

  // 每个消息关联的工具调用
  final Map<String, List<ToolCallInfo>> _messageToolCalls = {};

  @override
  void initState() {
    super.initState();
    _engine.setActiveConversation(widget.conversationId);
    _messages.addAll(_engine.getHistory(widget.conversationId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _isStreaming = false;
      _statusBarState = StatusBarState.connecting;
    });

    // 添加用户消息
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId,
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(userMsg));
    _scrollToBottom();

    try {
      // 创建助手消息占位
      final assistantMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        conversationId: widget.conversationId,
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.streaming,
      );
      setState(() {
        _messages.add(assistantMsg);
        _isStreaming = true;
        _statusBarState = StatusBarState.typing;
      });
      _scrollToBottom();

      await for (final msg in _engine.sendMessageStream(
        conversationId: widget.conversationId,
        content: text,
      )) {
        if (msg.role == MessageRole.user) continue;

        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last.role == MessageRole.assistant) {
            _messages[_messages.length - 1] = msg;
          }
        });
        _scrollToBottom();
      }

      // 完成
      setState(() {
        _isStreaming = false;
        _statusBarState = StatusBarState.idle;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversationId,
          content: '⚠️ 发送失败: $e',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        ));
        _isStreaming = false;
        _statusBarState = StatusBarState.idle;
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _showModelSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final models = ['Auto', 'DeepSeek', 'Qwen', 'GPT-4o'];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择模型',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              ...models.map((m) => ListTile(
                    leading: Icon(
                      _selectedModel == m ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _selectedModel == m
                          ? AppColors.primary(isDark)
                          : AppColors.textSecondary(isDark),
                    ),
                    title: Text(
                      m,
                      style: TextStyle(
                        color: _selectedModel == m
                            ? AppColors.primary(isDark)
                            : AppColors.textPrimary(isDark),
                        fontWeight: _selectedModel == m ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedModel = m);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.botName ?? '小酥'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 后台任务指示器
          BackgroundTaskIndicator(tasks: _backgroundTasks),
          const SizedBox(width: 8),
          // 更多菜单
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 消息列表 ───
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return MessageBubble(
                        message: msg,
                        toolCalls: _messageToolCalls[msg.id],
                      );
                    },
                  ),
          ),
          // ─── 动态状态栏 ───
          DynamicStatusBar(
            state: _statusBarState,
            taskName: _currentTaskName,
          ),
          // ─── 输入栏 ───
          ChatInput(
            onSend: _sendMessage,
            onModelSelect: _showModelSelector,
            onStop: () {
              // TODO: 停止生成
              setState(() {
                _isStreaming = false;
                _statusBarState = StatusBarState.idle;
              });
            },
            isLoading: _isLoading,
            isStreaming: _isStreaming,
            selectedModel: _selectedModel,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary(isDark).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🧠', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          Text(
            '你好，我是小酥！',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '有什么可以帮你的吗？',
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestionChip('🎨 生成一张图片', isDark),
              _suggestionChip('🔍 帮我搜索', isDark),
              _suggestionChip('📧 发送一封邮件', isDark),
              _suggestionChip('💡 给我个建议', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onPressed: () => _sendMessage(label.substring(2).trim()),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空对话'),
              onTap: () {
                Navigator.pop(context);
                _engine.clearHistory(widget.conversationId);
                setState(() => _messages.clear());
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制全部'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享对话'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

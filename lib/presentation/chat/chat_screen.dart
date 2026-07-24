// ============================================================================
// 小酥 - 聊天界面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/chat_engine.dart';
import '../../models/chat_message.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thinking_indicator.dart';

/// 聊天界面（完整版）
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatEngine _engine = ChatEngine.instance;
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

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
    setState(() => _isLoading = true);

    // 添加用户消息到本地
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId,
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
    });
    _scrollToBottom();

    try {
      // 使用流式响应
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
      });
      _scrollToBottom();

      await for (final msg in _engine.sendMessageStream(
        conversationId: widget.conversationId,
        content: text,
      )) {
        if (msg.role == MessageRole.user) continue;
        setState(() {
          // 更新最后一条助手消息
          if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
            _messages[_messages.length - 1] = msg;
          }
        });
        _scrollToBottom();
      }
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
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小酥'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _messages.length) {
                        return MessageBubble(message: _messages[index]);
                      }
                      return const ThinkingIndicator();
                    },
                  ),
          ),
          // 输入框
          ChatInput(onSend: _sendMessage, isLoading: _isLoading),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('你好，我是小酥！', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '有什么可以帮你的吗？',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _suggestionChip('🎨 生成一张图片'),
              _suggestionChip('🔍 帮我搜索'),
              _suggestionChip('📧 发送一封邮件'),
              _suggestionChip('💡 给我个建议'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      label: Text(label),
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
          ],
        ),
      ),
    );
  }
}

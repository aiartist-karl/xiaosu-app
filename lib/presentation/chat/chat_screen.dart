// ============================================================================
// 小酥 - 聊天界面（Agent完整版）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/chat_engine.dart';
import '../../models/chat_message.dart';
import '../../models/agent_message.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thinking_indicator.dart';

/// 聊天界面（Agent完整版）
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final ChatEngine _engine = ChatEngine.instance;
  final List<ChatMessage> _messages = [];
  final Map<String, List<AgentMessage>> _agentMessageMap = {};
  final Set<String> _streamingMessages = {};
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
      // 创建助手消息占位
      final assistantMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final assistantMsg = ChatMessage(
        id: assistantMsgId,
        conversationId: widget.conversationId,
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.streaming,
      );
      setState(() {
        _messages.add(assistantMsg);
        _streamingMessages.add(assistantMsgId);
      });
      _scrollToBottom();

      // 使用流式响应
      await for (final msg in _engine.sendMessageStream(
        conversationId: widget.conversationId,
        content: text,
      )) {
        if (msg.role == MessageRole.user) continue;

        // 获取Agent消息
        final agentMsgs = _engine.getAgentMessages(msg.id);

        setState(() {
          // 更新或替换消息
          final existingIdx = _messages.indexWhere((m) => m.id == msg.id);
          if (existingIdx >= 0) {
            _messages[existingIdx] = msg;
          } else {
            // 替换最后一条助手消息
            if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
              _messages[_messages.length - 1] = msg;
            }
          }

          // 更新Agent消息缓存
          if (agentMsgs.isNotEmpty) {
            _agentMessageMap[msg.id] = agentMsgs;
          }

          // 如果完成，移除streaming标记
          if (msg.status == MessageStatus.completed ||
              msg.status == MessageStatus.error) {
            _streamingMessages.remove(msg.id);
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('小酥'),
            const SizedBox(width: 8),
            if (_isLoading)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final agentMsgs = _agentMessageMap[msg.id];
                      final isStreaming = _streamingMessages.contains(msg.id);

                      return MessageBubble(
                        message: msg,
                        agentMessages: agentMsgs,
                        isStreaming: isStreaming,
                      );
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
              _suggestionChip('⌨️ 执行命令'),
              _suggestionChip('📅 创建日程'),
            ],
          ),
          const SizedBox(height: 16),
          // Agent模式标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, size: 14, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  'Agent模式已启用',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ),
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
                setState(() {
                  _messages.clear();
                  _agentMessageMap.clear();
                  _streamingMessages.clear();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制全部'),
              onTap: () {
                Navigator.pop(context);
                final allText = _messages
                    .map((m) => '${m.role == MessageRole.user ? "我" : "小酥"}: ${m.content}')
                    .join('\n\n');
                Clipboard.setData(ClipboardData(text: allText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制全部对话内容')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('settings-full');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 小酥 - 聊天界面（引用回复 + 连续发送 + 文件管理入口）
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
import '../files/file_manager_screen.dart';

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
  String? _currentAssistantMsgId;

  // 引用回复
  String? _replyToContent;
  String? _replyToAuthor;

  @override
  void initState() {
    super.initState();
    final convId = widget.conversationId.isEmpty 
        ? 'conv_${DateTime.now().millisecondsSinceEpoch}'
        : widget.conversationId;
    _engine.setActiveConversation(convId);
    _messages.addAll(_engine.getHistory(convId));
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

  /// 设置引用回复
  void _setReply(String content, String author) {
    setState(() {
      _replyToContent = content.length > 50 ? '${content.substring(0, 50)}...' : content;
      _replyToAuthor = author;
    });
  }

  /// 取消引用
  void _cancelReply() {
    setState(() {
      _replyToContent = null;
      _replyToAuthor = null;
    });
  }

  /// 发送消息 - 不阻塞连续发送
  Future<void> _sendMessage(String text, {List<String>? filePaths}) async {
    if (text.trim().isEmpty && (filePaths == null || filePaths.isEmpty)) return;
    
    // 不阻止连续发送，仅标记状态
    setState(() => _isLoading = true);

    final convId = widget.conversationId.isEmpty 
        ? 'conv_${DateTime.now().millisecondsSinceEpoch}'
        : widget.conversationId;

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      attachments: filePaths != null && filePaths.isNotEmpty
          ? filePaths.map((p) => MessageAttachment(
              id: 'att_${DateTime.now().millisecondsSinceEpoch}',
              type: p.endsWith('.mp4') ? 'video' : (p.endsWith('.jpg') || p.endsWith('.png') ? 'image' : 'file'),
              url: p,
            )).toList()
          : null,
      metadata: _replyToContent != null ? {'reply_to': _replyToContent, 'reply_to_author': _replyToAuthor} : null,
    );
    
    setState(() { _messages.add(userMsg); });
    _scrollToBottom();

    // 清除引用状态
    _cancelReply();

    try {
      _currentAssistantMsgId = null;
      final streamingMsgIds = <String>{};

      await for (final msg in _engine.sendMessageStream(
        conversationId: convId,
        content: text,
        filePaths: filePaths,
        replyTo: _replyToContent,
      )) {
        if (msg.role == MessageRole.user) continue;

        setState(() {
          final agentMsgs = _engine.getAgentMessages(msg.id);
          if (agentMsgs.isNotEmpty) { _agentMessageMap[msg.id] = agentMsgs; }

          final existingIdx = _messages.indexWhere((m) => m.id == msg.id);
          if (existingIdx >= 0) {
            _messages[existingIdx] = msg;
          } else {
            _messages.add(msg);
            streamingMsgIds.add(msg.id);
            _currentAssistantMsgId = msg.id;
          }

          if (msg.status == MessageStatus.streaming) {
            _streamingMessages.add(msg.id);
          } else {
            _streamingMessages.remove(msg.id);
            streamingMsgIds.remove(msg.id);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: convId,
          content: '⚠️ 发送失败: $e',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
        _currentAssistantMsgId = null;
      });
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
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '文件管理',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileManagerScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 引用预览条
          if (_replyToContent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Row(
                children: [
                  Icon(Icons.format_quote, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '回复 $_replyToAuthor：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                          ),
                          TextSpan(
                            text: _replyToContent,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
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
                        onReply: (content, author) => _setReply(content, author),
                      );
                    },
                  ),
          ),
          // 输入框
          ChatInput(
            onSend: _sendMessage,
            isLoading: _isLoading,
          ),
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
          Text('有什么可以帮你的吗？', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8, runSpacing: 8,
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
                Text('Agent模式已启用', style: TextStyle(fontSize: 12, color: Colors.green[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(label: Text(label), onPressed: () => _sendMessage(label.substring(2).trim()));
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('文件管理'),
              subtitle: const Text('浏览和下载服务器文件'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FileManagerScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空对话'),
              onTap: () {
                Navigator.pop(context);
                final convId = widget.conversationId.isEmpty ? 'conv_${DateTime.now().millisecondsSinceEpoch}' : widget.conversationId;
                _engine.clearHistory(convId);
                setState(() { _messages.clear(); _agentMessageMap.clear(); _streamingMessages.clear(); });
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制全部'),
              onTap: () {
                Navigator.pop(context);
                final allText = _messages.map((m) => '${m.role == MessageRole.user ? "我" : "小酥"}: ${m.content}').join('\n\n');
                Clipboard.setData(ClipboardData(text: allText));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制全部对话内容')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

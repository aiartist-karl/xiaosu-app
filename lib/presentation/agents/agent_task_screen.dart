// ============================================================================
// 小酥 - Agent任务执行页（对接ChatEngine真实执行）
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/chat_engine.dart';
import '../../models/chat_message.dart';
import '../chat/widgets/message_bubble.dart';
import '../chat/widgets/thinking_indicator.dart';

class AgentTaskScreen extends StatefulWidget {
  final String taskDescription;
  final String? taskId;

  const AgentTaskScreen({super.key, required this.taskDescription, this.taskId});

  @override
  State<AgentTaskScreen> createState() => _AgentTaskScreenState();
}

class _AgentTaskScreenState extends State<AgentTaskScreen> {
  final ChatEngine _engine = ChatEngine.instance;
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isExecuting = false;
  String _conversationId = '';

  @override
  void initState() {
    super.initState();
    _conversationId = widget.taskId ?? 'task_${DateTime.now().millisecondsSinceEpoch}';
    _engine.setActiveConversation(_conversationId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startExecution());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 开始执行任务
  Future<void> _startExecution() async {
    setState(() { _isExecuting = true; });

    try {
      await for (final message in _engine.sendMessageStream(
        conversationId: _conversationId,
        content: widget.taskDescription,
      )) {
        if (!mounted) return;

        setState(() {
          // 更新或添加消息
          final idx = _messages.indexWhere((m) => m.id == message.id);
          if (idx >= 0) {
            _messages[idx] = message;
          } else {
            _messages.add(message);
          }
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: _conversationId,
            content: '⚠️ 执行错误: ${e.toString()}',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            status: MessageStatus.error,
          ));
        });
      }
    } finally {
      if (mounted) setState(() { _isExecuting = false; });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent执行'),
        actions: [
          if (_isExecuting)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () { setState(() { _isExecuting = false; }); },
              tooltip: '停止执行',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { _messages.clear(); });
              _startExecution();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 任务描述卡片
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A5F) : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.blue[900]! : Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.task, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text('任务', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                Text(widget.taskDescription, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
          ),

          // 消息列表
          Expanded(
            child: _messages.isEmpty && _isExecuting
                ? const Center(child: ThinkingIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _messages.length + (_isExecuting ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: ThinkingIndicator(),
                        );
                      }
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // 状态栏
          if (_isExecuting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
              child: Row(children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('执行中...', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
            ),
        ],
      ),
    );
  }
}

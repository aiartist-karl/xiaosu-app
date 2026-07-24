// ============================================================================
// 小酥 - 会话列表界面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/chat_engine.dart';
import '../../../models/conversation.dart';

/// 会话列表界面
class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final ChatEngine _engine = ChatEngine.instance;
  final List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final ids = _engine.conversationIds;
    setState(() {
      _conversations.clear();
      for (final id in ids) {
        final history = _engine.getHistory(id);
        _conversations.add(Conversation(
          id: id,
          title: history.isNotEmpty ? _extractTitle(history.first.content) : '新对话',
          createdAt: history.isNotEmpty ? history.first.timestamp : DateTime.now(),
          updatedAt: history.isNotEmpty ? history.last.timestamp : DateTime.now(),
          messageCount: history.length,
        ));
      }
    });
  }

  String _extractTitle(String content) {
    if (content.length > 30) return '${content.substring(0, 30)}...';
    return content;
  }

  Future<void> _createNewConversation() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _engine.setActiveConversation(id);
    if (mounted) {
      context.goNamed('chat', pathParameters: {'conversationId': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话列表'),
        centerTitle: true,
      ),
      body: _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('还没有对话记录', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('开始一段新对话吧！', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.chat_bubble_outline, size: 20),
                    ),
                    title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${conv.messageCount} 条消息'),
                    trailing: Text(
                      _formatDate(conv.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => context.goNamed('chat', pathParameters: {'conversationId': conv.id}),
                    onLongPress: () => _confirmDelete(conv),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  void _confirmDelete(Conversation conv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除"${conv.title}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _engine.deleteConversation(conv.id);
              _loadConversations();
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

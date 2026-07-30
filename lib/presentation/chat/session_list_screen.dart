// ============================================================================
// 小酥 - 会话列表界面
// Phase 3: 对接 Coze Studio 会话列表
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/chat_engine.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/models/conversation_model.dart';

/// 会话列表界面 - 展示 Coze Studio 远程会话 + 本地会话
class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final ChatEngine _engine = ChatEngine.instance;
  final ConversationRepository _repo = ConversationRepository.instance;

  List<ConversationModel> _conversations = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  /// 加载会话列表（优先 Coze Studio，回退本地）
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 先尝试从 Coze Studio 拉取
      final cozeList = await _repo.fetchFromCoze();

      // 同时获取本地会话
      final localIds = _engine.conversationIds;

      if (cozeList.isNotEmpty) {
        setState(() {
          _conversations = cozeList;
          _isLoading = false;
        });
      } else {
        // 回退到本地
        setState(() {
          _conversations = [];
          for (final id in localIds) {
            final history = _engine.getHistory(id);
            _conversations.add(ConversationModel(
              id: id,
              title: history.isNotEmpty
                  ? _extractTitle(history.first.content)
                  : '新对话',
              messageCount: history.length,
              lastMessage: history.isNotEmpty ? history.last.content : '',
              createdAt: history.isNotEmpty ? history.first.timestamp : DateTime.now(),
              updatedAt: history.isNotEmpty ? history.last.timestamp : DateTime.now(),
            ));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // Coze Studio 失败，使用本地
      final localIds = _engine.conversationIds;
      setState(() {
        _conversations = [];
        for (final id in localIds) {
          final history = _engine.getHistory(id);
          _conversations.add(ConversationModel(
            id: id,
            title: history.isNotEmpty
                ? _extractTitle(history.first.content)
                : '新对话',
            messageCount: history.length,
            createdAt: history.isNotEmpty ? history.first.timestamp : DateTime.now(),
            updatedAt: history.isNotEmpty ? history.last.timestamp : DateTime.now(),
          ));
        }
        _isLoading = false;
        _error = null; // 本地回退成功，不显示错误
      });
    }
  }

  String _extractTitle(String content) {
    if (content.length > 30) return '${content.substring(0, 30)}...';
    return content;
  }

  /// 创建新对话（通过 Coze Studio）
  Future<void> _createNewConversation() async {
    // 创建远程会话
    final conv = await _repo.createOnCoze();
    if (conv != null) {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      _engine.setActiveConversation(
        localId,
        cozeConversationId: conv.cozeConversationId,
      );
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': localId,
            'cozeConversationId': conv.cozeConversationId,
          },
        );
      }
    } else {
      // 回退：纯本地创建
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _engine.setActiveConversation(id);
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {'conversationId': id},
        );
      }
    }
  }

  /// 打开已有对话
  void _openConversation(ConversationModel conv) {
    final localId = conv.id;
    _engine.setActiveConversation(
      localId,
      cozeConversationId: conv.cozeConversationId,
    );

    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': localId,
        'cozeConversationId': conv.cozeConversationId,
        'botName': conv.title,
      },
    );
  }

  /// 下拉刷新
  Future<void> _onRefresh() async {
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话列表'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      return _buildConversationCard(conv);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
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
    );
  }

  Widget _buildConversationCard(ConversationModel conv) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: conv.cozeConversationId != null
              ? const Icon(Icons.cloud, size: 20)
              : const Icon(Icons.chat_bubble_outline, size: 20),
        ),
        title: Text(
          conv.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${conv.messageCount} 条消息'
          '${conv.lastMessage.isNotEmpty ? " · ${conv.lastMessage.length > 20 ? '${conv.lastMessage.substring(0, 20)}...' : conv.lastMessage}' : ''}',
        ),
        trailing: Text(
          _formatDate(conv.updatedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () => _openConversation(conv),
        onLongPress: () => _confirmDelete(conv),
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

  void _confirmDelete(ConversationModel conv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除"${conv.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
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

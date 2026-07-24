// ============================================================================
// 小酥 (XiaoSu) - 首页（对话列表完整版）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/chat_engine.dart';
import '../../data/models/conversation_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页 —— 显示所有对话列表
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ChatEngine _engine = ChatEngine.instance;
  static const String _storageKey = 'xiaosu_conversations';
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _conversations = list
            .map((e) => ConversationModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .where((c) => c.status != 'deleted')
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_conversations.map((c) => c.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> _createNewConversation() async {
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final conv = ConversationModel(
      id: id,
      title: '新对话',
      createdAt: now,
      updatedAt: now,
      status: 'active',
      messageCount: 0,
    );
    setState(() {
      _conversations.insert(0, conv);
    });
    await _saveConversations();
    _engine.setActiveConversation(id);
    if (!mounted) return;
    context.push('/chat/$id');
  }

  Future<void> _deleteConversation(int index) async {
    final conv = _conversations[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除"${conv.title}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _conversations[index] = conv.copyWith(status: 'deleted');
      });
      await _saveConversations();
      setState(() {
        _conversations.removeAt(index);
      });
      _engine.deleteConversation(conv.id);
    }
  }

  Future<void> _renameConversation(int index) async {
    final conv = _conversations[index];
    final ctrl = TextEditingController(text: conv.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '对话名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _conversations[index] = conv.copyWith(title: newName, updatedAt: DateTime.now());
      });
      await _saveConversations();
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return '昨天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            icon: const Icon(Icons.build),
            onPressed: () => context.go('/skills'),
            tooltip: '技能管理',
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () => context.go('/tasks'),
            tooltip: '任务管理',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('开始新对话', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('点击右下角按钮创建你的第一次对话', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _createNewConversation,
                        icon: const Icon(Icons.add),
                        label: const Text('新建对话'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      return Dismissible(
                        key: Key(conv.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteConversation(index);
                          return false; // 我们在 _deleteConversation 里自己处理
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.chat_bubble,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            conv.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            conv.lastMessage.isNotEmpty
                                ? conv.lastMessage
                                : '${conv.messageCount}条消息',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          trailing: Text(
                            _formatTime(conv.updatedAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          onTap: () {
                            _engine.setActiveConversation(conv.id);
                            context.push('/chat/${conv.id}');
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('重命名'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _renameConversation(index);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('删除', style: TextStyle(color: Colors.red)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _deleteConversation(index);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        tooltip: '新建对话',
        child: const Icon(Icons.add),
      ),
    );
  }
}

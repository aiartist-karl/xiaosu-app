// ============================================================================
// 小酥 v2 - 首页（对话列表 + Token余额卡片）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/chat_engine.dart';
import '../../../models/conversation.dart';
import '../../../presentation/theme/app_colors.dart';

/// 首页 - 对话列表
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ChatEngine _engine = ChatEngine.instance;
  final List<Conversation> _conversations = [];
  int _selectedFilter = 0; // 0=最近 1=收藏 2=今天 3=更早
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  // 模拟 Token 余额（后续对接后端）
  final int _tokenBalance = 1500;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      // 按更新时间倒序
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  String _extractTitle(String content) {
    if (content.length > 30) return '${content.substring(0, 30)}...';
    return content;
  }

  List<Conversation> get _filteredConversations {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 2: // 今天
        return _conversations.where((c) =>
          c.updatedAt.year == now.year &&
          c.updatedAt.month == now.month &&
          c.updatedAt.day == now.day).toList();
      case 3: // 更早
        return _conversations.where((c) =>
          !(c.updatedAt.year == now.year &&
            c.updatedAt.month == now.month &&
            c.updatedAt.day == now.day)).toList();
      default: // 最近 / 收藏
        return _conversations;
    }
  }

  List<Conversation> get _displayConversations {
    var list = _filteredConversations;
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) =>
        c.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return list;
  }

  void _createNewConversation() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _engine.setActiveConversation(id);
    context.pushNamed('chat', pathParameters: {'conversationId': id});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── 顶部栏 ───
            _buildTopBar(isDark),
            // ─── Token余额卡片 ───
            _buildTokenCard(isDark),
            // ─── 筛选Tab ───
            _buildFilterTabs(isDark),
            // ─── 对话列表 ───
            Expanded(child: _buildConversationList(isDark)),
            // ─── 底部输入栏 ───
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─── 顶部栏 ───
  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // 头像
          GestureDetector(
            onTap: () => _showProfileSheet(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary(isDark).withOpacity(0.15),
              child: const Icon(Icons.person, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // 标题或搜索框
          Expanded(
            child: _isSearching ? _buildSearchField(isDark) : const SizedBox.shrink(),
          ),
          if (!_isSearching) ...[
            const Spacer(),
            // 搜索按钮
            IconButton(
              icon: Icon(Icons.search, color: AppColors.textSecondary(isDark)),
              onPressed: () => setState(() => _isSearching = true),
            ),
            // 新建对话
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.primary(isDark)),
              onPressed: _createNewConversation,
            ),
          ],
          if (_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: '搜索对话...',
        hintStyle: TextStyle(color: AppColors.textHint(isDark), fontSize: 15),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      style: TextStyle(fontSize: 15, color: AppColors.textPrimary(isDark)),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  // ─── Token余额卡片 ───
  Widget _buildTokenCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          // TODO: 跳转充值页
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary(isDark),
                AppColors.primary(isDark).withOpacity(0.7),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '剩余 $_tokenBalance Token',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '充值',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 筛选Tab ───
  Widget _buildFilterTabs(bool isDark) {
    final filters = ['最近', '收藏', '今天', '更早'];
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _selectedFilter == i;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary(isDark).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    filters[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.primary(isDark) : AppColors.textSecondary(isDark),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── 对话列表 ───
  Widget _buildConversationList(bool isDark) {
    final list = _displayConversations;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? '没有找到匹配的对话' : '还没有对话记录',
              style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 15),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '点击 + 开始一段新对话',
                style: TextStyle(color: AppColors.textHint(isDark), fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final conv = list[index];
        return _buildConversationItem(conv, isDark);
      },
    );
  }

  Widget _buildConversationItem(Conversation conv, bool isDark) {
    return GestureDetector(
      onTap: () => context.pushNamed('chat', pathParameters: {'conversationId': conv.id}),
      onLongPress: () => _showConversationActions(conv),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Bot 头像
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary(isDark).withOpacity(0.12),
              child: Icon(Icons.smart_toy_outlined, size: 22, color: AppColors.primary(isDark)),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(conv.updatedAt),
                        style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${conv.messageCount} 条消息',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 底部输入栏 ───
  Widget _buildInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(top: BorderSide(color: AppColors.divider(isDark), width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 12, top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // + 按钮
          IconButton(
            icon: Icon(Icons.add_circle_outline, size: 24, color: AppColors.textSecondary(isDark)),
            onPressed: _createNewConversation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          // 输入框
          Expanded(
            child: GestureDetector(
              onTap: _createNewConversation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '给小酥发消息...',
                  style: TextStyle(color: AppColors.textHint(isDark), fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 长按对话操作 ───
  void _showConversationActions(Conversation conv) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('置顶'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('收藏'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                _engine.deleteConversation(conv.id);
                _loadConversations();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 点击头像弹出侧边栏 ───
  void _showProfileSheet() {
    context.pushNamed('profile');
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}

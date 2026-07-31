// ============================================================================
// 小酥 v3 - 首页（对标扣子 APP 视觉风格）
// 蓝紫渐变 Token 卡片 + 卡片化对话列表 + 筛选 Tab
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/chat_engine.dart';
import '../../models/conversation.dart';
import '../../presentation/theme/app_colors.dart';

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

  // Token 余额
  int? _tokenBalance;
  bool _tokenLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadTokenBalance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载对话列表
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
          lastMessage: history.isNotEmpty ? history.last.content : null,
        ));
      }
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> _loadTokenBalance() async {
    setState(() => _tokenLoading = true);
    if (mounted) {
      setState(() {
        _tokenBalance = null;
        _tokenLoading = false;
      });
    }
  }

  String _extractTitle(String content) {
    if (content.length > 30) return '${content.substring(0, 30)}...';
    return content;
  }

  List<Conversation> get _filteredConversations {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 2:
        return _conversations.where((c) =>
          c.updatedAt.year == now.year &&
          c.updatedAt.month == now.month &&
          c.updatedAt.day == now.day).toList();
      case 3:
        return _conversations.where((c) =>
          !(c.updatedAt.year == now.year &&
            c.updatedAt.month == now.month &&
            c.updatedAt.day == now.day)).toList();
      default:
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
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            _buildTokenCard(isDark),
            _buildFilterTabs(isDark),
            Expanded(child: _buildConversationList(isDark)),
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─── 顶部栏：头像 + 用户名 + 搜索 + 新建 ───
  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          // 用户头像
          GestureDetector(
            onTap: () => context.pushNamed('profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary(isDark).withOpacity(0.12),
              child: Icon(Icons.person, size: 20, color: AppColors.primary(isDark)),
            ),
          ),
          const SizedBox(width: 10),
          // 用户名
          Expanded(
            child: Text(
              '小酥',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          // 搜索图标
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search_rounded, size: 24, color: AppColors.textSecondary(isDark)),
              onPressed: () => setState(() => _isSearching = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          // 新建图标
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, size: 24, color: AppColors.primary(isDark)),
            onPressed: _createNewConversation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // 搜索模式下的输入框和关闭按钮
          if (_isSearching) ...[
            Expanded(
              flex: 3,
              child: TextField(
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
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary(isDark)),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Token 余额卡片（蓝紫渐变） ───
  Widget _buildTokenCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GestureDetector(
        onTap: () => context.pushNamed('token-recharge'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.tokenCardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：标签 + 余额
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Token 余额',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (_tokenLoading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    )
                  else
                    Text(
                      _tokenBalance != null ? '$_tokenBalance' : '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _tokenBalance != null ? (_tokenBalance! / 10000).clamp(0.0, 1.0) : null,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              // 底部按钮
              Row(
                children: [
                  _buildTokenActionBtn('充值', Icons.add_rounded),
                  const SizedBox(width: 10),
                  _buildTokenActionBtn('消费记录', Icons.receipt_long_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenActionBtn(String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── 筛选 Tab ───
  Widget _buildFilterTabs(bool isDark) {
    final filters = ['最近', '收藏', '今天', '更早'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _selectedFilter == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary(isDark).withOpacity(0.10)
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
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textHint(isDark)),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildConversationItem(list[index], isDark);
      },
    );
  }

  Widget _buildConversationItem(Conversation conv, bool isDark) {
    return GestureDetector(
      onTap: () => context.pushNamed('chat', pathParameters: {'conversationId': conv.id}),
      onLongPress: () => _showConversationActions(conv),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [AppColors.shadow(isDark)],
        ),
        child: Row(
          children: [
            // Bot 头像（圆形）
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary(isDark).withOpacity(0.10),
              child: Icon(Icons.smart_toy_outlined, size: 22, color: AppColors.primary(isDark)),
            ),
            const SizedBox(width: 12),
            // 中间：名称 + 预览
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conv.lastMessage ?? '${conv.messageCount} 条消息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 右侧：时间
            Text(
              _formatDate(conv.updatedAt),
              style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 底部输入栏（预留） ───
  Widget _buildInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        border: Border(top: BorderSide(color: AppColors.divider(isDark), width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 12, top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, size: 24, color: AppColors.textSecondary(isDark)),
            onPressed: _createNewConversation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _createNewConversation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF5F5F7),
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

  // ─── 长按操作菜单 ───
  void _showConversationActions(Conversation conv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.push_pin_outlined, color: AppColors.primary(false)),
                title: const Text('置顶'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.star_outline_rounded, color: AppColors.warning(false)),
                title: const Text('收藏'),
                onTap: () => Navigator.pop(ctx),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
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
      ),
    );
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
    return '${dt.month}/${dt.day}';
  }
}

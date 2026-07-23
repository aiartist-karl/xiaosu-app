import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import 'chat_controller.dart';

/// 会话列表界面
/// 展示所有历史会话，支持搜索、分组、滑动删除/置顶
class SessionListScreen extends ConsumerStatefulWidget {
  const SessionListScreen({super.key});

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 搜索文本
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatControllerProvider);

    // 模拟会话列表数据
    final sessions = _generateMockSessions();

    // 按搜索过滤
    final filteredSessions = _searchQuery.isEmpty
        ? sessions
        : sessions.where((s) {
            return s.title.contains(_searchQuery) ||
                s.preview.contains(_searchQuery);
          }).toList();

    // 按时间分组
    final grouped = _groupSessions(filteredSessions);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('对话列表'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary(isDark),
            ),
            onPressed: () {
              _showSearchBar();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          AnimatedContainer2(
            visible: _searchQuery.isNotEmpty || _isSearching,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: '搜索对话...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textHint(isDark),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // 会话列表
          Expanded(
            child: filteredSessions.isEmpty
                ? EmptyStateView2(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '暂无对话',
                    subtitle: '开始你的第一次对话吧',
                    actionLabel: '新建对话',
                    onAction: () {
                      ref.read(chatControllerProvider.notifier).newSession();
                      Navigator.pop(context);
                    },
                    isDark: isDark,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final group = grouped[index];

                      if (group.isHeader) {
                        return SectionHeader2(
                          title: group.title!,
                          isDark: isDark,
                        );
                      }

                      return _buildSessionTile(
                        context,
                        group.session!,
                        isDark,
                      );
                    },
                  ),
          ),
        ],
      ),

      // 新建对话浮动按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(chatControllerProvider.notifier).newSession();
          Navigator.pop(context);
        },
        backgroundColor: AppColors.primary(isDark),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          '新对话',
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  bool _isSearching = false;

  void _showSearchBar() {
    setState(() => _isSearching = !_isSearching);
  }

  /// 构建会话列表项
  Widget _buildSessionTile(
    BuildContext context,
    ChatSession session,
    bool isDark,
  ) {
    return Dismissible(
      key: Key(session.id),
      background: Container(
        color: AppColors.primary(isDark).withOpacity(0.15),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(Icons.push_pin_rounded, color: AppColors.primary(isDark)),
            const Spacer(),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.error(isDark).withOpacity(0.15),
        child: Row(
          children: [
            const Spacer(),
            Icon(Icons.delete_outline_rounded, color: AppColors.error(isDark)),
            const SizedBox(width: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // 删除确认
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除对话'),
              content: Text('确定要删除「${session.title}」吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('删除',
                      style: TextStyle(color: AppColors.error(isDark))),
                ),
              ],
            ),
          );
        }
        // 置顶
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          // 删除逻辑
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(chatControllerProvider.notifier).switchSession(session);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // 会话图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    session.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary(isDark),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // 会话信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.textPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(session.updatedAt),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textHint(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.preview,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 消息数量
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(isDark: isDark),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    '${session.messages.length}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 模拟会话列表数据
  List<ChatSession> _generateMockSessions() {
    final now = DateTime.now();
    return [
      ChatSession(
        id: '1',
        title: 'Flutter 开发问题咨询',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        messages: List.generate(5, (i) => ChatMessage(
          id: 'm_$i',
          role: i.isEven ? MessageRole.user : MessageRole.assistant,
          content: i == 0 ? '你好，我有一个关于 Riverpod 的问题' : '这是一条模拟消息',
          timestamp: now.subtract(Duration(hours: i)),
        )),
      ),
      ChatSession(
        id: '2',
        title: '帮我写一篇周报告',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        messages: List.generate(3, (i) => ChatMessage(
          id: 'm2_$i',
          role: i.isEven ? MessageRole.user : MessageRole.assistant,
          content: '帮我整理一下本周的工作内容',
          timestamp: now.subtract(Duration(days: 1, hours: i)),
        )),
      ),
      ChatSession(
        id: '3',
        title: 'Python 数据分析',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
        messages: List.generate(8, (i) => ChatMessage(
          id: 'm3_$i',
          role: i.isEven ? MessageRole.user : MessageRole.assistant,
          content: '如何用 pandas 处理 CSV 文件',
          timestamp: now.subtract(Duration(days: 3, hours: i)),
        )),
      ),
      ChatSession(
        id: '4',
        title: '旅行计划讨论',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 8)),
        messages: List.generate(4, (i) => ChatMessage(
          id: 'm4_$i',
          role: i.isEven ? MessageRole.user : MessageRole.assistant,
          content: '五一想去云南旅游，帮我规划一下',
          timestamp: now.subtract(Duration(days: 10, hours: i)),
        )),
      ),
      ChatSession(
        id: '5',
        title: 'API 接口设计',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 18)),
        messages: List.generate(6, (i) => ChatMessage(
          id: 'm5_$i',
          role: i.isEven ? MessageRole.user : MessageRole.assistant,
          content: 'RESTful API 最佳实践',
          timestamp: now.subtract(Duration(days: 20, hours: i)),
        )),
      ),
    ];
  }

  /// 按时间分组
  List<_ListGroup> _groupSessions(List<ChatSession> sessions) {
    final List<_ListGroup> result = [];
    final now = DateTime.now();

    String? lastGroup;

    for (final session in sessions) {
      final diff = now.difference(session.updatedAt);
      String groupTitle;

      if (diff.inDays == 0) {
        groupTitle = '今天';
      } else if (diff.inDays == 1) {
        groupTitle = '昨天';
      } else if (diff.inDays < 7) {
        groupTitle = '本周';
      } else {
        groupTitle = '更早';
      }

      if (groupTitle != lastGroup) {
        result.add(_ListGroup(isHeader: true, title: groupTitle));
        lastGroup = groupTitle;
      }

      result.add(_ListGroup(session: session));
    }

    return result;
  }

  /// 格式化相对时间
  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

/// 列表分组项
class _ListGroup {
  final bool isHeader;
  final String? title;
  final ChatSession? session;

  _ListGroup({this.isHeader = false, this.title, this.session});
}

/// 简化的动画容器
class AnimatedContainer2 extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedContainer2({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}

/// 简化的空状态
class EmptyStateView2 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const EmptyStateView2({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint(isDark)),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary(isDark),
          )),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary(isDark),
            )),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 简化的分节标题
class SectionHeader2 extends StatelessWidget {
  final String title;
  final bool isDark;

  const SectionHeader2({super.key, required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}

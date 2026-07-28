// ============================================================================
// 小酥 v2 - 记忆管理页
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 记忆管理页面
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 模拟记忆数据
  final List<_MemoryItem> _conversationMemories = [
    _MemoryItem(
      summary: '用户偏好用 Flutter 开发移动端应用，熟悉 Riverpod 状态管理',
      source: '技术讨论对话',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _MemoryItem(
      summary: '用户倾向于使用 Material Design 3 风格进行 UI 设计',
      source: 'UI 设计讨论对话',
      time: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _MemoryItem(
      summary: '用户在代码审查中偏好简洁的命名风格和模块化架构',
      source: '代码评审对话',
      time: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _MemoryItem(
      summary: '用户使用 VS Code 作为主要开发环境，配合 Git 版本控制',
      source: '工具链讨论对话',
      time: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  final List<_MemoryItem> _knowledgeMemories = [
    _MemoryItem(
      summary: 'Flutter 3.x 推荐使用 go_router 进行声明式路由管理',
      source: '项目文档',
      time: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _MemoryItem(
      summary: 'AppColors 使用 isDark 参数切换深色/浅色主题色',
      source: '设计规范文档',
      time: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _MemoryItem(
      summary: 'Riverpod 的 StateNotifier 适合管理有复杂状态变化的场景',
      source: '技术博客收藏',
      time: DateTime.now().subtract(const Duration(days: 3)),
    ),
    _MemoryItem(
      summary: 'Dart 3.0 引入了 sealed class、pattern matching 等新特性',
      source: 'Dart 官方文档',
      time: DateTime.now().subtract(const Duration(days: 5)),
    ),
    _MemoryItem(
      summary: '项目使用 go_router 的 StatefulShellRoute 实现底部 Tab 导航',
      source: '代码注释',
      time: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  final List<_MemoryItem> _preferenceMemories = [
    _MemoryItem(
      summary: '偏好深色模式，代码使用深色背景',
      source: '系统设置',
      time: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _MemoryItem(
      summary: '沟通风格偏好：简洁直接，重点突出',
      source: '对话分析',
      time: DateTime.now().subtract(const Duration(days: 5)),
    ),
    _MemoryItem(
      summary: '语言偏好：中文为主，技术术语使用英文',
      source: '对话分析',
      time: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  List<_MemoryItem> get _currentMemories {
    final int idx = _tabController.index;
    List<_MemoryItem> all;
    switch (idx) {
      case 0:
        all = _conversationMemories;
        break;
      case 1:
        all = _knowledgeMemories;
        break;
      case 2:
        all = _preferenceMemories;
        break;
      default:
        all = [];
    }
    if (_searchQuery.isEmpty) return all;
    return all.where((m) {
      return m.summary.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.source.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆管理'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary(isDark),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary(isDark),
          unselectedLabelColor: AppColors.textSecondary(isDark),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '对话记忆'),
            Tab(text: '知识记忆'),
            Tab(text: '偏好记忆'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '搜索记忆...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surfaceVariant(isDark: isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // 统计
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.memory, size: 16, color: AppColors.secondary(isDark)),
                const SizedBox(width: 6),
                Text(
                  '${_currentMemories.length} 条记忆',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          // 记忆列表
          Expanded(
            child: _currentMemories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.memory,
                          size: 48,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无相关记忆',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentMemories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final memory = _currentMemories[index];
                      return _MemoryCard(
                        memory: memory,
                        isDark: isDark,
                        onDelete: () {
                          setState(() {
                            final idx = _tabController.index;
                            switch (idx) {
                              case 0:
                                _conversationMemories.removeAt(index);
                                break;
                              case 1:
                                _knowledgeMemories.removeAt(index);
                                break;
                              case 2:
                                _preferenceMemories.removeAt(index);
                                break;
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 记忆卡片 ──────────────────────────────────────────────────
class _MemoryCard extends StatelessWidget {
  final _MemoryItem memory;
  final bool isDark;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 记忆图标
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary(isDark).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: AppColors.secondary(isDark),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.summary,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary(isDark),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.source,
                          size: 13,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          memory.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          memory.timeString,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error(isDark).withOpacity(0.6),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 记忆数据模型 ──────────────────────────────────────────────
class _MemoryItem {
  final String summary;
  final String source;
  final DateTime time;

  _MemoryItem({
    required this.summary,
    required this.source,
    required this.time,
  });

  String get timeString {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

// ============================================================================
// 小酥 v2 - Bot 商店
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bot 模型
class BotItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final bool isOwned;
  final bool isPreset;

  const BotItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.isOwned = false,
    this.isPreset = false,
  });
}

/// Bot 商店页面
class BotStoreScreen extends StatefulWidget {
  const BotStoreScreen({super.key});

  @override
  State<BotStoreScreen> createState() => _BotStoreScreenState();
}

class _BotStoreScreenState extends State<BotStoreScreen> {
  int _selectedTab = 0; // 0=精选 1=我的 2=最近使用
  int _selectedCategory = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = ['全部', '自媒体', '金融', '法律', '互联网', '科研'];

  // 模拟数据（后续对接后端 API）
  final List<BotItem> _bots = [
    BotItem(id: '1', name: '智能写作助手', description: '帮你写文案、文章、营销内容', category: '自媒体', isPreset: true),
    BotItem(id: '2', name: '投资分析员', description: '个股分析、行情解读、投资建议', category: '金融', isPreset: true),
    BotItem(id: '3', name: '法律顾问', description: '法律咨询、合同审核、诉讼文书', category: '法律', isPreset: true),
    BotItem(id: '4', name: '行业研究员', description: '行业调研、竞品分析、市场洞察', category: '互联网', isPreset: true),
    BotItem(id: '5', name: '论文助手', description: '论文搜索、文献综述、学术写作', category: '科研', isPreset: true),
    BotItem(id: '6', name: '代码专家', description: '代码生成、Bug修复、架构设计', category: '互联网', isPreset: true),
    BotItem(id: '7', name: '翻译官', description: '多语言翻译、本地化、术语管理', category: '全部', isPreset: true),
    BotItem(id: '8', name: '日报生成器', description: '自动生成工作日报、周报', category: '自媒体', isOwned: true),
  ];

  List<BotItem> get _filteredBots {
    var list = _bots;
    // Tab 过滤
    if (_selectedTab == 1) {
      list = list.where((b) => b.isOwned).toList();
    } else if (_selectedTab == 2) {
      list = list.where((b) => b.isPreset).take(4).toList(); // 模拟最近使用
    }
    // 分类过滤
    if (_selectedCategory > 0) {
      final cat = _categories[_selectedCategory];
      list = list.where((b) => b.category == cat).toList();
    }
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      list = list.where((b) =>
        b.name.contains(_searchQuery) || b.description.contains(_searchQuery)).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            // ─── Tab 切换 ───
            _buildTabBar(isDark),
            // ─── 搜索框 ───
            _buildSearchBar(isDark),
            // ─── 分类横滑 ───
            _buildCategoryBar(isDark),
            // ─── Bot 列表 ───
            Expanded(child: _buildBotGrid(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 创建新 Bot
        },
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            'Bot 商店',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const Spacer(),
          Icon(Icons.tune, size: 22, color: AppColors.textSecondary(isDark)),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = ['精选', '我的', '最近使用'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary(isDark)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: selected
                      ? null
                      : Border.all(color: AppColors.divider(isDark), width: 0.5),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary(isDark),
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

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: AppColors.textHint(isDark)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '搜索 Bot...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(isDark)),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _selectedCategory == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary(isDark).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _categories[i],
                style: TextStyle(
                  color: selected ? AppColors.primary(isDark) : AppColors.textSecondary(isDark),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBotGrid(bool isDark) {
    final list = _filteredBots;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              '暂无 Bot',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) => _buildBotCard(list[index], isDark),
    );
  }

  Widget _buildBotCard(BotItem bot, bool isDark) {
    return GestureDetector(
      onTap: () {
        // TODO: 跳转 Bot 详情页
      },
      onLongPress: () {
        if (bot.isOwned) {
          _showBotActions(bot);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: AppColors.primary(isDark),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            // 名称
            Text(
              bot.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 描述
            Text(
              bot.description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 底部：标签 + 按钮
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bot.category,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // TODO: 开始对话
                  },
                  child: Text(
                    bot.isOwned ? '编辑' : '使用',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBotActions(BotItem bot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 小酥 v2 - Bot 商店
// Phase 2: 对接 Coze Studio Bot API，保留原有 UI 设计风格
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/bot_model.dart';
import '../../core/bot/bot_manager.dart';
import '../theme/app_colors.dart';
import 'bot_detail_screen.dart';
import 'bot_editor_screen.dart';

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
  bool _showSearch = false;

  final List<String> _categories = [
    '全部', '自媒体', '金融', '法律', '互联网', '科研', '教育',
  ];

  /// 头像背景色池 —— 让每个 Bot 的圆形头像有不同底色
  static const List<Color> _avatarColors = [
    Color(0xFF6C63FF), Color(0xFFE8895C), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  final BotManager _botManager = BotManager.instance;

  List<BotModel> _bots = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBots();
    _botManager.onBotListUpdated.listen((bots) {
      if (mounted) {
        setState(() {
          _bots = bots;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadBots({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final bots = await _botManager.fetchBotList(
        forceRefresh: forceRefresh,
        keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _bots = bots;
          _isLoading = false;
          if (_botManager.lastError != null && bots.isEmpty) {
            _hasError = true;
            _errorMessage = _botManager.lastError;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '加载失败: ${e.toString()}';
        });
      }
    }
  }

  List<BotModel> get _filteredBots {
    var list = _bots;

    if (_selectedTab == 1) {
      list = list.where((b) => b.isOwned).toList();
    } else if (_selectedTab == 2) {
      list = list.where((b) => b.status == BotStatus.published).take(4).toList();
    }

    if (_selectedCategory > 0) {
      final cat = _categories[_selectedCategory];
      list = list.where((b) => b.category == cat || b.category == null).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((b) =>
          b.name.contains(_searchQuery) ||
          b.description.contains(_searchQuery)).toList();
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
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 顶部栏 ───
            _buildTopBar(isDark),
            // ─── Tab 切换 ───
            _buildTabBar(isDark),
            // ─── 搜索框（点击搜索图标展开） ───
            if (_showSearch) _buildSearchBar(isDark),
            // ─── 分类横滑 ───
            _buildCategoryBar(isDark),
            // ─── Bot 列表 ───
            Expanded(child: _buildBotGrid(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BotEditorScreen()),
          );
          _loadBots(forceRefresh: true);
        },
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ─────────────────── 顶部栏 ───────────────────
  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            'Bot商店',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                  _loadBots();
                }
              });
            },
            child: Icon(
              _showSearch ? Icons.close : Icons.search,
              size: 24,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Tab 栏（蓝色下划线选中态） ───────────────────
  Widget _buildTabBar(bool isDark) {
    final tabs = ['精选', '我的', '最近使用'];
    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? AppColors.info(isDark)
                            : AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      width: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.info(isDark)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────── 搜索框 ───────────────────
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索 Bot...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(isDark)),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _debouncedSearch();
                },
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _loadBots();
                },
                child: Icon(Icons.close, size: 18, color: AppColors.textHint(isDark)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _debouncedSearch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_searchQuery.isNotEmpty) {
      _loadBots(forceRefresh: true);
    }
  }

  // ─────────────────── 分类横滑条 ───────────────────
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
                    ? AppColors.info(isDark).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _categories[i],
                style: TextStyle(
                  color: selected ? AppColors.info(isDark) : AppColors.textSecondary(isDark),
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

  // ─────────────────── Bot 网格列表 ───────────────────
  Widget _buildBotGrid(bool isDark) {
    if (_isLoading && _bots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _bots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '加载失败',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _loadBots(forceRefresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('重试', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }

    final list = _filteredBots;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text('暂无 Bot', style: TextStyle(color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _loadBots(forceRefresh: true),
              child: Text('点击刷新', style: TextStyle(color: AppColors.primary(isDark), fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadBots(forceRefresh: true),
      color: AppColors.primary(isDark),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildBotCard(list[index], index, isDark),
      ),
    );
  }

  // ─────────────────── Bot 卡片 ───────────────────
  Widget _buildBotCard(BotModel bot, int index, bool isDark) {
    final avatarColor = _avatarColors[index % _avatarColors.length];
    final isMyTab = _selectedTab == 1;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BotDetailScreen(botId: bot.id, preloadBot: bot),
          ),
        );
      },
      onLongPress: () {
        if (bot.isOwned) _showBotActions(bot);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 头像 60x60 圆形 + 彩色背景 ──
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: bot.iconUri != null
                    ? ClipOval(
                        child: Image.network(
                          bot.iconUri!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              bot.name.isNotEmpty ? bot.name[0] : 'B',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: avatarColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          bot.name.isNotEmpty ? bot.name[0] : 'B',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: avatarColor,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // ── 名称（粗体） ──
            Text(
              bot.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // ── 简介（2 行省略，灰色小字） ──
            Expanded(
              child: Text(
                bot.description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── 底部：标签 + 按钮 ──
            Row(
              children: [
                // 标签
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      _tagChip('#${bot.category ?? "通用"}', isDark),
                    ],
                  ),
                ),
                // 使用 / 编辑按钮
                GestureDetector(
                  onTap: () async {
                    if (isMyTab) {
                      // "我的" Tab → 编辑
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BotEditorScreen(botId: bot.id, preloadBot: bot),
                        ),
                      );
                      _loadBots(forceRefresh: true);
                    } else {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BotDetailScreen(botId: bot.id, preloadBot: bot),
                        ),
                      );
                      _loadBots(forceRefresh: true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.info(isDark),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isMyTab ? '编辑' : '使用',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
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

  /// 标签小药丸
  Widget _tagChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info(isDark).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: AppColors.info(isDark)),
      ),
    );
  }

  // ─────────────────── Bot 操作菜单 ───────────────────
  void _showBotActions(BotModel bot) {
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
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BotEditorScreen(botId: bot.id, preloadBot: bot),
                  ),
                );
                _loadBots(forceRefresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () async {
                Navigator.pop(ctx);
                final duplicated = await _botManager.duplicateBot(bot.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(duplicated != null ? '复制成功' : '复制失败')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('发布'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await _botManager.publishBot(bot.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? '发布成功' : '发布失败')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteBot(bot);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBot(BotModel bot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Text('确认删除', style: TextStyle(color: AppColors.textPrimary(isDark))),
        content: Text(
          '确定要删除 Bot「${bot.name}」吗？此操作不可恢复。',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _botManager.deleteBot(bot.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已删除' : '删除失败')),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 小酥 v2 - Bot 详情页
// Phase 2: 对接 Coze Studio Bot API，保留原有 UI 设计风格
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/bot_model.dart';
import '../../core/bot/bot_manager.dart';
import '../theme/app_colors.dart';
import 'bot_editor_screen.dart';

/// Bot 详情页
class BotDetailScreen extends StatefulWidget {
  final String botId;
  /// 可选的预加载 Bot 数据（从列表中传入，避免重复请求）
  final BotModel? preloadBot;

  const BotDetailScreen({
    super.key,
    required this.botId,
    this.preloadBot,
  });

  @override
  State<BotDetailScreen> createState() => _BotDetailScreenState();
}

class _BotDetailScreenState extends State<BotDetailScreen> {
  bool _isFavorited = false;
  BotModel? _bot;
  bool _isLoading = true;
  String? _error;

  final BotManager _botManager = BotManager.instance;

  @override
  void initState() {
    super.initState();
    _bot = widget.preloadBot;
    if (_bot != null) {
      _isLoading = false;
      // 后台刷新详情
      _refreshDetail();
    } else {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final bot = await _botManager.getBotDetail(widget.botId);
    if (mounted) {
      setState(() {
        _bot = bot;
        _isLoading = false;
        if (bot == null) {
          _error = _botManager.lastError ?? 'Bot 不存在';
        }
      });
    }
  }

  Future<void> _refreshDetail() async {
    final bot = await _botManager.getBotDetail(widget.botId);
    if (mounted && bot != null) {
      setState(() => _bot = bot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 加载中
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 错误
    final bot = _bot;
    if (bot == null) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Bot 不存在',
                style: TextStyle(color: AppColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loadDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('重试', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Column(
        children: [
          // 顶部导航栏
          _buildTopBar(isDark),
          // 可滚动内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildHeader(bot, isDark),
                  const SizedBox(height: 20),
                  _buildStatsBar(bot, isDark),
                  const SizedBox(height: 24),
                  if (bot.prompt != null && bot.prompt!.isNotEmpty)
                    _buildSection('系统提示词', [bot.prompt!], isDark, icon: Icons.psychology_outlined),
                  if (bot.prompt != null && bot.prompt!.isNotEmpty)
                    const SizedBox(height: 20),
                  if (bot.suggestedQuestions.isNotEmpty)
                    _buildExamplesSection(bot, isDark),
                  if (bot.suggestedQuestions.isNotEmpty)
                    const SizedBox(height: 20),
                  _buildConfigSection(bot, isDark),
                  const SizedBox(height: 20),
                  if (bot.category != null || _buildTags(bot).isNotEmpty)
                    _buildTagsSection(bot, isDark),
                ],
              ),
            ),
          ),
          // 底部固定操作栏
          _buildBottomBar(bot, isDark),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary(isDark)),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 22, color: AppColors.textSecondary(isDark)),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BotEditorScreen(botId: widget.botId, preloadBot: _bot),
                  ),
                );
                _refreshDetail();
              },
            ),
            IconButton(
              icon: Icon(Icons.more_horiz, size: 22, color: AppColors.textSecondary(isDark)),
              onPressed: () {
                _showMoreActions();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BotModel bot, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 头像
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(isDark).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: bot.iconUri != null
                ? ClipOval(
                    child: Image.network(
                      bot.iconUri!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          _getAvatarEmoji(bot.name),
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _getAvatarEmoji(bot.name),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // 名称
          Text(
            bot.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: bot.status == BotStatus.published
                  ? AppColors.success(isDark).withOpacity(0.12)
                  : AppColors.warning(isDark).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              bot.status.label,
              style: TextStyle(
                fontSize: 12,
                color: bot.status == BotStatus.published
                    ? AppColors.success(isDark)
                    : AppColors.warning(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 描述
          if (bot.description.isNotEmpty)
            Text(
              bot.description,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(isDark),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BotModel bot, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFB800),
              value: bot.rating?.toStringAsFixed(1) ?? '--',
              label: '评分',
              isDark: isDark,
            ),
            Container(width: 0.5, height: 32, color: AppColors.divider(isDark)),
            _buildStatItem(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.error(isDark),
              value: _isFavorited ? '已收藏' : '未收藏',
              label: '收藏',
              isDark: isDark,
            ),
            Container(width: 0.5, height: 32, color: AppColors.divider(isDark)),
            _buildStatItem(
              icon: Icons.play_circle_outline,
              iconColor: AppColors.primary(isDark),
              value: bot.usageCount != null ? _formatCount(bot.usageCount!) : '--',
              label: '使用',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, bool isDark, {IconData? icon}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary(isDark)),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary(isDark).withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary(isDark),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExamplesSection(BotModel bot, bool isDark) {
    if (bot.suggestedQuestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.secondary(isDark)),
              const SizedBox(width: 6),
              Text(
                '使用示例',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bot.suggestedQuestions.map((example) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(isDark: isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider(isDark), width: 0.5),
              ),
              child: Text(
                example,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                  height: 1.5,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildConfigSection(BotModel bot, bool isDark) {
    final hasConfig = bot.pluginIds.isNotEmpty ||
        bot.knowledgeIds.isNotEmpty ||
        bot.modelInfo != null;
    if (!hasConfig) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary(isDark)),
              const SizedBox(width: 6),
              Text(
                '配置信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(isDark), width: 0.5),
            ),
            child: Column(
              children: [
                if (bot.modelInfo != null)
                  _buildConfigRow(isDark, '模型',
                      bot.modelInfo!['model_name']?.toString() ?? bot.modelInfo!['model_id']?.toString() ?? '默认'),
                if (bot.pluginIds.isNotEmpty)
                  _buildConfigRow(isDark, '插件', '${bot.pluginIds.length} 个'),
                if (bot.knowledgeIds.isNotEmpty)
                  _buildConfigRow(isDark, '知识库', '${bot.knowledgeIds.length} 个'),
                if (bot.onboardingPrompt != null)
                  _buildConfigRow(isDark, '开场白', bot.onboardingPrompt!.length > 30
                      ? '${bot.onboardingPrompt!.substring(0, 30)}...'
                      : bot.onboardingPrompt!),
                _buildConfigRow(isDark, '创建时间',
                    bot.createdAt != null
                        ? '${bot.createdAt!.year}-${bot.createdAt!.month.toString().padLeft(2, '0')}-${bot.createdAt!.day.toString().padLeft(2, '0')}'
                        : '未知'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint(isDark),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildTags(BotModel bot) {
    final tags = <String>[];
    if (bot.category != null) tags.add(bot.category!);
    if (bot.status == BotStatus.published) tags.add('已发布');
    if (bot.pluginIds.isNotEmpty) tags.add('有插件');
    if (bot.knowledgeIds.isNotEmpty) tags.add('有知识库');
    return tags;
  }

  Widget _buildTagsSection(BotModel bot, bool isDark) {
    final tags = _buildTags(bot);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary(isDark).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BotModel bot, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildActionButton(
              isDark: isDark,
              icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
              label: '收藏',
              isActive: _isFavorited,
              activeColor: AppColors.error(isDark),
              onTap: () {
                setState(() => _isFavorited = !_isFavorited);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isFavorited ? '已收藏' : '已取消收藏'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            if (bot.isOwned) ...[
              const SizedBox(width: 12),
              _buildActionButton(
                isDark: isDark,
                icon: Icons.edit_outlined,
                label: '编辑',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BotEditorScreen(botId: widget.botId, preloadBot: _bot),
                    ),
                  );
                  _refreshDetail();
                },
              ),
            ],
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  // 开始对话 - 切换到当前 Bot
                  _botManager.setCurrentBot(bot);
                  Navigator.pop(context, bot);
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary(isDark).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '开始对话',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? activeColor : AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? activeColor : AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreActions() {
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
              leading: const Icon(Icons.refresh),
              title: const Text('刷新详情'),
              onTap: () {
                Navigator.pop(ctx);
                _refreshDetail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制 Bot'),
              onTap: () async {
                Navigator.pop(ctx);
                final duplicated = await _botManager.duplicateBot(
                  widget.botId,
                  targetName: '${_bot?.name ?? ''} (副本)',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(duplicated != null ? '复制成功' : '复制失败'),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('发布'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await _botManager.publishBot(widget.botId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '发布成功' : '发布失败'),
                    ),
                  );
                  if (success) _refreshDetail();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Text('确认删除', style: TextStyle(color: AppColors.textPrimary(isDark))),
        content: Text(
          '确定要删除 Bot「${_bot?.name ?? ''}」吗？此操作不可恢复。',
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
              final success = await _botManager.deleteBot(widget.botId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已删除' : '删除失败')),
                );
                if (success) Navigator.pop(context);
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 根据 Bot 名称生成一个 emoji 头像
  String _getAvatarEmoji(String name) {
    if (name.isEmpty) return '🤖';
    final lower = name.toLowerCase();
    if (lower.contains('写') || lower.contains('文案')) return '📝';
    if (lower.contains('投资') || lower.contains('金融') || lower.contains('股票')) return '📈';
    if (lower.contains('法律') || lower.contains('合同')) return '⚖️';
    if (lower.contains('研究') || lower.contains('分析')) return '🔍';
    if (lower.contains('论文') || lower.contains('学术')) return '🎓';
    if (lower.contains('代码') || lower.contains('编程') || lower.contains('开发')) return '💻';
    if (lower.contains('翻译')) return '🌍';
    if (lower.contains('音乐')) return '🎵';
    if (lower.contains('画') || lower.contains('绘')) return '🎨';
    if (lower.contains('健康') || lower.contains('运动')) return '🏋️';
    return '🤖';
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

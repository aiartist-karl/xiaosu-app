// ============================================================================
// 小酥 v2 - Bot 详情页
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// Bot 详情模型（模拟数据）
class _BotDetailData {
  final String id;
  final String name;
  final String avatar;
  final String description;
  final String author;
  final double rating;
  final int ratingCount;
  final int favoriteCount;
  final int usageCount;
  final List<String> features;
  final List<String> examples;
  final List<String> tags;

  const _BotDetailData({
    required this.id,
    required this.name,
    required this.avatar,
    required this.description,
    required this.author,
    this.rating = 4.8,
    this.ratingCount = 128,
    this.favoriteCount = 562,
    this.usageCount = 3842,
    this.features = const [],
    this.examples = const [],
    this.tags = const [],
  });
}

/// 模拟数据仓库
class _BotDetailRepository {
  static const Map<String, _BotDetailData> _data = {
    '1': _BotDetailData(
      id: '1',
      name: '智能写作助手',
      avatar: '\u{1F4DD}',
      description: '专业的AI写作助手，擅长撰写各类文案、营销内容、社交媒体帖子。支持多种写作风格，从正式商业文案到轻松有趣的社交媒体内容都能轻松驾驭。',
      author: '小酥官方',
      rating: 4.9,
      ratingCount: 256,
      favoriteCount: 1024,
      usageCount: 8920,
      features: [
        '支持小红书、公众号、抖音等多种平台风格',
        '自动生成标题、正文、标签',
        '内置SEO优化建议',
        '支持多种写作语气切换',
        '一键生成多版本文案供选择',
      ],
      examples: [
        '"帮我写一篇小红书探店笔记，主题是周末咖啡探店"',
        '"生成10条朋友圈文案，主题是秋天穿搭"',
        '"写一篇公众号文章，介绍AI对教育行业的影响"',
      ],
      tags: ['自媒体', '写作', '营销'],
    ),
    '2': _BotDetailData(
      id: '2',
      name: '投资分析员',
      avatar: '\u{1F4C8}',
      description: '智能投资分析助手，提供个股基本面分析、技术面解读、行业趋势研判。帮你做出更理性的投资决策。',
      author: '小酥官方',
      rating: 4.7,
      ratingCount: 189,
      favoriteCount: 743,
      usageCount: 5621,
      features: [
        '个股基本面深度分析',
        '技术指标解读（K线、MACD、RSI等）',
        '行业动态追踪与研判',
        '财务报表智能解读',
        '风险评估与仓位建议',
      ],
      examples: [
        '"分析一下宁德时代最近的走势和基本面"',
        '"帮我看看新能源行业近期的投资机会"',
        '"解读贵州茅台最新财报"',
      ],
      tags: ['金融', '投资', '分析'],
    ),
    '3': _BotDetailData(
      id: '3',
      name: '法律顾问',
      avatar: '\u{2696}\u{FE0F}',
      description: '专业法律咨询助手，覆盖合同法、劳动法、知识产权等常见法律领域。提供法律条文解读、合同审核要点提示、诉讼文书起草建议。',
      author: '小酥官方',
      rating: 4.6,
      ratingCount: 98,
      favoriteCount: 432,
      usageCount: 2876,
      features: [
        '常见法律问题咨询与解答',
        '合同条款审核与风险提示',
        '诉讼文书模板与建议',
        '劳动法相关问题解答',
        '知识产权咨询',
      ],
      examples: [
        '"租房合同到期房东不退还押金怎么办？"',
        '"帮我审核这份劳动合同有没有陷阱"',
        '"公司拖欠工资，我应该怎么维权？"',
      ],
      tags: ['法律', '合同', '咨询'],
    ),
    '4': _BotDetailData(
      id: '4',
      name: '行业研究员',
      avatar: '\u{1F50D}',
      description: '深度行业研究助手，帮你快速完成行业调研、竞品分析、市场洞察。适合产品经理、创业者、投资人使用。',
      author: '小酥官方',
      rating: 4.8,
      ratingCount: 145,
      favoriteCount: 678,
      usageCount: 4210,
      features: [
        '行业规模与趋势分析',
        '竞品多维度对比',
        '用户画像与需求洞察',
        '商业模式拆解',
        '自动生成研究报告大纲',
      ],
      examples: [
        '"分析一下中国新能源汽车市场格局"',
        '"帮我做一份SaaS赛道的竞品分析"',
        '"调研一下宠物经济的市场规模"',
      ],
      tags: ['互联网', '研究', '分析'],
    ),
    '5': _BotDetailData(
      id: '5',
      name: '论文助手',
      avatar: '\u{1F393}',
      description: '学术科研助手，辅助文献检索、论文写作、引用管理。支持多种学科的学术规范。',
      author: '小酥官方',
      rating: 4.7,
      ratingCount: 167,
      favoriteCount: 892,
      usageCount: 6543,
      features: [
        '学术文献检索与推荐',
        '论文结构与写作指导',
        '引用格式自动管理（APA/MLA/GB-T）',
        '摘要与关键词优化',
        '查重建议与降重技巧',
      ],
      examples: [
        '"帮我梳理大语言模型在医疗领域的应用综述"',
        '"优化这段英文摘要的表达"',
        '"推荐关于强化学习在推荐系统中的参考文献"',
      ],
      tags: ['科研', '论文', '学术'],
    ),
    '6': _BotDetailData(
      id: '6',
      name: '代码专家',
      avatar: '\u{1F4BB}',
      description: '全栈代码助手，支持多种编程语言的代码生成、Bug修复、性能优化和架构设计建议。',
      author: '小酥官方',
      rating: 4.9,
      ratingCount: 312,
      favoriteCount: 1567,
      usageCount: 12480,
      features: [
        '多语言代码生成（Python/JS/Go/Rust等）',
        'Bug诊断与修复建议',
        '代码重构与性能优化',
        '系统架构设计方案',
        '技术选型对比分析',
      ],
      examples: [
        '"用Python写一个异步爬虫框架"',
        '"这段React代码为什么性能很差？帮我优化"',
        '"设计一个高并发订单系统的架构方案"',
      ],
      tags: ['互联网', '编程', '开发'],
    ),
    '7': _BotDetailData(
      id: '7',
      name: '翻译官',
      avatar: '\u{1F30D}',
      description: '专业多语言翻译助手，支持中英日韩法德等20+语言互译。针对技术文档、商务邮件、文学作品等不同场景优化翻译质量。',
      author: '小酥官方',
      rating: 4.8,
      ratingCount: 203,
      favoriteCount: 945,
      usageCount: 9876,
      features: [
        '20+语言高质量互译',
        '专业领域术语库（技术/医学/法律）',
        '语境感知翻译优化',
        '批量翻译与术语一致性检查',
        '翻译记忆与个人词库',
      ],
      examples: [
        '"把这篇技术博客翻译成英文，保持专业术语准确"',
        '"这封商务邮件翻译成日文，语气要正式"',
        '"帮我校对这段中英对照的翻译质量"',
      ],
      tags: ['翻译', '多语言', '工具'],
    ),
  };

  static _BotDetailData? get(String id) => _data[id];
}

/// Bot 详情页
class BotDetailScreen extends StatefulWidget {
  final String botId;

  const BotDetailScreen({super.key, required this.botId});

  @override
  State<BotDetailScreen> createState() => _BotDetailScreenState();
}

class _BotDetailScreenState extends State<BotDetailScreen> {
  bool _isFavorited = false;
  _BotDetailData? _bot;

  @override
  void initState() {
    super.initState();
    _bot = _BotDetailRepository.get(widget.botId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bot = _bot;

    if (bot == null) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary(isDark)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Bot 不存在',
            style: TextStyle(color: AppColors.textSecondary(isDark)),
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
                  _buildSection('功能介绍', bot.features, isDark, icon: Icons.star_outline),
                  const SizedBox(height: 20),
                  _buildExamplesSection(bot, isDark),
                  const SizedBox(height: 20),
                  if (bot.tags.isNotEmpty) _buildTags(bot.tags, isDark),
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
              onPressed: () => context.pop(),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.share_outlined, size: 22, color: AppColors.textSecondary(isDark)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能开发中'), duration: Duration(seconds: 1)),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.more_horiz, size: 22, color: AppColors.textSecondary(isDark)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('更多功能开发中'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_BotDetailData bot, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
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
            child: Center(
              child: Text(
                bot.avatar,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            bot.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'by ${bot.author}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 12),
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

  Widget _buildStatsBar(_BotDetailData bot, bool isDark) {
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
              value: bot.rating.toStringAsFixed(1),
              label: '${bot.ratingCount} 评价',
              isDark: isDark,
            ),
            Container(width: 0.5, height: 32, color: AppColors.divider(isDark)),
            _buildStatItem(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.error(isDark),
              value: _formatCount(bot.favoriteCount),
              label: '收藏',
              isDark: isDark,
            ),
            Container(width: 0.5, height: 32, color: AppColors.divider(isDark)),
            _buildStatItem(
              icon: Icons.play_circle_outline,
              iconColor: AppColors.primary(isDark),
              value: _formatCount(bot.usageCount),
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
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
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

  Widget _buildExamplesSection(_BotDetailData bot, bool isDark) {
    if (bot.examples.isEmpty) return const SizedBox.shrink();
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
          ...bot.examples.map((example) => Padding(
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

  Widget _buildTags(List<String> tags, bool isDark) {
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

  Widget _buildBottomBar(_BotDetailData bot, bool isDark) {
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
            _buildActionButton(
              isDark: isDark,
              icon: Icons.share_outlined,
              label: '分享',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能开发中'), duration: Duration(seconds: 1)),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  context.push('/chat-new', extra: {'botName': bot.name});
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

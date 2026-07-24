import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_widgets.dart';

/// 主仪表盘界面
/// 包含快速开始对话入口、最近会话、技能快捷入口、话题追踪状态、系统状态
/// 底部导航栏：对话 / 技能 / 设置
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// 当前选中的导航索引
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(isDark),
          _buildSkillsTab(isDark),
          _buildSettingsTab(isDark),
        ],
      ),

      // ==================== 底部导航栏 ====================
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension_rounded),
            label: '技能',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }

  /// ==================== 首页标签页 ====================
  Widget _buildDashboardTab(bool isDark) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ==================== 顶部问候区域 ====================
          SliverToBoxAdapter(
            child: _buildGreetingSection(context, isDark),
          ),

          // ==================== 快速开始对话 ====================
          SliverToBoxAdapter(
            child: _buildQuickStartSection(context, isDark),
          ),

          // ==================== 最近会话 ====================
          SliverToBoxAdapter(
            child: _buildRecentSessionsSection(context, isDark),
          ),

          // ==================== 技能快捷入口 ====================
          SliverToBoxAdapter(
            child: _buildSkillShortcutsSection(context, isDark),
          ),

          // ==================== 话题追踪 ====================
          SliverToBoxAdapter(
            child: _buildTopicTrackingSection(context, isDark),
          ),

          // ==================== 系统状态 ====================
          SliverToBoxAdapter(
            child: _buildSystemStatusSection(context, isDark),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  /// 问候区域
  Widget _buildGreetingSection(BuildContext context, bool isDark) {
    final now = DateTime.now();
    String greeting;
    if (now.hour < 6) {
      greeting = '夜深了';
    } else if (now.hour < 12) {
      greeting = '早上好';
    } else if (now.hour < 14) {
      greeting = '中午好';
    } else if (now.hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '有什么需要小酥帮忙的吗？',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          // 用户头像
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.coolGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// 快速开始对话
  Widget _buildQuickStartSection(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '开始新对话',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '和小酥聊点什么吧 ✨',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// 最近会话区域
  Widget _buildRecentSessionsSection(BuildContext context, bool isDark) {
    final sessions = [
      _RecentSession(title: 'Flutter 开发咨询', time: '30分钟前', messages: 5),
      _RecentSession(title: '帮我写周报告', time: '1小时前', messages: 3),
      _RecentSession(title: '数据分析问题', time: '昨天', messages: 8),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近对话',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/sessions');
                },
                child: Text(
                  '查看全部',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 会话列表
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/chat');
                },
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_rounded,
                            size: 16,
                            color: AppColors.primary(isDark),
                          ),
                          const Spacer(),
                          Text(
                            session.time,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textHint(isDark),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        session.title,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.messages} 条消息',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 技能快捷入口
  Widget _buildSkillShortcutsSection(BuildContext context, bool isDark) {
    final skills = [
      _SkillShortcut(name: '搜索', icon: Icons.search_rounded,
          color: AppColors.infoLight),
      _SkillShortcut(name: '图片', icon: Icons.image_rounded,
          color: AppColors.primaryLight),
      _SkillShortcut(name: '代码', icon: Icons.code_rounded,
          color: AppColors.secondaryLight),
      _SkillShortcut(name: '文件', icon: Icons.folder_rounded,
          color: AppColors.warningLight),
      _SkillShortcut(name: '分析', icon: Icons.analytics_rounded,
          color: AppColors.successLight),
      _SkillShortcut(name: '翻译', icon: Icons.translate_rounded,
          color: AppColors.infoLight),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            '快捷技能',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: skills.map((skill) {
              return GestureDetector(
                onTap: () {
                  // TODO: 使用技能
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: skill.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: skill.color.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(skill.icon, color: skill.color, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        skill.name,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 话题追踪状态
  Widget _buildTopicTrackingSection(BuildContext context, bool isDark) {
    final topics = [
      _TopicInfo(name: 'Flutter 3.x 更新', lastUpdate: '2小时前', hasNew: true),
      _TopicInfo(name: 'AI 行业动态', lastUpdate: '今天', hasNew: true),
      _TopicInfo(name: 'Swift 新版本', lastUpdate: '3天前', hasNew: false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '话题追踪',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              BadgeWidget(text: '${topics.where((t) => t.hasNew).length} 条更新'),
            ],
          ),
        ),
        ...topics.map((topic) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: topic.hasNew
                        ? AppColors.success(isDark)
                        : AppColors.textHint(isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.name,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        '最近更新: ${topic.lastUpdate}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint(isDark),
                  size: 20,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 系统状态
  Widget _buildSystemStatusSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '系统状态',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(
                  isDark,
                  icon: Icons.psychology_rounded,
                  label: 'GPT-4o',
                  color: AppColors.successLight,
                ),
                const SizedBox(width: 12),
                _buildStatusChip(
                  isDark,
                  icon: Icons.wifi_rounded,
                  label: '已连接',
                  color: AppColors.successLight,
                ),
                const SizedBox(width: 12),
                _buildStatusChip(
                  isDark,
                  icon: Icons.storage_rounded,
                  label: '128 MB',
                  color: AppColors.infoLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 状态指示标签
  Widget _buildStatusChip(
    bool isDark, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ==================== 技能标签页 ====================
  Widget _buildSkillsTab(bool isDark) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              '技能中心',
              style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索技能...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSkillListItem(
                  isDark,
                  name: '网络搜索',
                  desc: '实时搜索互联网信息',
                  icon: Icons.search_rounded,
                  color: AppColors.infoLight,
                  installed: true,
                ),
                _buildSkillListItem(
                  isDark,
                  name: '图片生成',
                  desc: 'AI 文生图，支持多种风格',
                  icon: Icons.image_rounded,
                  color: AppColors.primaryLight,
                  installed: true,
                ),
                _buildSkillListItem(
                  isDark,
                  name: '代码执行',
                  desc: '沙箱环境运行代码',
                  icon: Icons.code_rounded,
                  color: AppColors.secondaryLight,
                  installed: true,
                ),
                _buildSkillListItem(
                  isDark,
                  name: 'PDF 处理',
                  desc: 'PDF 解析、生成、合并',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.errorLight,
                  installed: false,
                ),
                _buildSkillListItem(
                  isDark,
                  name: '数据分析',
                  desc: '数据清洗、统计、可视化',
                  icon: Icons.analytics_rounded,
                  color: AppColors.successLight,
                  installed: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 技能列表项
  Widget _buildSkillListItem(
    bool isDark, {
    required String name,
    required String desc,
    required IconData icon,
    required Color color,
    required bool installed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (installed)
            BadgeWidget(text: '已安装')
          else
            FilledButton.tonal(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('安装', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// ==================== 设置标签页 ====================
  Widget _buildSettingsTab(bool isDark) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Text(
              '设置',
              style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),

          // 用户信息卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.coolGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用户',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        '点击编辑个人资料',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 22),
              ],
            ),
          ),

          // 设置项列表
          _buildSettingTile(
            isDark,
            icon: Icons.dark_mode_rounded,
            label: '深色模式',
            trailing: Switch(
              value: isDark,
              onChanged: (_) {},
            ),
          ),
          _buildSettingTile(
            isDark,
            icon: Icons.psychology_rounded,
            label: '模型配置',
            subtitle: 'GPT-4o',
            onTap: () {
              Navigator.of(context).pushNamed('/settings/model');
            },
          ),
          _buildSettingTile(
            isDark,
            icon: Icons.memory_rounded,
            label: '记忆管理',
            onTap: () {},
          ),
          _buildSettingTile(
            isDark,
            icon: Icons.extension_rounded,
            label: '技能管理',
            onTap: () {
              Navigator.of(context).pushNamed('/settings/skills');
            },
          ),
          _buildSettingTile(
            isDark,
            icon: Icons.storage_rounded,
            label: '存储管理',
            subtitle: '128 MB 缓存',
            onTap: () {},
          ),
          _buildSettingTile(
            isDark,
            icon: Icons.info_outline_rounded,
            label: '关于小酥',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 设置列表项
  Widget _buildSettingTile(
    bool isDark, {
    required IconData icon,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary(isDark), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint(isDark),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 最近会话数据
class _RecentSession {
  final String title;
  final String time;
  final int messages;
  const _RecentSession({
    required this.title,
    required this.time,
    required this.messages,
  });
}

/// 技能快捷入口数据
class _SkillShortcut {
  final String name;
  final IconData icon;
  final Color color;
  const _SkillShortcut({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// 话题追踪数据
class _TopicInfo {
  final String name;
  final String lastUpdate;
  final bool hasNew;
  const _TopicInfo({
    required this.name,
    required this.lastUpdate,
    required this.hasNew,
  });
}

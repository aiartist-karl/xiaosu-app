import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';

/// 设置主页
/// 分组展示所有设置项：通用、AI 模型、记忆、技能、存储、关于
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ==================== 通用设置 ====================
          _buildSectionHeader('通用', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.language_rounded,
              iconColor: AppColors.infoLight,
              title: '语言',
              subtitle: '简体中文',
              onTap: () => _showLanguageDialog(context, isDark),
            ),
            _SettingsItem(
              icon: Icons.dark_mode_rounded,
              iconColor: AppColors.secondaryLight,
              title: '主题',
              subtitle: isDark ? '深色模式' : '浅色模式',
              trailing: Switch(
                value: isDark,
                onChanged: (_) {
                  // TODO: 通过 ThemeProvider 切换主题
                },
              ),
            ),
            _SettingsItem(
              icon: Icons.notifications_rounded,
              iconColor: AppColors.warningLight,
              title: '通知',
              subtitle: '消息通知设置',
              onTap: () {
                // TODO: 导航到通知设置
              },
            ),
          ]),

          // ==================== AI 模型 ====================
          _buildSectionHeader('AI 模型', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.psychology_rounded,
              iconColor: AppColors.primaryLight,
              title: '模型配置',
              subtitle: 'Provider、API Key、默认模型',
              onTap: () {
                Navigator.of(context).pushNamed('/settings/model');
              },
            ),
            _SettingsItem(
              icon: Icons.speed_rounded,
              iconColor: AppColors.successLight,
              title: '生成参数',
              subtitle: 'Temperature、Top-P、Max Tokens',
              onTap: () {
                // TODO: 导航到生成参数设置
              },
            ),
          ]),

          // ==================== 记忆 ====================
          _buildSectionHeader('记忆', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.memory_rounded,
              iconColor: AppColors.secondaryLight,
              title: '记忆管理',
              subtitle: '查看和管理 AI 记忆',
              onTap: () {
                // TODO: 导航到记忆管理
              },
            ),
            _SettingsItem(
              icon: Icons.person_outline_rounded,
              iconColor: AppColors.infoLight,
              title: '用户画像',
              subtitle: '查看 AI 对你的了解',
              onTap: () {
                // TODO: 导航到用户画像
              },
            ),
            _SettingsItem(
              icon: Icons.forget_rounded,
              iconColor: AppColors.errorLight,
              title: '清除记忆',
              subtitle: '清除所有记忆数据',
              onTap: () {
                _showClearMemoryDialog(context, isDark);
              },
            ),
          ]),

          // ==================== 技能 ====================
          _buildSectionHeader('技能', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.extension_rounded,
              iconColor: AppColors.primaryLight,
              title: '技能管理',
              subtitle: '已安装 5 个技能',
              onTap: () {
                Navigator.of(context).pushNamed('/settings/skills');
              },
            ),
            _SettingsItem(
              icon: Icons.add_circle_outline_rounded,
              iconColor: AppColors.successLight,
              title: '安装技能',
              subtitle: '从技能商店发现更多',
              onTap: () {
                // TODO: 导航到技能商店
              },
            ),
          ]),

          // ==================== 存储 ====================
          _buildSectionHeader('存储', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.storage_rounded,
              iconColor: AppColors.warningLight,
              title: '缓存管理',
              subtitle: '当前缓存: 128 MB',
              onTap: () {
                _showCacheDialog(context, isDark);
              },
            ),
            _SettingsItem(
              icon: Icons.file_download_rounded,
              iconColor: AppColors.infoLight,
              title: '数据导出',
              subtitle: '导出对话记录和配置',
              onTap: () {
                // TODO: 数据导出
              },
            ),
          ]),

          // ==================== 关于 ====================
          _buildSectionHeader('关于', isDark),
          _buildSettingsGroup(isDark, [
            _SettingsItem(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.primaryLight,
              title: '关于小酥',
              subtitle: '版本 1.0.0',
              onTap: () {
                _showAboutDialog(context, isDark);
              },
            ),
            _SettingsItem(
              icon: Icons.feedback_rounded,
              iconColor: AppColors.secondaryLight,
              title: '意见反馈',
              subtitle: '帮助我们做得更好',
              onTap: () {
                // TODO: 反馈页面
              },
            ),
            _SettingsItem(
              icon: Icons.description_outlined,
              iconColor: AppColors.textSecondary(isDark),
              title: '隐私政策',
              onTap: () {
                // TODO: 隐私政策页面
              },
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 构建分节标题
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.primary(isDark),
        ),
      ),
    );
  }

  /// 构建设置项分组
  Widget _buildSettingsGroup(bool isDark, List<_SettingsItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Divider(
                    height: 0.5,
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
              _buildSettingsItem(item, isDark),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建单个设置项
  Widget _buildSettingsItem(_SettingsItem item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 图标
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 20),
              ),
              const SizedBox(width: 14),

              // 标题和副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 右侧操作
              if (item.trailing != null)
                item.trailing!
              else if (item.onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint(isDark),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 语言选择对话框
  void _showLanguageDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: '选择语言',
        children: [
          _buildLanguageOption(context, '简体中文', true, isDark),
          _buildLanguageOption(context, 'English', false, isDark),
          _buildLanguageOption(context, '日本語', false, isDark),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String label,
    bool selected,
    bool isDark,
  ) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary(isDark))
          : null,
      onTap: () => Navigator.pop(context),
    );
  }

  /// 清除记忆确认
  void _showClearMemoryDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除记忆'),
        content: const Text('确定要清除所有记忆数据吗？AI 将不再记得之前的对话内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 清除记忆
            },
            child: Text('清除', style: TextStyle(color: AppColors.error(isDark))),
          ),
        ],
      ),
    );
  }

  /// 缓存管理对话框
  void _showCacheDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cacheInfoRow('对话缓存', '64 MB', isDark),
            _cacheInfoRow('图片缓存', '42 MB', isDark),
            _cacheInfoRow('模型缓存', '22 MB', isDark),
            const Divider(),
            _cacheInfoRow('总计', '128 MB', isDark, isBold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 清除缓存
            },
            child: Text('清除缓存', style: TextStyle(color: AppColors.error(isDark))),
          ),
        ],
      ),
    );
  }

  Widget _cacheInfoRow(String label, String size, bool isDark, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            size,
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// 关于对话框
  void _showAboutDialog(BuildContext context, bool isDark) {
    showAboutDialog(
      context: context,
      applicationName: '小酥',
      applicationVersion: 'v1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text(
          '全能 AI 助手，让智能触手可及 🍪',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '基于先进的 AI 技术，小酥为你提供自然对话、\n知识问答、创作辅助、工具调用等多种能力。',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}

/// 设置项数据
class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
}

// 注意：使用 List 内置的 asMap() 方法
// items.asMap().entries 返回 Iterable<MapEntry<int, T>>

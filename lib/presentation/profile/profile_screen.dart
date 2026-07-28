// ============================================================================
// 小酥 v2 - 我的（个人中心 + Token管理）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../app.dart';

/// 我的页面
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            // ─── 用户信息 ───
            _buildUserInfo(isDark),
            const SizedBox(height: 20),
            // ─── Token 卡片 ───
            _buildTokenCard(context, isDark),
            const SizedBox(height: 20),
            // ─── 功能列表 ───
            _buildMenuSection(context, ref, isDark),
            const SizedBox(height: 20),
            // ─── 其他设置 ───
            _buildSettingsSection(context, ref, isDark),
            const SizedBox(height: 20),
            // ─── 退出登录 ───
            _buildLogoutButton(context, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary(isDark).withOpacity(0.15),
            child: const Icon(Icons.person, size: 32, color: Colors.white54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '卡尔',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1643143@qq.com',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '超级管理员',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textHint(isDark)),
        ],
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context, bool isDark) {
    const balance = 1500;
    const maxBalance = 2000;
    final progress = balance / maxBalance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary(isDark),
            AppColors.primary(isDark).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Token 余额',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$balance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _tokenButton(context, '充值', isDark: true, filled: true, onTap: () {
                Navigator.of(context).pushNamed('/token-recharge');
              }),
              const SizedBox(width: 12),
              _tokenButton(context, '消费记录', isDark: true, filled: false, onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('功能开发中'), duration: Duration(seconds: 1)),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tokenButton(BuildContext context, String label, {required bool isDark, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref, bool isDark) {
    final themeMode = ref.watch(themeModeProvider);
    final currentThemeColor = ref.watch(themeColorProvider);

    return Column(
      children: [
        // 深色模式切换项
        _buildDarkModeSwitch(context, ref, themeMode, isDark),
        const SizedBox(height: 1),
        _menuItem(
          Icons.auto_fix_normal, '模型偏好', '当前: Auto',
          isDark: isDark, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('功能开发中'), duration: Duration(seconds: 1)),
            );
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.notifications_outlined, '通知设置', '',
          isDark: isDark, onTap: () {
            Navigator.of(context).pushNamed('/notification');
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.palette_outlined, '主题颜色', _themeColorLabel(currentThemeColor),
          isDark: isDark, onTap: () {
            _showThemeColorPicker(context, ref, isDark);
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.devices, '设备管理', '',
          isDark: isDark, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('即将上线'), duration: Duration(seconds: 1)),
            );
          },
        ),
      ],
    );
  }

  /// 深色模式切换行
  Widget _buildDarkModeSwitch(BuildContext context, WidgetRef ref, ThemeMode themeMode, bool isDark) {
    final isCurrentlyDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.dark_mode, size: 20, color: AppColors.textSecondary(isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '深色模式',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Switch.adaptive(
            value: isCurrentlyDark,
            activeColor: AppColors.primary(isDark),
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).state =
                  value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ],
      ),
    );
  }

  /// 主题颜色标签
  String _themeColorLabel(ThemeColor color) {
    switch (color) {
      case ThemeColor.orange:
        return '橙色';
      case ThemeColor.blue:
        return '蓝色';
      case ThemeColor.green:
        return '绿色';
      case ThemeColor.purple:
        return '紫色';
      case ThemeColor.red:
        return '红色';
    }
  }

  /// 显示主题颜色选择底部弹窗
  void _showThemeColorPicker(BuildContext context, WidgetRef ref, bool isDark) {
    final currentColor = ref.read(themeColorProvider);

    final colorOptions = <_ColorOption>[
      _ColorOption(ThemeColor.orange, '橙色', Colors.deepOrange),
      _ColorOption(ThemeColor.blue, '蓝色', Colors.blue),
      _ColorOption(ThemeColor.green, '绿色', Colors.green),
      _ColorOption(ThemeColor.purple, '紫色', Colors.purple),
      _ColorOption(ThemeColor.red, '红色', Colors.red),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '选择主题颜色',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: colorOptions.map((option) {
                    final isSelected = currentColor == option.color;
                    return GestureDetector(
                      onTap: () {
                        ref.read(themeColorProvider.notifier).state = option.color;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换为${option.label}主题'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: option.swatchColor,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppColors.textPrimary(isDark), width: 3)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? AppColors.textPrimary(isDark)
                                  : AppColors.textHint(isDark),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, bool isDark) {
    return Column(
      children: [
        _menuItem(
          Icons.info_outline, '关于小酥', 'v1.0.0',
          isDark: isDark, onTap: () {
            Navigator.of(context).pushNamed('/about');
          },
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.code, '开发者选项', '',
          isDark: isDark, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('功能开发中'), duration: Duration(seconds: 1)),
            );
          },
        ),
      ],
    );
  }

  Widget _menuItem(
    IconData icon, String title, String subtitle, {
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: title == '模型偏好' || title == '关于小酥'
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : (title == '设备管理' || title == '开发者选项')
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
          border: Border(
            bottom: (title == '设备管理' || title == '开发者选项')
                ? BorderSide.none
                : BorderSide(color: AppColors.divider(isDark), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint(isDark),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('退出登录'),
            content: const Text('确定要退出当前账号吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出登录'), duration: Duration(seconds: 1)),
                  );
                },
                child: Text(
                  '确定',
                  style: TextStyle(color: AppColors.error(isDark)),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.error(isDark).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '退出登录',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.error(isDark),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 主题颜色枚举
enum ThemeColor { orange, blue, green, purple, red }

/// 主题颜色 Provider
final themeColorProvider = StateProvider<ThemeColor>((ref) => ThemeColor.blue);

/// 颜色选项辅助类
class _ColorOption {
  final ThemeColor color;
  final String label;
  final Color swatchColor;

  const _ColorOption(this.color, this.label, this.swatchColor);
}

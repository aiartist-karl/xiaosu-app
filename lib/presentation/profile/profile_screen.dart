// ============================================================================
// 小酥 v2 - 我的（个人中心 + Token管理）
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 我的页面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _buildTokenCard(isDark),
            const SizedBox(height: 20),
            // ─── 功能列表 ───
            _buildMenuSection(isDark),
            const SizedBox(height: 20),
            // ─── 其他设置 ───
            _buildSettingsSection(isDark),
            const SizedBox(height: 20),
            // ─── 退出登录 ───
            _buildLogoutButton(isDark),
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

  Widget _buildTokenCard(bool isDark) {
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
              _tokenButton('充值', isDark: true, filled: true, onTap: () {}),
              const SizedBox(width: 12),
              _tokenButton('消费记录', isDark: true, filled: false, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tokenButton(String label, {required bool isDark, required bool filled, required VoidCallback onTap}) {
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

  Widget _buildMenuSection(bool isDark) {
    return Column(
      children: [
        _menuItem(
          Icons.auto_fix_normal, '模型偏好', '当前: Auto',
          isDark: isDark, onTap: () {},
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.notifications_outlined, '通知设置', '',
          isDark: isDark, onTap: () {},
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.palette_outlined, '主题颜色', '默认蓝',
          isDark: isDark, onTap: () {},
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.devices, '设备管理', '',
          isDark: isDark, onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    return Column(
      children: [
        _menuItem(
          Icons.info_outline, '关于小酥', 'v1.0.0',
          isDark: isDark, onTap: () {},
        ),
        const SizedBox(height: 1),
        _menuItem(
          Icons.code, '开发者选项', '',
          isDark: isDark, onTap: () {},
        ),
      ],
    );
  }

  Widget _menuItem(
    IconData icon, String title, String subtitle, {
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
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
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        // TODO: 退出登录
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

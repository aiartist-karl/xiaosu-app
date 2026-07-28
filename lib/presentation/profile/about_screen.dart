// ============================================================================
// 小酥 v2 - 关于页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// 关于页面
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于小酥'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 24),
          // ─── Logo + 名称 ───
          _buildHeader(isDark),
          const SizedBox(height: 8),
          // ─── 版本号 ───
          Center(
            child: Text(
              '版本 $_version',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // ─── 更新检查 ───
          _buildCheckUpdate(isDark),
          const SizedBox(height: 20),
          // ─── 链接列表 ───
          _buildLinksSection(context, isDark),
          const SizedBox(height: 20),
          // ─── 联系反馈 ───
          _buildFeedbackSection(isDark),
          const SizedBox(height: 40),
          // ─── 底部版权 ───
          _buildFooter(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(isDark).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🧠', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '小酥',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '你的 AI 智能助手',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckUpdate(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, size: 20, color: AppColors.primary(isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '检查更新',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Text(
            '已是最新版本',
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

  Widget _buildLinksSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _linkItem(
          Icons.description_outlined,
          '用户协议',
          isDark: isDark,
          onTap: () {
            // TODO: 打开用户协议页面
          },
        ),
        const SizedBox(height: 1),
        _linkItem(
          Icons.privacy_tip_outlined,
          '隐私政策',
          isDark: isDark,
          onTap: () {
            // TODO: 打开隐私政策页面
          },
        ),
        const SizedBox(height: 1),
        _linkItem(
          Icons.code,
          '开源许可',
          isDark: isDark,
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: '小酥',
              applicationVersion: _version,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(bool isDark) {
    return Column(
      children: [
        _linkItem(
          Icons.feedback_outlined,
          '意见反馈',
          subtitle: '帮助我们做得更好',
          isDark: isDark,
          onTap: () {
            // TODO: 打开反馈表单
          },
        ),
        const SizedBox(height: 1),
        _linkItem(
          Icons.email_outlined,
          '联系我们',
          subtitle: 'support@xiaosu.app',
          isDark: isDark,
          onTap: () {
            // TODO: 发送邮件
          },
        ),
      ],
    );
  }

  Widget _linkItem(
    IconData icon,
    String title, {
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Text(
          '© 2025 小酥团队',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textHint(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '用心打造，让 AI 更懂你',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint(isDark).withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

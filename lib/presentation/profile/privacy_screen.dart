// ============================================================================
// 小酥 v2 - 隐私设置页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// 隐私设置页面
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _dataSync = true;
  bool _anonymousUsage = true;

  // 模拟缓存大小
  final String _cacheSize = '128.5 MB';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 8),
          // ─── 数据与隐私 ───
          _sectionTitle('数据与隐私', isDark),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.cloud_sync_outlined,
            title: '数据同步',
            subtitle: '自动同步对话历史到云端',
            value: _dataSync,
            isDark: isDark,
            onChanged: (v) => setState(() => _dataSync = v),
          ),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.analytics_outlined,
            title: '匿名使用数据',
            subtitle: '帮助我们改善产品体验',
            value: _anonymousUsage,
            isDark: isDark,
            onChanged: (v) => setState(() => _anonymousUsage = v),
          ),
          const SizedBox(height: 28),
          // ─── 存储管理 ───
          _sectionTitle('存储管理', isDark),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存',
            subtitle: _cacheSize,
            isDark: isDark,
            onTap: () => _showClearCacheDialog(isDark),
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.history_outlined,
            title: '清除对话历史',
            subtitle: '清除所有对话记录',
            isDark: isDark,
            onTap: () => _showClearHistoryDialog(isDark),
          ),
          const SizedBox(height: 40),
          // ─── 危险区域 ───
          _sectionTitle('账号管理', isDark),
          const SizedBox(height: 8),
          _dangerTile(
            icon: Icons.person_off_outlined,
            title: '注销账号',
            subtitle: '永久删除账号及所有数据',
            isDark: isDark,
            onTap: () => _showDeleteAccountDialog(isDark),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary(isDark),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _dangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.error(isDark).withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.error(isDark).withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.error(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error(isDark).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.error(isDark),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '清除缓存',
          style: TextStyle(color: AppColors.textPrimary(isDark)),
        ),
        content: Text(
          '确定要清除 $_cacheSize 的缓存数据吗？',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        backgroundColor: AppColors.surface(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 清除缓存逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('缓存已清除'),
                  backgroundColor: AppColors.success(isDark),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              '确认',
              style: TextStyle(color: AppColors.primary(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '清除对话历史',
          style: TextStyle(color: AppColors.textPrimary(isDark)),
        ),
        content: Text(
          '此操作将清除所有对话记录，且无法恢复。确定继续吗？',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        backgroundColor: AppColors.surface(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 清除历史逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('对话历史已清除'),
                  backgroundColor: AppColors.success(isDark),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              '确认清除',
              style: TextStyle(color: AppColors.error(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error(isDark), size: 22),
            const SizedBox(width: 8),
            Text(
              '注销账号',
              style: TextStyle(color: AppColors.error(isDark)),
            ),
          ],
        ),
        content: Text(
          '注销后，您的账号、对话记录、Token 余额等所有数据将被永久删除，且无法恢复。\n\n确定要注销吗？',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        backgroundColor: AppColors.surface(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '再想想',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 注销账号逻辑
            },
            child: Text(
              '确认注销',
              style: TextStyle(color: AppColors.error(isDark)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 小酥 v2 - 项目空间页
// Phase 3: 移除假数据，显示空状态（暂无项目API）
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 项目空间页面
class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目空间'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppColors.textHint(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无项目数据',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '项目功能即将上线',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 小酥 v2 - 日程管理页
// Phase 3: 移除假数据，显示空状态（暂无日程API）
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 日程管理页面
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程管理'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: AppColors.textHint(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无日程数据',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '日程功能即将上线',
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

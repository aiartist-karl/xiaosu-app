// ============================================================================
// 小酥 v2 - 日程管理页
// 显示今日模拟日程列表
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 日程数据模型
class _ScheduleItem {
  final String time;
  final String title;
  final String status;
  final IconData icon;
  final Color color;

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.status,
    required this.icon,
    required this.color,
  });
}

/// 日程管理页面
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const List<_ScheduleItem> _schedules = [
    _ScheduleItem(
      time: '09:00',
      title: '团队站会 - 同步项目进度',
      status: '已完成',
      icon: Icons.groups,
      color: Colors.green,
    ),
    _ScheduleItem(
      time: '14:00',
      title: 'Bot 工作流优化讨论',
      status: '进行中',
      icon: Icons.autorenew,
      color: Colors.blue,
    ),
    _ScheduleItem(
      time: '16:30',
      title: '新功能需求评审',
      status: '待开始',
      icon: Icons.rate_review,
      color: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程管理'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '今日日程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return _buildScheduleCard(schedule, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(_ScheduleItem schedule, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          // 时间
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: schedule.color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: schedule.color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(schedule.icon, size: 16, color: schedule.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        schedule.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: schedule.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    schedule.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: schedule.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

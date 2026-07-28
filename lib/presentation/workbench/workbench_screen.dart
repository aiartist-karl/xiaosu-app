// ============================================================================
// 小酥 v2 - 工作台（文件/日程/项目/记忆）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// 工作台页面
class WorkbenchScreen extends StatelessWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题
            Text(
              '工作台',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            // ─── 功能卡片网格 ───
            Row(
              children: [
                Expanded(child: _workCard(
                  icon: Icons.folder_outlined,
                  label: '文件',
                  subtitle: '25.3/50GB',
                  color: AppColors.info(isDark),
                  isDark: isDark,
                  onTap: () => context.pushNamed('workbench-files'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _workCard(
                  icon: Icons.calendar_today_outlined,
                  label: '日程',
                  subtitle: '今日 3 项',
                  color: AppColors.success(isDark),
                  isDark: isDark,
                  onTap: () => context.pushNamed('workbench-schedule'),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _workCard(
                  icon: Icons.folder_outlined,
                  label: '项目',
                  subtitle: '2 个进行中',
                  color: AppColors.secondary(isDark),
                  isDark: isDark,
                  onTap: () => context.pushNamed('workbench-project'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _workCard(
                  icon: Icons.psychology_outlined,
                  label: '记忆',
                  subtitle: '查看/管理',
                  color: AppColors.warning(isDark),
                  isDark: isDark,
                  onTap: () => context.pushNamed('workbench-memory'),
                )),
              ],
            ),
            const SizedBox(height: 24),
            // ─── 最近文件 ───
            _sectionHeader('最近文件', '查看全部', isDark, onTap: () => context.pushNamed('workbench-files')),
            const SizedBox(height: 8),
            _fileItem(Icons.description, 'report.md', '2小时前', isDark: isDark),
            _fileItem(Icons.table_chart, 'data.xlsx', '昨天', isDark: isDark),
            _fileItem(Icons.image, 'design_v2.png', '3天前', isDark: isDark),
            const SizedBox(height: 20),
            // ─── 最近日程 ───
            _sectionHeader('最近日程', '查看全部', isDark, onTap: () {}),
            const SizedBox(height: 8),
            _scheduleItem('14:00', '团队周会', isDark: isDark),
            _scheduleItem('明天 09:00', '代码评审', isDark: isDark),
            _scheduleItem('明天 15:00', '产品评审', isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _workCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String action, bool isDark, {required VoidCallback onTap}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fileItem(IconData icon, String name, String time, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider(isDark), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.info(isDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleItem(String time, String title, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider(isDark), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.success(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: AppColors.textHint(isDark)),
        ],
      ),
    );
  }
}

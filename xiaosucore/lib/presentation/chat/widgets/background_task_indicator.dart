// ============================================================================
// 小酥 v2 - 后台任务指示器（右上角 Badge + 下拉面板）
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 后台任务模型
class BackgroundTask {
  final String id;
  final String name;
  final TaskStatus status;
  final double progress; // 0.0 ~ 1.0

  const BackgroundTask({
    required this.id,
    required this.name,
    this.status = TaskStatus.running,
    this.progress = 0.0,
  });
}

enum TaskStatus { running, completed, failed, cancelled }

/// 后台任务指示器
class BackgroundTaskIndicator extends StatelessWidget {
  final List<BackgroundTask> tasks;
  final VoidCallback? onTaskTap;

  const BackgroundTaskIndicator({
    super.key,
    this.tasks = const [],
    this.onTaskTap,
  });

  int get _runningCount =>
      tasks.where((t) => t.status == TaskStatus.running).length;

  @override
  Widget build(BuildContext context) {
    if (_runningCount == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showTaskPanel(context, isDark),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.success(isDark),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$_runningCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showTaskPanel(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.task_alt, color: AppColors.primary(isDark), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '后台任务 ($_runningCount)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...tasks.map((task) => _buildTaskItem(task, isDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BackgroundTask task, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _statusDot(task.status, isDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _statusLabel(task.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(task.status, isDark),
                      ),
                    ),
                    if (task.status == TaskStatus.running && task.progress > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: task.progress,
                          backgroundColor: AppColors.divider(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary(isDark),
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(TaskStatus status, bool isDark) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusColor(status, isDark),
      ),
    );
  }

  String _statusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.running: return '运行中';
      case TaskStatus.completed: return '已完成';
      case TaskStatus.failed: return '失败';
      case TaskStatus.cancelled: return '已取消';
    }
  }

  Color _statusColor(TaskStatus status, bool isDark) {
    switch (status) {
      case TaskStatus.running: return AppColors.success(isDark);
      case TaskStatus.completed: return AppColors.info(isDark);
      case TaskStatus.failed: return AppColors.error(isDark);
      case TaskStatus.cancelled: return AppColors.textHint(isDark);
    }
  }
}

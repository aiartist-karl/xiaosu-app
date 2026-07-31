// ============================================================================
// 小酥 v2 - 动态状态栏（6种状态：空闲/连接中/输入中/搜索中/思考中/分配任务/执行任务）
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 状态栏状态枚举
enum StatusBarState {
  idle,        // 空闲（不显示）
  connecting,  // 连接中
  typing,      // 输入中
  searching,   // 搜索中
  thinking,    // 思考中
  assigning,   // 分配任务
  executing,   // 执行任务
}

/// 动态状态栏组件
class DynamicStatusBar extends StatelessWidget {
  final StatusBarState state;
  final String? taskName; // 执行任务时的任务名

  const DynamicStatusBar({
    super.key,
    this.state = StatusBarState.idle,
    this.taskName,
  });

  @override
  Widget build(BuildContext context) {
    if (state == StatusBarState.idle) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor(state, isDark).withOpacity(0.08),
        border: Border(
          top: BorderSide(color: _statusColor(state, isDark).withOpacity(0.2), width: 0.5),
          bottom: BorderSide(color: _statusColor(state, isDark).withOpacity(0.2), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(isDark),
          const SizedBox(width: 8),
          Text(
            _statusText(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _statusColor(state, isDark),
            ),
          ),
          const SizedBox(width: 8),
          if (state != StatusBarState.idle)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor(state, isDark)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isDark) {
    final color = _statusColor(state, isDark);
    switch (state) {
      case StatusBarState.connecting:
        return Icon(Icons.cloud_outlined, size: 16, color: color);
      case StatusBarState.typing:
        return Icon(Icons.edit_note, size: 16, color: color);
      case StatusBarState.searching:
        return Icon(Icons.search, size: 16, color: color);
      case StatusBarState.thinking:
        return Icon(Icons.psychology_outlined, size: 16, color: color);
      case StatusBarState.assigning:
        return Icon(Icons.assignment_outlined, size: 16, color: color);
      case StatusBarState.executing:
        return Icon(Icons.play_circle_outline, size: 16, color: color);
      default:
        return const SizedBox.shrink();
    }
  }

  String _statusText() {
    switch (state) {
      case StatusBarState.connecting:
        return '小酥正在连接...';
      case StatusBarState.typing:
        return '小酥正在输入 •••';
      case StatusBarState.searching:
        return '小酥正在搜索';
      case StatusBarState.thinking:
        return '小酥正在思考 •••';
      case StatusBarState.assigning:
        return '小酥正在分配后台任务 •••';
      case StatusBarState.executing:
        return '小酥正在执行 ${taskName ?? '任务'}...';
      default:
        return '';
    }
  }

  Color _statusColor(StatusBarState state, bool isDark) {
    switch (state) {
      case StatusBarState.connecting:
        return AppColors.info(isDark);
      case StatusBarState.typing:
        return AppColors.primary(isDark);
      case StatusBarState.searching:
        return AppColors.secondary(isDark);
      case StatusBarState.thinking:
        return AppColors.warning(isDark);
      case StatusBarState.assigning:
        return AppColors.info(isDark);
      case StatusBarState.executing:
        return AppColors.success(isDark);
      default:
        return Colors.transparent;
    }
  }
}

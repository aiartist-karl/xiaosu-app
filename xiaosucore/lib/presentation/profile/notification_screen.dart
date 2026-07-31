// ============================================================================
// 小酥 v2 - 通知设置页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:xiaosu/presentation/theme/app_colors.dart';

/// 通知设置页面
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _pushEnabled = true;
  bool _chatReply = true;
  bool _taskComplete = true;
  bool _scheduleReminder = true;

  // 免打扰时段
  TimeOfDay _dndStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _dndEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 8),
          // ─── 通知总开关 ───
          _sectionTitle('通知总开关', isDark),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.notifications_active_outlined,
            title: '推送通知',
            subtitle: _pushEnabled ? '已开启所有推送通知' : '已关闭所有推送通知',
            value: _pushEnabled,
            isDark: isDark,
            onChanged: (v) => setState(() => _pushEnabled = v),
          ),
          const SizedBox(height: 20),
          // ─── 通知分类 ───
          _sectionTitle('通知分类', isDark),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.chat_bubble_outline,
            title: '对话回复通知',
            subtitle: 'AI 回复消息时通知',
            value: _chatReply,
            isDark: isDark,
            enabled: _pushEnabled,
            onChanged: (v) => setState(() => _chatReply = v),
          ),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.task_alt,
            title: '后台任务完成通知',
            subtitle: '后台任务执行完毕后通知',
            value: _taskComplete,
            isDark: isDark,
            enabled: _pushEnabled,
            onChanged: (v) => setState(() => _taskComplete = v),
          ),
          const SizedBox(height: 8),
          _switchTile(
            icon: Icons.calendar_today_outlined,
            title: '日程提醒',
            subtitle: '日程开始前提醒',
            value: _scheduleReminder,
            isDark: isDark,
            enabled: _pushEnabled,
            onChanged: (v) => setState(() => _scheduleReminder = v),
          ),
          const SizedBox(height: 28),
          // ─── 免打扰时段 ───
          _sectionTitle('免打扰', isDark),
          const SizedBox(height: 8),
          _dndTimeTile(isDark),
          const SizedBox(height: 20),
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
    bool enabled = true,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
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
              onChanged: enabled
                  ? onChanged
                  : null,
              activeColor: AppColors.primary(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dndTimeTile(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.do_not_disturb_outlined, size: 20, color: AppColors.textSecondary(isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '免打扰时段',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(_dndStart)} - ${_formatTime(_dndEnd)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ],
            ),
          ),
          // 开始时间
          _timeChip(_dndStart, isDark, (t) => setState(() => _dndStart = t)),
          const SizedBox(width: 8),
          Text(
            '至',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(width: 8),
          // 结束时间
          _timeChip(_dndEnd, isDark, (t) => setState(() => _dndEnd = t)),
        ],
      ),
    );
  }

  Widget _timeChip(TimeOfDay time, bool isDark, ValueChanged<TimeOfDay> onPicked) {
    return GestureDetector(
      onTap: () => _pickTime(time, onPicked, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary(isDark).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary(isDark),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
    bool isDark,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary(isDark),
              onPrimary: Colors.white,
              surface: AppColors.surface(isDark),
              onSurface: AppColors.textPrimary(isDark),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// 小酥 v2 - 日程管理页
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 日程管理页面
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  // 模拟日程数据
  final List<_ScheduleItem> _schedules = [
    _ScheduleItem(
      title: '团队周会',
      startTime: DateTime.now().subtract(const Duration(hours: 2)).add(const Duration(hours: 3)),
      endTime: DateTime.now().add(const Duration(hours: 2)),
      location: '会议室 A',
      dateKey: _dateKey(DateTime.now()),
    ),
    _ScheduleItem(
      title: '午餐约会',
      startTime: DateTime.now().add(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 3)),
      location: '楼下餐厅',
      dateKey: _dateKey(DateTime.now()),
    ),
    _ScheduleItem(
      title: '代码评审',
      startTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      location: '线上 - 腾讯会议',
      dateKey: _dateKey(DateTime.now().add(const Duration(days: 1))),
    ),
    _ScheduleItem(
      title: '产品需求评审',
      startTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 4)),
      location: '会议室 B',
      dateKey: _dateKey(DateTime.now().add(const Duration(days: 1))),
    ),
    _ScheduleItem(
      title: '客户演示',
      startTime: DateTime.now().add(const Duration(days: 3, hours: 2)),
      endTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
      location: '客户公司',
      dateKey: _dateKey(DateTime.now().add(const Duration(days: 3))),
    ),
  ];

  static String _dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_ScheduleItem> get _selectedDateSchedules {
    final key = _dateKey(_selectedDate);
    return _schedules.where((s) => s.dateKey == key).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程管理'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 月视图日历
          _MonthCalendar(
            focusedMonth: _focusedMonth,
            selectedDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
            onMonthChanged: (month) => setState(() => _focusedMonth = month),
            isDark: isDark,
            scheduleDateKeys: _schedules.map((s) => s.dateKey).toSet(),
          ),
          const Divider(height: 1),
          // 日程列表
          Expanded(
            child: _selectedDateSchedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '当天暂无日程',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedDateSchedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final schedule = _selectedDateSchedules[index];
                      return _ScheduleCard(schedule: schedule, isDark: isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 添加新日程
        },
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── 月历组件 ──────────────────────────────────────────────────
class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final bool isDark;
  final Set<String> scheduleDateKeys;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.isDark,
    required this.scheduleDateKeys,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // 0=Sun
    final totalDays = lastDay.day;

    final weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        children: [
          // 月份切换
          Row(
            children: [
              Text(
                '$year年$month月',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onMonthChanged(DateTime(year, month - 1)),
                icon: Icon(Icons.chevron_left, color: AppColors.textSecondary(isDark)),
                iconSize: 22,
              ),
              IconButton(
                onPressed: () => onMonthChanged(DateTime(year, month + 1)),
                icon: Icon(Icons.chevron_right, color: AppColors.textSecondary(isDark)),
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 星期标签
          Row(
            children: weekLabels.map((label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
            ),
            itemCount: firstWeekday + totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final day = index - firstWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final hasSchedule = scheduleDateKeys.contains(
                '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
              );

              return GestureDetector(
                onTap: () => onDateSelected(date),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary(isDark)
                        : isToday
                            ? AppColors.primary(isDark).withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppColors.primary(isDark)
                                  : AppColors.textPrimary(isDark),
                        ),
                      ),
                      if (hasSchedule)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : AppColors.success(isDark),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 日程卡片 ──────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final _ScheduleItem schedule;
  final bool isDark;

  const _ScheduleCard({required this.schedule, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_fmt(schedule.startTime)} - ${_fmt(schedule.endTime)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          // 左侧色条
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textSecondary(isDark)),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary(isDark)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.location,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textHint(isDark)),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── 日程数据模型 ──────────────────────────────────────────────
class _ScheduleItem {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String dateKey;

  _ScheduleItem({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.dateKey,
  });
}

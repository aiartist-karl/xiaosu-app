// ============================================================================
// 小酥 v2 - 云设备管理页面
// 管理云电脑、云手机，查看设备状态与任务
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 设备类型
enum CloudDeviceType {
  computer, // 云电脑
  phone,    // 云手机
}

/// 设备状态
enum CloudDeviceStatus {
  online,   // 在线空闲
  busy,     // 忙碌中
  offline,  // 离线
}

/// 任务状态
enum TaskStatus {
  running,
  completed,
  failed,
}

/// 设备数据模型
class _CloudDevice {
  final String id;
  final String name;
  final CloudDeviceType type;
  final CloudDeviceStatus status;
  final String spec;
  final int runningTasks;
  final String lastActive;

  const _CloudDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.spec,
    required this.runningTasks,
    required this.lastActive,
  });
}

/// 任务数据模型
class _DeviceTask {
  final String id;
  final String title;
  final TaskStatus status;
  final String startedAt;
  final double progress;

  const _DeviceTask({
    required this.id,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.progress,
  });
}

/// 云设备管理页面
class CloudDeviceScreen extends StatefulWidget {
  const CloudDeviceScreen({super.key});

  @override
  State<CloudDeviceScreen> createState() => _CloudDeviceScreenState();
}

class _CloudDeviceScreenState extends State<CloudDeviceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedDeviceId;

  static const List<_CloudDevice> _devices = [
    _CloudDevice(
      id: 'pc-001',
      name: '云电脑-工作区',
      type: CloudDeviceType.computer,
      status: CloudDeviceStatus.online,
      spec: '4核 8GB · 100GB SSD',
      runningTasks: 0,
      lastActive: '刚刚',
    ),
    _CloudDevice(
      id: 'pc-002',
      name: '云电脑-测试环境',
      type: CloudDeviceType.computer,
      status: CloudDeviceStatus.busy,
      spec: '8核 16GB · 200GB SSD',
      runningTasks: 2,
      lastActive: '运行中',
    ),
    _CloudDevice(
      id: 'phone-001',
      name: '云手机-主力机',
      type: CloudDeviceType.phone,
      status: CloudDeviceStatus.online,
      spec: '8核 12GB · 128GB',
      runningTasks: 0,
      lastActive: '5分钟前',
    ),
    _CloudDevice(
      id: 'phone-002',
      name: '云手机-备用机',
      type: CloudDeviceType.phone,
      status: CloudDeviceStatus.offline,
      spec: '4核 8GB · 64GB',
      runningTasks: 0,
      lastActive: '3小时前',
    ),
  ];

  static const Map<String, List<_DeviceTask>> _deviceTasks = {
    'pc-002': [
      _DeviceTask(
        id: 't1',
        title: '网页数据采集 - GitHub Trending',
        status: TaskStatus.running,
        startedAt: '10分钟前',
        progress: 0.65,
      ),
      _DeviceTask(
        id: 't2',
        title: 'API 自动化测试 - 支付模块',
        status: TaskStatus.running,
        startedAt: '25分钟前',
        progress: 0.3,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_CloudDevice> get _computers =>
      _devices.where((d) => d.type == CloudDeviceType.computer).toList();

  List<_CloudDevice> get _phones =>
      _devices.where((d) => d.type == CloudDeviceType.phone).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('云设备'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '设备列表'),
            Tab(text: '任务监控'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDeviceListTab(isDark),
          _buildTaskMonitorTab(isDark),
        ],
      ),
    );
  }

  // ─────────────────── 设备列表 Tab ───────────────────
  Widget _buildDeviceListTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 统计卡片
        _buildStatsCard(isDark),
        const SizedBox(height: 20),

        // 云电脑
        _buildSectionTitle('云电脑', _computers.length, isDark),
        const SizedBox(height: 8),
        ..._computers.map((d) => _buildDeviceCard(d, isDark)),
        const SizedBox(height: 20),

        // 云手机
        _buildSectionTitle('云手机', _phones.length, isDark),
        const SizedBox(height: 8),
        ..._phones.map((d) => _buildDeviceCard(d, isDark)),
      ],
    );
  }

  Widget _buildStatsCard(bool isDark) {
    final onlineCount = _devices.where((d) => d.status == CloudDeviceStatus.online).length;
    final busyCount = _devices.where((d) => d.status == CloudDeviceStatus.busy).length;
    final offlineCount = _devices.where((d) => d.status == CloudDeviceStatus.offline).length;
    final totalTasks = _devices.fold<int>(0, (sum, d) => sum + d.runningTasks);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary(isDark),
            AppColors.primary(isDark).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('云设备概览', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem('${_devices.length}', '总设备', Colors.white),
              _statItem('$onlineCount', '在线', Colors.greenAccent),
              _statItem('$busyCount', '忙碌', Colors.orangeAccent),
              _statItem('$offlineCount', '离线', Colors.white54),
              _statItem('$totalTasks', '任务', Colors.cyanAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, bool isDark) {
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
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.textHint(isDark).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(_CloudDevice device, bool isDark) {
    final isSelected = _selectedDeviceId == device.id;
    final statusColor = _getStatusColor(device.status);
    final statusText = _getStatusText(device.status);
    final deviceIcon = device.type == CloudDeviceType.computer
        ? Icons.computer
        : Icons.smartphone;

    return GestureDetector(
      onTap: () => setState(() => _selectedDeviceId = device.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary(isDark)
                : AppColors.divider(isDark),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // 设备图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(deviceIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                // 设备信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        device.spec,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 展开的操作区
            if (isSelected) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.divider(isDark)),
              const SizedBox(height: 12),
              Row(
                children: [
                  // 活跃信息
                  Icon(Icons.access_time, size: 14, color: AppColors.textHint(isDark)),
                  const SizedBox(width: 4),
                  Text(
                    '最后活跃: ${device.lastActive}',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint(isDark)),
                  ),
                  if (device.runningTasks > 0) ...[
                    const Spacer(),
                    Icon(Icons.task_alt, size: 14, color: AppColors.warning(isDark)),
                    const SizedBox(width: 4),
                    Text(
                      '${device.runningTasks} 个任务运行中',
                      style: TextStyle(fontSize: 12, color: AppColors.warning(isDark)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (device.status != CloudDeviceStatus.offline)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.send,
                        label: '发送任务',
                        color: AppColors.primary(isDark),
                        isDark: isDark,
                        onTap: () => _showSendTaskDialog(device, isDark),
                      ),
                    ),
                  if (device.status != CloudDeviceStatus.offline)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.visibility,
                      label: '查看状态',
                      color: AppColors.info(isDark),
                      isDark: isDark,
                      onTap: () => _showDeviceDetail(device, isDark),
                    ),
                  ),
                  if (device.status != CloudDeviceStatus.offline) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.power_settings_new,
                        label: '关机',
                        color: AppColors.error(isDark),
                        isDark: isDark,
                        onTap: () => _showPowerOffConfirm(device, isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 任务监控 Tab ───────────────────
  Widget _buildTaskMonitorTab(bool isDark) {
    final allTasks = <_DeviceTask>[];
    final deviceNameMap = <String, String>{};

    for (final entry in _deviceTasks.entries) {
      final device = _devices.firstWhere((d) => d.id == entry.key);
      deviceNameMap[entry.key] = device.name;
      allTasks.addAll(entry.value);
    }

    if (allTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 64, color: AppColors.textHint(isDark)),
            const SizedBox(height: 16),
            Text(
              '暂无运行中的任务',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '向云设备发送任务后，将在此显示进度',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '运行中的任务',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 12),
        ...allTasks.map((task) => _buildTaskCard(task, isDark)),
      ],
    );
  }

  Widget _buildTaskCard(_DeviceTask task, bool isDark) {
    final statusColor = task.status == TaskStatus.running
        ? AppColors.info(isDark)
        : task.status == TaskStatus.completed
            ? AppColors.success(isDark)
            : AppColors.error(isDark);

    final statusText = task.status == TaskStatus.running
        ? '运行中'
        : task.status == TaskStatus.completed
            ? '已完成'
            : '失败';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  task.status == TaskStatus.running ? Icons.sync : Icons.check_circle,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '启动于 ${task.startedAt}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (task.status == TaskStatus.running) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: AppColors.divider(isDark),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(task.progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint(isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────── 弹窗方法 ───────────────────

  void _showSendTaskDialog(_CloudDevice device, bool isDark) {
    final taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '发送任务到 ${device.name}',
          style: TextStyle(color: AppColors.textPrimary(isDark)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入任务描述，系统将自动分发到该设备执行。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: taskController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '例如：抓取某网站的数据并生成报告...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.surfaceVariant(isDark: isDark),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary(isDark))),
          ),
          FilledButton(
            onPressed: () {
              final task = taskController.text.trim();
              Navigator.pop(ctx);
              if (task.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('任务已发送到 ${device.name}'),
                    backgroundColor: AppColors.success(isDark),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetail(_CloudDevice device, bool isDark) {
    final tasks = _deviceTasks[device.id] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  device.type == CloudDeviceType.computer
                      ? Icons.computer
                      : Icons.smartphone,
                  color: AppColors.primary(isDark),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('设备ID', device.id, isDark),
            _detailRow('规格', device.spec, isDark),
            _detailRow('状态', _getStatusText(device.status), isDark),
            _detailRow('最后活跃', device.lastActive, isDark),
            _detailRow('运行任务', '${device.runningTasks}', isDark),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '当前任务',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.info(isDark)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                    Text(
                      '${(t.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info(isDark),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint(isDark),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPowerOffConfirm(_CloudDevice device, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error(isDark), size: 22),
            const SizedBox(width: 8),
            Text('确认关机', style: TextStyle(color: AppColors.error(isDark))),
          ],
        ),
        content: Text(
          '确定要关闭「${device.name}」吗？运行中的任务将被中断。',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        backgroundColor: AppColors.surface(isDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「${device.name}」已关机'),
                  backgroundColor: AppColors.error(isDark),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text('确认关机', style: TextStyle(color: AppColors.error(isDark))),
          ),
        ],
      ),
    );
  }

  // ─────────────────── 工具方法 ───────────────────

  Color _getStatusColor(CloudDeviceStatus status) {
    switch (status) {
      case CloudDeviceStatus.online:
        return const Color(0xFF10B981);
      case CloudDeviceStatus.busy:
        return const Color(0xFFF59E0B);
      case CloudDeviceStatus.offline:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(CloudDeviceStatus status) {
    switch (status) {
      case CloudDeviceStatus.online:
        return '在线';
      case CloudDeviceStatus.busy:
        return '忙碌';
      case CloudDeviceStatus.offline:
        return '离线';
    }
  }
}

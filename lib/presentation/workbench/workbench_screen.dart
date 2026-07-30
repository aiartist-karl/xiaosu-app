// ============================================================================
// 小酥 v2 - 工作台（文件/日程/项目/记忆）
// Phase 3: 对接真实API，移除假数据
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/file_repository.dart';
import '../../data/repositories/memory_repository.dart';
import '../theme/app_colors.dart';

/// 工作台页面
class WorkbenchScreen extends StatefulWidget {
  const WorkbenchScreen({super.key});

  @override
  State<WorkbenchScreen> createState() => _WorkbenchScreenState();
}

class _WorkbenchScreenState extends State<WorkbenchScreen> {
  final FileRepository _fileRepo = FileRepository();
  final MemoryRepository _memoryRepo = MemoryRepository.instance;

  int? _fileCount;
  int? _memoryCount;
  bool _loadingCards = true;

  /// 最近文件（模拟数据占位，后续对接 API）
  final List<_RecentFile> _recentFiles = [
    _RecentFile('产品需求文档 v3.pdf', '今天 14:30', Icons.picture_as_pdf, Color(0xFFEF4444)),
    _RecentFile('Q2 运营数据.xlsx', '今天 10:15', Icons.table_chart, Color(0xFF10B981)),
    _RecentFile('会议纪要-0610.docx', '昨天 17:00', Icons.description, Color(0xFF3B82F6)),
  ];

  /// 最近日程（模拟数据占位，后续对接 API）
  final List<_RecentEvent> _recentEvents = [
    _RecentEvent('今天 15:00', '产品评审会议'),
    _RecentEvent('今天 17:30', '与设计团队同步'),
    _RecentEvent('明天 10:00', '周报撰写'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    try {
      final fileResult = await _fileRepo.fetchFileList();
      final memoryResult = await _memoryRepo.fetchMemoryList();

      if (mounted) {
        setState(() {
          _fileCount = fileResult.success ? (fileResult.data?.length ?? 0) : null;
          _memoryCount = memoryResult.success ? (memoryResult.data?.length ?? 0) : null;
          _loadingCards = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCards = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ─── 顶栏 ───
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                '工作台',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),

            // ─── 4 个入口卡片（2x2 网格） ───
            _buildEntryGrid(isDark),
            const SizedBox(height: 24),

            // ─── 最近文件 ───
            _buildSectionHeader('最近文件', '查看更多', isDark, () {
              // TODO: navigate to full file list
            }),
            const SizedBox(height: 8),
            _buildRecentFileList(isDark),
            const SizedBox(height: 24),

            // ─── 最近日程 ───
            _buildSectionHeader('最近日程', '查看更多', isDark, () {
              context.pushNamed('workbench-schedule');
            }),
            const SizedBox(height: 8),
            _buildRecentEventList(isDark),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 4 入口卡片 ───────────────────
  Widget _buildEntryGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _entryCard(
                emoji: '📁',
                label: '文件',
                subtitle: _loadingCards ? '加载中...' : '25.3/50GB',
                color: AppColors.info(isDark),
                isDark: isDark,
                onTap: () => context.pushNamed('workbench-files'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _entryCard(
                emoji: '📅',
                label: '日程',
                subtitle: '今日3项',
                color: AppColors.success(isDark),
                isDark: isDark,
                onTap: () => context.pushNamed('workbench-schedule'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _entryCard(
                emoji: '📋',
                label: '项目',
                subtitle: '2个进行中',
                color: AppColors.secondary(isDark),
                isDark: isDark,
                onTap: () => context.pushNamed('workbench-project'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _entryCard(
                emoji: '🧠',
                label: '记忆',
                subtitle: '查看/管理',
                color: AppColors.warning(isDark),
                isDark: isDark,
                onTap: () => context.pushNamed('workbench-memory'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ─── 云设备入口（全宽） ───
        _cloudDeviceEntry(isDark),
      ],
    );
  }

  Widget _cloudDeviceEntry(bool isDark) {
    return GestureDetector(
      onTap: () => context.pushNamed('cloud-devices'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withOpacity(isDark ? 0.3 : 0.08),
              const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.cloud, color: Color(0xFF6366F1), size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '云设备',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '云电脑 2台 · 云手机 2台 · 2台在线',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint(isDark), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _entryCard({
    required String emoji,
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
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标 40x40
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
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

  // ─────────────────── 分区标题 ───────────────────
  Widget _buildSectionHeader(
    String title,
    String actionLabel,
    bool isDark,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary(isDark)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────── 最近文件列表 ───────────────────
  Widget _buildRecentFileList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _recentFiles.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.5,
                indent: 56,
                color: AppColors.divider(isDark),
              ),
            _fileListItem(_recentFiles[i], isDark),
          ],
        ],
      ),
    );
  }

  Widget _fileListItem(_RecentFile file, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: file.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(file.icon, color: file.color, size: 20),
      ),
      title: Text(
        file.name,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary(isDark)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file.time,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark)),
      ),
      dense: true,
    );
  }

  // ─────────────────── 最近日程列表 ───────────────────
  Widget _buildRecentEventList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _recentEvents.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.5,
                indent: 16,
                color: AppColors.divider(isDark),
              ),
            _eventListItem(_recentEvents[i], isDark),
          ],
        ],
      ),
    );
  }

  Widget _eventListItem(_RecentEvent event, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 左侧时间竖条
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.info(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.info(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────── 辅助数据类 ───────────────────

class _RecentFile {
  final String name;
  final String time;
  final IconData icon;
  final Color color;

  const _RecentFile(this.name, this.time, this.icon, this.color);
}

class _RecentEvent {
  final String time;
  final String title;

  const _RecentEvent(this.time, this.title);
}

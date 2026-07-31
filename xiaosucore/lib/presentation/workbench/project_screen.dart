// ============================================================================
// 小酥 v2 - 项目空间页
// 显示模拟项目列表
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 项目数据模型
class _ProjectItem {
  final String name;
  final String status;
  final String createdAt;
  final IconData icon;
  final Color statusColor;

  const _ProjectItem({
    required this.name,
    required this.status,
    required this.createdAt,
    required this.icon,
    required this.statusColor,
  });
}

/// 项目空间页面
class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  static const List<_ProjectItem> _projects = [
    _ProjectItem(
      name: '智能客服 Bot',
      status: '运行中',
      createdAt: '2025-06-01',
      icon: Icons.smart_toy,
      statusColor: Colors.green,
    ),
    _ProjectItem(
      name: '周报生成工作流',
      status: '已暂停',
      createdAt: '2025-06-10',
      icon: Icons.article,
      statusColor: Colors.orange,
    ),
    _ProjectItem(
      name: '知识库问答系统',
      status: '开发中',
      createdAt: '2025-06-15',
      icon: Icons.menu_book,
      statusColor: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目空间'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return _buildProjectCard(project, isDark);
        },
      ),
    );
  }

  Widget _buildProjectCard(_ProjectItem project, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: project.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(project.icon, color: project.statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '创建于 ${project.createdAt}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: project.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              project.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: project.statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

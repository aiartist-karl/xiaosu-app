// ============================================================================
// 小酥 v2 - 项目空间页
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 项目空间页面
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 模拟项目数据
  final List<_ProjectItem> _projects = [
    _ProjectItem(
      name: '小酥 AI 助手 v2',
      description: '全功能 AI 助手平台的核心版本迭代，包含对话引擎、插件系统和技能框架',
      members: ['张', '李', '王', '赵'],
      memberColors: [0xFFE8895C, 0xFF6C63FF, 0xFF10B981, 0xFFF59E0B],
      recentActivity: DateTime.now().subtract(const Duration(hours: 1)),
      fileCount: 42,
      status: _ProjectStatus.active,
    ),
    _ProjectItem(
      name: '智能客服系统',
      description: '基于大语言模型的智能客服平台，支持多轮对话和知识库检索',
      members: ['陈', '刘'],
      memberColors: [0xFF3B82F6, 0xFFEF4444],
      recentActivity: DateTime.now().subtract(const Duration(hours: 6)),
      fileCount: 18,
      status: _ProjectStatus.active,
    ),
    _ProjectItem(
      name: '数据分析看板',
      description: '实时数据监控与可视化分析系统，集成多种图表组件和数据源',
      members: ['周', '吴', '孙'],
      memberColors: [0xFF8B84FF, 0xFF34D399, 0xFFFBBF24],
      recentActivity: DateTime.now().subtract(const Duration(days: 2)),
      fileCount: 27,
      status: _ProjectStatus.paused,
    ),
  ];

  List<_ProjectItem> get _filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    return _projects.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目空间'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '搜索项目...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surfaceVariant(isDark: isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // 项目统计
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '共 ${_filteredProjects.length} 个项目',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success(isDark).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_projects.where((p) => p.status == _ProjectStatus.active).length} 个进行中',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 项目列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredProjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final project = _filteredProjects[index];
                return _ProjectCard(
                  project: project,
                  isDark: isDark,
                  onTap: () {},
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: 创建新项目
        },
        backgroundColor: AppColors.primary(isDark),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新建项目', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ─── 项目卡片 ──────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final _ProjectItem project;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            // 标题行
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary(isDark).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_special,
                    color: AppColors.secondary(isDark),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: project.status.color(isDark).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project.status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: project.status.color(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textHint(isDark)),
              ],
            ),
            const SizedBox(height: 10),
            // 描述
            Text(
              project.description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // 底部：成员头像 + 文件数 + 最近活动
            Row(
              children: [
                // 成员头像堆叠
                Stack(
                  children: [
                    for (int i = 0; i < project.members.length && i < 4; i++)
                      Positioned(
                        left: i * 22.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(project.memberColors[i]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface(isDark),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              project.members[i],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  '${project.members.length}人',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const Spacer(),
                Icon(Icons.attach_file, size: 14, color: AppColors.textHint(isDark)),
                const SizedBox(width: 4),
                Text(
                  '${project.fileCount} 文件',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: AppColors.textHint(isDark)),
                const SizedBox(width: 4),
                Text(
                  project.activityString,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 项目状态 ──────────────────────────────────────────────────
enum _ProjectStatus {
  active('进行中'),
  paused('已暂停'),
  archived('已归档');

  final String label;
  const _ProjectStatus(this.label);

  Color color(bool isDark) {
    switch (this) {
      case _ProjectStatus.active:
        return AppColors.success(isDark);
      case _ProjectStatus.paused:
        return AppColors.warning(isDark);
      case _ProjectStatus.archived:
        return AppColors.textSecondary(isDark);
    }
  }
}

// ─── 项目数据模型 ──────────────────────────────────────────────
class _ProjectItem {
  final String name;
  final String description;
  final List<String> members;
  final List<int> memberColors;
  final DateTime recentActivity;
  final int fileCount;
  final _ProjectStatus status;

  _ProjectItem({
    required this.name,
    required this.description,
    required this.members,
    required this.memberColors,
    required this.recentActivity,
    required this.fileCount,
    required this.status,
  });

  String get activityString {
    final diff = DateTime.now().difference(recentActivity);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

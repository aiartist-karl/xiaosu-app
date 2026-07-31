// ============================================================================
// 小酥 v2 - 工作流列表页
// 从 WorkflowRepository 获取工作流列表，支持创建、编辑、删除、运行
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/workflow_repository.dart';
import '../../data/models/workflow_model.dart';
import '../theme/app_colors.dart';

/// 工作流列表页
class WorkflowListScreen extends StatefulWidget {
  const WorkflowListScreen({super.key});

  @override
  State<WorkflowListScreen> createState() => _WorkflowListScreenState();
}

class _WorkflowListScreenState extends State<WorkflowListScreen> {
  final WorkflowRepository _repo = WorkflowRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CozeWorkflowSummary> _workflows = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repo.fetchWorkflowList(
      keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _workflows = result.data!;
      } else {
        _error = result.error ?? '加载失败';
      }
    });
  }

  Future<void> _createWorkflow() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建工作流'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '工作流名称',
                hintText: '请输入工作流名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '请输入工作流描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final createResult = await _repo.createWorkflow(
        name: nameController.text,
        description: descController.text,
      );

      if (!mounted) return;

      if (createResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('工作流创建成功')),
        );
        _loadWorkflows();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult.error ?? '创建失败')),
        );
      }
    }
  }

  Future<void> _deleteWorkflow(CozeWorkflowSummary workflow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除工作流'),
        content: Text('确定要删除工作流「${workflow.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _repo.deleteWorkflow(workflow.id);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        _loadWorkflows();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? '删除失败')),
        );
      }
    }
  }

  Future<void> _runWorkflow(CozeWorkflowSummary workflow) async {
    final result = await _repo.runWorkflow(workflowId: workflow.id);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('工作流已触发运行，状态：${result.data?.status.value ?? "运行中"}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '运行失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('工作流管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkflows,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchQuery = v;
                _loadWorkflows();
              },
              decoration: InputDecoration(
                hintText: '搜索工作流...',
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
          // 内容区域
          Expanded(
            child: _buildContent(isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createWorkflow,
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadWorkflows,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_workflows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: AppColors.textHint(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无工作流',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮创建第一个工作流',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkflows,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _workflows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _WorkflowCard(
            workflow: _workflows[index],
            isDark: isDark,
            onTap: () => context.pushNamed(
              'workflow-detail',
              queryParameters: {'workflowId': _workflows[index].id},
            ),
            onRun: () => _runWorkflow(_workflows[index]),
            onDelete: () => _deleteWorkflow(_workflows[index]),
          );
        },
      ),
    );
  }
}

/// 工作流卡片
class _WorkflowCard extends StatelessWidget {
  final CozeWorkflowSummary workflow;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRun;
  final VoidCallback onDelete;

  const _WorkflowCard({
    required this.workflow,
    required this.isDark,
    required this.onTap,
    required this.onRun,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_tree,
                    color: AppColors.primary(isDark),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workflow.description.isNotEmpty
                            ? workflow.description
                            : '暂无描述',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: workflow.isPublished
                        ? AppColors.success(isDark).withOpacity(0.1)
                        : AppColors.warning(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    workflow.isPublished ? '已发布' : '草稿',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: workflow.isPublished
                          ? AppColors.success(isDark)
                          : AppColors.warning(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textHint(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(workflow.updatedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
                const Spacer(),
                // 操作按钮
                TextButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('运行'),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error(isDark),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

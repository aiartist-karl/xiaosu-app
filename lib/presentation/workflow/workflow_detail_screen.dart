// ============================================================================
// 小酥 v2 - 工作流详情/编辑页
// 显示工作流配置，支持编辑参数，可手动触发运行
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/workflow_repository.dart';
import '../../data/models/workflow_model.dart';
import '../theme/app_colors.dart';

/// 工作流详情/编辑页
class WorkflowDetailScreen extends StatefulWidget {
  final String workflowId;

  const WorkflowDetailScreen({super.key, required this.workflowId});

  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen>
    with SingleTickerProviderStateMixin {
  final WorkflowRepository _repo = WorkflowRepository();
  late TabController _tabController;

  CozeWorkflowDetail? _detail;
  List<CozeWorkflowRunRecord> _runHistory = [];
  bool _isLoading = true;
  String? _error;
  bool _isRunning = false;

  // 运行参数
  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
    _loadRunHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repo.fetchWorkflowDetailInternal(widget.workflowId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _detail = result.data!;
        // 初始化参数输入框（基于 Entry 节点的输入参数）
        _initParamControllers();
      } else {
        _error = result.error ?? '加载失败';
      }
    });
  }

  void _initParamControllers() {
    // 查找 Entry 节点的输入参数定义
    if (_detail == null) return;

    final entryNode = _detail!.nodes.where(
      (n) => n.type == CozeWorkflowNodeType.entry,
    );

    if (entryNode.isNotEmpty) {
      for (final input in entryNode.first.inputs) {
        if (!_paramControllers.containsKey(input.name)) {
          final controller = TextEditingController(
            text: input.defaultValue?.toString() ?? '',
          );
          _paramControllers[input.name] = controller;
        }
      }
    }
  }

  Future<void> _loadRunHistory() async {
    final result = await _repo.fetchRunHistory(workflowId: widget.workflowId);

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _runHistory = result.data!;
      });
    }
  }

  Future<void> _runWorkflow() async {
    setState(() => _isRunning = true);

    final parameters = <String, dynamic>{};
    for (final entry in _paramControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        parameters[entry.key] = entry.value.text;
      }
    }

    final result = await _repo.runWorkflow(
      workflowId: widget.workflowId,
      parameters: parameters,
    );

    if (!mounted) return;

    setState(() => _isRunning = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('运行成功！状态：${result.data?.status.value ?? "完成"}'),
          backgroundColor: AppColors.success(Theme.of(context).brightness == Brightness.dark),
        ),
      );
      _loadRunHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? '运行失败'),
          backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark),
        ),
      );
    }
  }

  Future<void> _publishWorkflow() async {
    final result = await _repo.publishWorkflow(widget.workflowId);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功')),
      );
      _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '发布失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? '工作流详情'),
        centerTitle: true,
        actions: [
          if (_detail != null) ...[
            IconButton(
              icon: const Icon(Icons.publish),
              tooltip: '发布',
              onPressed: _publishWorkflow,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () {
                _loadDetail();
                _loadRunHistory();
              },
            ),
          ],
        ],
        bottom: _detail != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '概览'),
                  Tab(text: '参数'),
                  Tab(text: '运行历史'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isDark)
              : _detail != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isDark),
                        _buildParamsTab(isDark),
                        _buildHistoryTab(isDark),
                      ],
                    )
                  : const SizedBox.shrink(),
      floatingActionButton: _detail != null
          ? FloatingActionButton.extended(
              onPressed: _isRunning ? null : _runWorkflow,
              backgroundColor: AppColors.primary(isDark),
              icon: _isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                _isRunning ? '运行中...' : '运行工作流',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadDetail,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 基本信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _detail!.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              if (_detail!.description.isNotEmpty)
                Text(
                  _detail!.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              const SizedBox(height: 16),
              _infoRow('工作流 ID', _detail!.id, isDark),
              _infoRow('状态', _detail!.isPublished ? '已发布' : '草稿', isDark),
              if (_detail!.version != null)
                _infoRow('版本', _detail!.version!, isDark),
              _infoRow('节点数量', '${_detail!.nodes.length}', isDark),
              _infoRow('连线数量', '${_detail!.edges.length}', isDark),
              _infoRow(
                '创建时间',
                _formatDateTime(_detail!.createdAt),
                isDark,
              ),
              _infoRow(
                '更新时间',
                _formatDateTime(_detail!.updatedAt),
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 节点列表
        Text(
          '节点列表（${_detail!.nodes.length}）',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        ..._detail!.nodes.map((node) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider(isDark), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    _nodeIcon(node.type),
                    size: 18,
                    color: AppColors.primary(isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name.isNotEmpty ? node.name : node.type.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          '${node.type.label} · ${node.type.category.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildParamsTab(bool isDark) {
    if (_paramControllers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              '该工作流无可配置参数',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '运行参数',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '填写下方参数后点击右下角"运行工作流"按钮',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textHint(isDark),
          ),
        ),
        const SizedBox(height: 16),
        ..._paramControllers.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: entry.value,
              decoration: InputDecoration(
                labelText: entry.key,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.surfaceVariant(isDark: isDark),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_runHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              '暂无运行记录',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _runHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = _runHistory[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider(isDark), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    record.isSuccess
                        ? Icons.check_circle
                        : (record.status == CozeWorkflowRunStatus.running
                            ? Icons.pending
                            : Icons.error),
                    size: 18,
                    color: record.isSuccess
                        ? AppColors.success(isDark)
                        : (record.status == CozeWorkflowRunStatus.running
                            ? AppColors.warning(isDark)
                            : AppColors.error(isDark)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _runStatusLabel(record.status),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(record.startedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                    ),
                  ),
                ],
              ),
              if (record.duration != null) ...[
                const SizedBox(height: 8),
                Text(
                  '耗时：${record.duration!.inSeconds}.${(record.duration!.inMilliseconds % 1000) ~/ 100}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
              if (record.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  '错误：${record.errorMessage}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error(isDark),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
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

  IconData _nodeIcon(CozeWorkflowNodeType type) {
    switch (type.category) {
      case CozeNodeCategory.control:
        return Icons.power_settings_new;
      case CozeNodeCategory.ai:
        return Icons.auto_awesome;
      case CozeNodeCategory.logic:
        return Icons.call_split;
      case CozeNodeCategory.data:
        return Icons.storage;
      case CozeNodeCategory.knowledge:
        return Icons.menu_book;
      case CozeNodeCategory.db:
        return Icons.database;
      case CozeNodeCategory.conversation:
        return Icons.chat;
      case CozeNodeCategory.network:
        return Icons.http;
      case CozeNodeCategory.other:
        return Icons.widgets;
    }
  }

  String _runStatusLabel(CozeWorkflowRunStatus status) {
    switch (status) {
      case CozeWorkflowRunStatus.success:
        return '成功';
      case CozeWorkflowRunStatus.running:
        return '运行中';
      case CozeWorkflowRunStatus.failed:
        return '失败';
      case CozeWorkflowRunStatus.cancelled:
        return '已取消';
      case CozeWorkflowRunStatus.paused:
        return '已暂停';
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

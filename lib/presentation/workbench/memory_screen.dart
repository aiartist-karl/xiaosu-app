// ============================================================================
// 小酥 v2 - 记忆管理页
// Phase 3: 对接真实API，移除假数据
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/models/memory_model.dart';
import '../theme/app_colors.dart';

/// 记忆管理页面
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final MemoryRepository _memoryRepo = MemoryRepository.instance;
  String _searchQuery = '';

  List<CozeMemory> _memories = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _loadMemories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final result = await _memoryRepo.fetchMemoryList();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.success && result.data != null) {
            _memories = result.data!;
          } else {
            _hasError = true;
            _errorMessage = result.error ?? '获取记忆列表失败';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '加载异常: ${e.toString()}';
        });
      }
    }
  }

  List<CozeMemory> get _filteredMemories {
    var list = _memories;

    // 按Tab类型过滤
    switch (_tabController.index) {
      case 0: // 对话记忆
        list = list.where((m) =>
            m.type == CozeMemoryType.shortTerm || m.type == CozeMemoryType.episodic).toList();
        break;
      case 1: // 知识记忆
        list = list.where((m) => m.type == CozeMemoryType.semantic).toList();
        break;
      case 2: // 偏好记忆
        list = list.where((m) => m.type == CozeMemoryType.longTerm).toList();
        break;
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      list = list.where((m) {
        return m.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆管理'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary(isDark),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary(isDark),
          unselectedLabelColor: AppColors.textSecondary(isDark),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '对话记忆'),
            Tab(text: '知识记忆'),
            Tab(text: '偏好记忆'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '搜索记忆...',
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
          // 内容区
          Expanded(child: _buildContent(isDark)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '加载失败',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadMemories,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('重试', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    final memories = _filteredMemories;

    if (memories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 48,
              color: AppColors.textHint(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? '没有找到匹配的记忆' : '暂无相关记忆',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 统计
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.memory, size: 16, color: AppColors.secondary(isDark)),
              const SizedBox(width: 6),
              Text(
                '${memories.length} 条记忆',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
        // 记忆列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: memories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final memory = memories[index];
              return _MemoryCard(
                memory: memory,
                isDark: isDark,
                onDelete: () => _deleteMemory(memory, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMemory(CozeMemory memory, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记忆吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _memoryRepo.deleteMemory(memory.id);
      if (mounted) {
        if (result.success) {
          setState(() => _memories.removeWhere((m) => m.id == memory.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? '删除失败'),
              backgroundColor: AppColors.error(Theme.of(context).brightness == Brightness.dark),
            ),
          );
        }
      }
    }
  }
}

// ─── 记忆卡片 ──────────────────────────────────────────────────
class _MemoryCard extends StatelessWidget {
  final CozeMemory memory;
  final bool isDark;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    required this.isDark,
    required this.onDelete,
  });

  String _timeString(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary(isDark).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: AppColors.secondary(isDark),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary(isDark),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeString(memory.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        if (memory.tags.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.label_outline,
                            size: 13,
                            color: AppColors.textHint(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            memory.tags.join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error(isDark).withOpacity(0.6),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

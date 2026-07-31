// ============================================================================
// 小酥 v2 - 项目空间页
// 对接后端 /v1/bot/list 接口
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/bot_repository.dart';
import '../../data/models/bot_model.dart';
import '../theme/app_colors.dart';

/// 项目空间页面 - 展示当前空间下的 Bot 列表
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final BotRepository _botRepo = BotRepository();
  List<BotModel> _bots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBots();
  }

  Future<void> _loadBots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _botRepo.fetchFromCoze(pageSize: 50);
      setState(() {
        if (result.success && result.data != null) {
          _bots = result.data!;
        } else {
          _error = result.error ?? '加载失败';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载异常: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目空间'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadBots,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _bots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('暂无项目', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('在 Bot 商店中创建你的第一个 Bot',
                              style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBots,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bot = _bots[index];
                          return _buildProjectCard(bot, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildProjectCard(BotModel bot, bool isDark) {
    final statusColor = bot.status == BotStatus.published
        ? Colors.green
        : bot.status == BotStatus.draft
            ? Colors.orange
            : Colors.blue;
    final statusText = switch (bot.status) {
      BotStatus.published => '已发布',
      BotStatus.draft => '草稿',
      _ => '开发中',
    };

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
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.smart_toy, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bot.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bot.description.isNotEmpty ? bot.description : '暂无描述',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (bot.updatedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '更新于 ${_formatDate(bot.updatedAt!)}',
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) {
      return '${date.month}/${date.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else {
      return '刚刚';
    }
  }
}

// ============================================================================
// 小酥 - 仪表盘
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../services/performance/performance_monitor.dart';
import '../../core/skill/skill_registry.dart';
import '../../core/chat_engine.dart';

/// 仪表盘 - 系统概览
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final monitor = PerformanceMonitor.instance;
    final skills = SkillRegistry.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('仪表盘'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('系统概览', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(title: '总请求', value: '${monitor.totalRequests}', icon: Icons.send, color: Colors.blue),
                const SizedBox(width: 12),
                _StatCard(title: '平均延迟', value: '${monitor.averageLatency.toStringAsFixed(0)}ms', icon: Icons.speed, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(title: '错误率', value: '${(monitor.errorRate * 100).toStringAsFixed(1)}%', icon: Icons.error_outline, color: Colors.orange),
                const SizedBox(width: 12),
                _StatCard(title: '已注册技能', value: '${skills.length}', icon: Icons.extension, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            Text('快速操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('新对话'),
                  avatar: const Icon(Icons.chat, size: 18),
                  onPressed: () {
                    final id = DateTime.now().millisecondsSinceEpoch.toString();
                    ChatEngine.instance.setActiveConversation(id);
                    context.pushNamed('chat', pathParameters: {'conversationId': id});
                  },
                ),
                ActionChip(
                  label: const Text('搜索'),
                  avatar: const Icon(Icons.search, size: 18),
                  onPressed: () => _showSearchDialog(context),
                ),
                ActionChip(
                  label: const Text('技能管理'),
                  avatar: const Icon(Icons.extension, size: 18),
                  onPressed: () => context.pushNamed('skill-manager'),
                ),
                ActionChip(
                  label: const Text('重置监控'),
                  avatar: const Icon(Icons.refresh, size: 18),
                  onPressed: () {
                    monitor.reset();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('搜索对话'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入关键词...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                final query = controller.text.trim();
                if (query.isNotEmpty) {
                  final results = ChatEngine.instance.search(query);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('找到 ${results.length} 条相关消息')),
                  );
                }
              },
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

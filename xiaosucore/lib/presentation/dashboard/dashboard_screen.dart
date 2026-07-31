// ============================================================================
// 小酥 - 仪表盘
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/performance/performance_monitor.dart';
import '../../core/skill/skill_registry.dart';

/// 仪表盘 - 系统概览
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
                ActionChip(label: const Text('新对话'), avatar: const Icon(Icons.chat, size: 18), onPressed: () {}),
                ActionChip(label: const Text('搜索'), avatar: const Icon(Icons.search, size: 18), onPressed: () {}),
                ActionChip(label: const Text('技能管理'), avatar: const Icon(Icons.extension, size: 18), onPressed: () {}),
                ActionChip(label: const Text('重置监控'), avatar: const Icon(Icons.refresh, size: 18), onPressed: () { monitor.reset(); }),
              ],
            ),
          ],
        ),
      ),
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

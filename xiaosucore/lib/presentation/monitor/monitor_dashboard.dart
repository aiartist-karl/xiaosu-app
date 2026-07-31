// ============================================================================
// 小酥 - 监控面板
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/performance/performance_monitor.dart';

/// 监控面板
class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({super.key});

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  final PerformanceMonitor _monitor = PerformanceMonitor.instance;

  @override
  Widget build(BuildContext context) {
    final metrics = _monitor.getRecentMetrics(limit: 20);

    return Scaffold(
      appBar: AppBar(
        title: const Text('性能监控'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _monitor.reset()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 关键指标
            Row(
              children: [
                _MetricTile('总请求', '${_monitor.totalRequests}', Colors.blue),
                const SizedBox(width: 8),
                _MetricTile('平均延迟', '${_monitor.averageLatency.toStringAsFixed(0)}ms', Colors.green),
                const SizedBox(width: 8),
                _MetricTile('错误率', '${(_monitor.errorRate * 100).toStringAsFixed(1)}%', Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            Text('最近请求记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (metrics.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('暂无数据'),
              ))
            else
              ...metrics.reversed.map((m) => Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  title: Text(m.name, style: const TextStyle(fontSize: 13)),
                  trailing: Text('${m.value.toStringAsFixed(1)}${m.unit}',
                      style: const TextStyle(fontSize: 13)),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

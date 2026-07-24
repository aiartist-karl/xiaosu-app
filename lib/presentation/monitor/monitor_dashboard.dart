// ============================================================================
// 小酥 - 监控面板（对接后端版）
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/performance/performance_monitor.dart';
import '../../config/app_config.dart';

/// 监控面板 - 显示后端真实状态 + 本地性能统计
class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({super.key});

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  final PerformanceMonitor _monitor = PerformanceMonitor.instance;
  final http.Client _client = http.Client();

  Map<String, dynamic>? _backendStatus;
  bool _isLoading = false;
  String? _errorMessage;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchBackendStatus();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _fetchBackendStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _client
          .get(Uri.parse('${AppConfig.agentApiBase}/api/health'),
              headers: {'Authorization': 'Bearer ${AppConfig.agentAuthToken}'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _backendStatus = jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
          _wsConnected = true;
        });
      } else {
        setState(() {
          _errorMessage = 'HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '连接失败: $e';
        _isLoading = false;
        _wsConnected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('监控面板'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchBackendStatus,
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 后端状态卡片
            _buildBackendStatusCard(),
            const SizedBox(height: 16),

            // 本地性能指标
            Text('本地性能统计', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
            _buildRecentRequests(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendStatusCard() {
    if (_isLoading && _backendStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, size: 24),
                const SizedBox(width: 8),
                Text('后端Agent服务', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _errorMessage == null ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _errorMessage == null ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _errorMessage == null ? '在线' : '离线',
                        style: TextStyle(
                          fontSize: 12,
                          color: _errorMessage == null ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _fetchBackendStatus,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试连接'),
              ),
            ],
            if (_backendStatus != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildStatusRow('后端版本', _backendStatus!['version']?.toString() ?? 'N/A'),
              _buildStatusRow('模型', _backendStatus!['model']?.toString() ?? 'N/A'),
              _buildStatusRow('工具数量', '${_backendStatus!['tools_count'] ?? 'N/A'}'),
              _buildStatusRow('工作目录', _backendStatus!['workspace']?.toString() ?? 'N/A'),
              _buildStatusRow('运行时间', _backendStatus!['uptime']?.toString() ?? 'N/A'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildStatusRow('API地址', AppConfig.agentApiBase),
              _buildStatusRow('WebSocket', _wsConnected ? '✅ 已连接' : '❌ 未连接'),
              _buildStatusRow('认证', 'Bearer Token'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequests() {
    final metrics = _monitor.getRecentMetrics(limit: 20);
    if (metrics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('暂无请求记录', style: TextStyle(color: Colors.grey))),
        ),
      );
    }
    return Column(
      children: metrics.reversed.map((m) => Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          title: Text(m.name, style: const TextStyle(fontSize: 13)),
          trailing: Text('${m.value.toStringAsFixed(1)}${m.unit}',
              style: const TextStyle(fontSize: 13)),
        ),
      )).toList(),
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

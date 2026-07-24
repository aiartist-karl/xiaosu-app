// ============================================================================
// 小酥 - 仪表盘（对接真实后端数据 + 可视化）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/agent_api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AgentApiService _api = AgentApiService.instance;
  
  bool _isLoading = true;
  bool _isOnline = false;
  
  // 后端真实数据
  int _agentCount = 0;
  int _fileCount = 0;
  int _memoryCount = 0;
  int _calendarCount = 0;
  String _serverStatus = '检测中...';
  List<Map<String, dynamic>> _backendTools = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() { _isLoading = true; });
    
    try {
      // 1. 健康检查
      _isOnline = await _api.healthCheck();
      _serverStatus = _isOnline ? '在线' : '离线';

      // 2. 获取Agent数量
      try {
        final agentsResult = await _api.getAgents();
        if (agentsResult['success'] == true) {
          _agentCount = (agentsResult['agents'] as List?)?.length ?? 0;
        }
      } catch (_) {}

      // 3. 获取文件数量
      try {
        final filesResult = await _api.getFiles();
        if (filesResult['success'] == true) {
          _fileCount = (filesResult['files'] as List?)?.length ?? 0;
        }
      } catch (_) {}

      // 4. 获取记忆数量
      try {
        final memResult = await _api.getMemories();
        if (memResult['success'] == true) {
          _memoryCount = (memResult['memories'] as List?)?.length ?? 0;
        }
      } catch (_) {}

      // 5. 获取日历事件数量
      try {
        final calResult = await _api.getCalendar(days: 30);
        if (calResult['success'] == true) {
          _calendarCount = (calResult['events'] as List?)?.length ?? 0;
        }
      } catch (_) {}

      // 6. 获取后端工具列表
      try {
        final toolsResult = await _api.getBackendTools();
        if (toolsResult['success'] == true) {
          _backendTools = (toolsResult['tools'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        }
      } catch (_) {}

    } catch (e) {
      _serverStatus = '错误';
    }

    if (mounted) setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboardData, tooltip: '刷新'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 服务器状态
                  _buildServerStatusCard(),
                  const SizedBox(height: 16),
                  // 数据统计
                  Text('系统概览', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatCard(title: 'Agent', value: '$_agentCount', icon: Icons.psychology, color: Colors.blue),
                    const SizedBox(width: 12),
                    _StatCard(title: '文件', value: '$_fileCount', icon: Icons.folder, color: Colors.green),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatCard(title: '记忆', value: '$_memoryCount', icon: Icons.memory, color: Colors.purple),
                    const SizedBox(width: 12),
                    _StatCard(title: '日程', value: '$_calendarCount', icon: Icons.calendar_today, color: Colors.orange),
                  ]),
                  const SizedBox(height: 24),
                  // 后端工具可视化
                  Text('后端工具 (${_backendTools.length})', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_backendTools.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('暂无工具数据', style: TextStyle(color: Colors.grey[600]))),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _backendTools.map((tool) {
                        final name = tool['name']?.toString() ?? '';
                        return Chip(
                          avatar: const Icon(Icons.build, size: 16),
                          label: Text(name, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  // 快速操作
                  Text('快速操作', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Agent协作'),
                        avatar: const Icon(Icons.hub, size: 18),
                        onPressed: () => context.push('/agents'),
                      ),
                      ActionChip(
                        label: const Text('文件管理'),
                        avatar: const Icon(Icons.folder, size: 18),
                        onPressed: () => context.push('/files'),
                      ),
                      ActionChip(
                        label: const Text('工具集'),
                        avatar: const Icon(Icons.build, size: 18),
                        onPressed: () => context.push('/tools'),
                      ),
                      ActionChip(
                        label: const Text('插件商店'),
                        avatar: const Icon(Icons.extension, size: 18),
                        onPressed: () => context.push('/plugins'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildServerStatusCard() {
    final statusColor = _isOnline ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('后端服务', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(_serverStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
            if (_isOnline) ...[
              const SizedBox(width: 8),
              Column(children: [
                Text('${_backendTools.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text('工具', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ],
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

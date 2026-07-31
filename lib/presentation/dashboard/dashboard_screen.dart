// ============================================================================
// 小酥 - 仪表盘（对接后端 API）
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 仪表盘 - 聚合后端统计数据
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // 统计数据
  int _botCount = 0;
  int _knowledgeCount = 0;
  int _workflowCount = 0;
  int _pluginCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final gateway = ApiGateway.instance;
      final sessionKey = AppConfig.defaultSessionKey;
      final pat = AppConfig.cozeStudioPat;
      final spaceId = AppConfig.cozeStudioSpaceId;

      // 并行请求所有统计数据
      final results = await Future.wait([
        // Bot 列表
        gateway.get(
          AppConfig.v1BotList,
          queryParameters: {'space_id': spaceId, 'page_index': 0, 'page_size': 1},
          authType: CozeAuthType.pat,
        ).catchError((_) => {'data': {'total': 0}}),

        // 知识库列表
        gateway.post(
          AppConfig.apiKnowledgeList,
          data: {'space_id': spaceId, 'page_index': 1, 'page_size': 1},
          authType: CozeAuthType.session,
        ).catchError((_) => {'data': {'total': 0}}),

        // 工作流列表
        gateway.post(
          AppConfig.apiWorkflowList,
          data: {'space_id': spaceId, 'page': 1, 'size': 1},
          authType: CozeAuthType.session,
        ).catchError((_) => {'data': {'total': 0}}),

        // 插件列表
        gateway.post(
          AppConfig.apiPluginList,
          data: {'space_id': spaceId, 'page_index': 1, 'page_size': 1},
          authType: CozeAuthType.session,
        ).catchError((_) => {'data': {'total': 0}}),
      ]);

      if (!mounted) return;

      setState(() {
        _botCount = _extractTotal(results[0]);
        _knowledgeCount = _extractTotal(results[1]);
        _workflowCount = _extractTotal(results[2]);
        _pluginCount = _extractTotal(results[3]);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  int _extractTotal(dynamic response) {
    try {
      final data = response['data'];
      if (data is Map) {
        return data['total'] as int? ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('资源概览', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(title: 'Bot', value: '$_botCount', icon: Icons.smart_toy, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: '知识库', value: '$_knowledgeCount', icon: Icons.menu_book, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(title: '工作流', value: '$_workflowCount', icon: Icons.account_tree, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: '插件', value: '$_pluginCount', icon: Icons.extension, color: Colors.purple)),
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
                onPressed: () => Navigator.pushNamed(context, '/chat'),
              ),
              ActionChip(
                label: const Text('Bot 管理'),
                avatar: const Icon(Icons.smart_toy, size: 18),
                onPressed: () => Navigator.pushNamed(context, '/bot-store'),
              ),
              ActionChip(
                label: const Text('知识库'),
                avatar: const Icon(Icons.menu_book, size: 18),
                onPressed: () => Navigator.pushNamed(context, '/knowledge'),
              ),
              ActionChip(
                label: const Text('工作流'),
                avatar: const Icon(Icons.account_tree, size: 18),
                onPressed: () => Navigator.pushNamed(context, '/workflow'),
              ),
            ],
          ),
        ],
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
    return Card(
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
    );
  }
}

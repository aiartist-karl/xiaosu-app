// ============================================================================
// 小酥 - 插件商店
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/plugin_market/plugin_market.dart';

/// 插件商店
class PluginStoreScreen extends StatefulWidget {
  const PluginStoreScreen({super.key});

  @override
  State<PluginStoreScreen> createState() => _PluginStoreScreenState();
}

class _PluginStoreScreenState extends State<PluginStoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PluginMarket _market = PluginMarket.instance;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件商店'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '已安装'),
            Tab(text: '可用'),
            Tab(text: '全部'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索插件...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // 标签页
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_market.installedPlugins),
                _buildList(_market.availablePlugins),
                _buildList(_market.allPlugins),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<PluginInfo> plugins) {
    final filtered = _searchQuery.isEmpty
        ? plugins
        : _market.search(_searchQuery);

    if (filtered.isEmpty) {
      return const Center(child: Text('暂无插件'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final plugin = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(plugin.icon, style: const TextStyle(fontSize: 22)),
            ),
            title: Text(plugin.name),
            subtitle: Text(plugin.description),
            trailing: plugin.installed
                ? TextButton(onPressed: () => setState(() => _market.uninstall(plugin.id)), child: const Text('卸载'))
                : FilledButton(onPressed: () => setState(() => _market.install(plugin.id)), child: const Text('安装')),
          ),
        );
      },
    );
  }
}

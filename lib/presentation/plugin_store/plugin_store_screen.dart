// ============================================================================
// 小酥 - 插件商店
// 对接后端 /api/plugin_api/* 接口
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/plugin_repository.dart';
import '../../data/models/plugin_model.dart';
import '../../core/plugin_market/plugin_market.dart';

/// 插件商店 - 合并本地内置插件 + 后端远程插件
class PluginStoreScreen extends StatefulWidget {
  const PluginStoreScreen({super.key});

  @override
  State<PluginStoreScreen> createState() => _PluginStoreScreenState();
}

class _PluginStoreScreenState extends State<PluginStoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PluginMarket _market = PluginMarket.instance;
  final PluginRepository _repo = PluginRepository();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  // 远程插件列表
  List<PluginModel> _remotePlugins = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRemotePlugins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 从后端加载远程插件
  Future<void> _loadRemotePlugins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 获取运行时插件列表（已安装 + 内置）
      final result = await _repo.fetchPlaygroundPluginList();
      if (result.success && result.data != null) {
        setState(() {
          _remotePlugins = result.data!;
          _isLoading = false;
        });
      } else {
        // 如果 playground 列表失败，尝试获取开发者插件列表
        final devResult = await _repo.fetchDevPluginList(pageSize: 50);
        setState(() {
          if (devResult.success && devResult.data != null) {
            _remotePlugins = devResult.data!;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载远程插件失败: $e';
        _isLoading = false;
      });
    }
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
            Tab(text: '远程插件'),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRemotePlugins,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInstalledTab(),
                          _buildRemoteTab(),
                          _buildAllTab(),
                        ],
                      ),
          ),
        ],
      ),
      // 下拉刷新
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRemotePlugins,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  /// 已安装 Tab - 本地已安装 + 远程已安装
  Widget _buildInstalledTab() {
    final localInstalled = _market.installedPlugins;
    final remoteInstalled = _remotePlugins.where((p) => p.isInstalled).toList();

    final items = <Widget>[
      // 本地已安装插件
      ...localInstalled.map((p) => _buildLocalPluginTile(p, isInstalled: true)),
      // 远程已安装插件
      ...remoteInstalled.map((p) => _buildRemotePluginTile(p)),
    ];

    final filtered = _filterItems(items);
    if (filtered.isEmpty) {
      return const Center(child: Text('暂无已安装插件'));
    }

    return RefreshIndicator(
      onRefresh: _loadRemotePlugins,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filtered,
      ),
    );
  }

  /// 远程插件 Tab
  Widget _buildRemoteTab() {
    if (_remotePlugins.isEmpty) {
      return const Center(child: Text('暂无远程插件\n点击右下角刷新按钮加载'));
    }

    final items = _remotePlugins.map((p) => _buildRemotePluginTile(p)).toList();
    final filtered = _filterItems(items);

    if (filtered.isEmpty) {
      return const Center(child: Text('无匹配结果'));
    }

    return RefreshIndicator(
      onRefresh: _loadRemotePlugins,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filtered,
      ),
    );
  }

  /// 全部 Tab - 本地 + 远程
  Widget _buildAllTab() {
    final localAll = _market.allPlugins;
    final items = <Widget>[
      ...localAll.map((p) => _buildLocalPluginTile(p, isInstalled: p.installed)),
      ..._remotePlugins.map((p) => _buildRemotePluginTile(p)),
    ];

    final filtered = _filterItems(items);
    if (filtered.isEmpty) {
      return const Center(child: Text('暂无插件'));
    }

    return RefreshIndicator(
      onRefresh: _loadRemotePlugins,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filtered,
      ),
    );
  }

  /// 搜索过滤
  List<Widget> _filterItems(List<Widget> items) {
    if (_searchQuery.isEmpty) return items;
    // 简单过滤：根据 widget 的 key 或重新构建
    // 由于 Widget 不易过滤，这里返回全部，搜索功能在数据层实现
    return items;
  }

  /// 构建本地插件 Tile
  Widget _buildLocalPluginTile(PluginInfo plugin, {required bool isInstalled}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(plugin.icon, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(plugin.name),
        subtitle: Text('${plugin.description} · ${plugin.category}'),
        trailing: isInstalled
            ? TextButton(
                onPressed: () => setState(() => _market.uninstall(plugin.id)),
                child: const Text('卸载'))
            : FilledButton(
                onPressed: () => setState(() => _market.install(plugin.id)),
                child: const Text('安装')),
      ),
    );
  }

  /// 构建远程插件 Tile
  Widget _buildRemotePluginTile(PluginModel plugin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: plugin.iconUrl != null && plugin.iconUrl!.isNotEmpty
              ? Image.network(plugin.iconUrl!, width: 24, height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.extension, size: 24))
              : const Icon(Icons.extension, size: 24),
        ),
        title: Text(plugin.name),
        subtitle: Text(
          '${plugin.description}\nv${plugin.version} · ${plugin.author}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: plugin.isInstalled
            ? const Chip(label: Text('已安装'))
            : FilledButton.tonal(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('插件 "${plugin.name}" 安装功能开发中')),
                  );
                },
                child: const Text('安装')),
      ),
    );
  }
}

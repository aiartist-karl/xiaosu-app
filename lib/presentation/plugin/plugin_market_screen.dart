// ============================================================================
// 小酥 v2 - 插件市场页面
// 从 PluginRepository 获取可用插件列表，支持安装/卸载
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/plugin_repository.dart';
import '../../data/models/plugin_model.dart';
import '../theme/app_colors.dart';

/// 插件市场页面
class PluginMarketScreen extends StatefulWidget {
  const PluginMarketScreen({super.key});

  @override
  State<PluginMarketScreen> createState() => _PluginMarketScreenState();
}

class _PluginMarketScreenState extends State<PluginMarketScreen>
    with SingleTickerProviderStateMixin {
  final PluginRepository _repo = PluginRepository();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<PluginModel> _installedPlugins = [];
  List<PluginModel> _marketPlugins = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlugins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlugins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 并行加载已安装插件和市场插件
    final results = await Future.wait([
      _repo.fetchPlaygroundPluginList(),
      _repo.fetchMarketplacePluginList(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (results[0].success && results[0].data != null) {
        _installedPlugins = results[0].data!;
      }
      if (results[1].success && results[1].data != null) {
        _marketPlugins = results[1].data!;
      }
      if (!results[0].success && !results[1].success) {
        _error = results[0].error ?? results[1].error ?? '加载失败';
      }
    });
  }

  List<PluginModel> get _filteredInstalled {
    if (_searchQuery.isEmpty) return _installedPlugins;
    return _installedPlugins
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<PluginModel> get _filteredMarket {
    if (_searchQuery.isEmpty) return _marketPlugins;
    return _marketPlugins
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _toggleInstall(PluginModel plugin) async {
    if (plugin.isInstalled) {
      // 卸载
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('卸载插件'),
          content: Text('确定要卸载「${plugin.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('卸载'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final result = await _repo.deletePlugin(plugin.id);
        if (!mounted) return;

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已卸载')),
          );
          _loadPlugins();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? '卸载失败')),
          );
        }
      }
    } else {
      // 安装（通过收藏机制）
      final result = await _repo.favoriteMarketProduct(plugin.id);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已安装「${plugin.name}」')),
        );
        _loadPlugins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? '安装失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('插件市场'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlugins,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '已安装（${_installedPlugins.length}）'),
            Tab(text: '全部插件'),
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
                hintText: '搜索插件...',
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
          // 内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _installedPlugins.isEmpty && _marketPlugins.isEmpty
                    ? _buildError(isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPluginList(_filteredInstalled, isDark, showInstallButton: true),
                          _buildPluginList(_filteredMarket, isDark, showInstallButton: true),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.textHint(isDark)),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadPlugins,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginList(List<PluginModel> plugins, bool isDark,
      {bool showInstallButton = false}) {
    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_outlined, size: 64, color: AppColors.textHint(isDark)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配插件' : '暂无插件',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlugins,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: plugins.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          return _PluginCard(
            plugin: plugin,
            isDark: isDark,
            onTap: () => context.pushNamed(
              'plugin-detail',
              queryParameters: {'pluginId': plugin.id},
            ),
            onInstall: showInstallButton ? () => _toggleInstall(plugin) : null,
          );
        },
      ),
    );
  }
}

/// 插件卡片
class _PluginCard extends StatelessWidget {
  final PluginModel plugin;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onInstall;

  const _PluginCard({
    required this.plugin,
    required this.isDark,
    required this.onTap,
    this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                image: plugin.iconUrl != null
                    ? DecorationImage(
                        image: NetworkImage(plugin.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: plugin.iconUrl == null
                  ? Icon(
                      Icons.extension,
                      color: AppColors.secondary(isDark),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plugin.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plugin.description.isNotEmpty
                        ? plugin.description
                        : '暂无描述',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (plugin.author.isNotEmpty) ...[
                        Icon(Icons.person_outline,
                            size: 12, color: AppColors.textHint(isDark)),
                        const SizedBox(width: 3),
                        Text(
                          plugin.author,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.category_outlined,
                          size: 12, color: AppColors.textHint(isDark)),
                      const SizedBox(width: 3),
                      Text(
                        plugin.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v${plugin.version}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 安装/卸载按钮
            if (onInstall != null)
              TextButton(
                onPressed: onInstall,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  plugin.isInstalled ? '卸载' : '安装',
                  style: TextStyle(
                    fontSize: 13,
                    color: plugin.isInstalled
                        ? AppColors.textSecondary(isDark)
                        : AppColors.primary(isDark),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

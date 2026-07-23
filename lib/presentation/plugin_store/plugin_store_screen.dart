import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_widgets.dart';

// ============================================================================
// 数据模型
// ============================================================================

/// 插件安装状态
enum PluginInstallStatus { notInstalled, installing, installed, needsUpdate }

/// 插件数据模型
class PluginInfo {
  final String id;
  final String name;
  final String author;
  final String description;
  final String iconEmoji;
  final Color accentColor;
  final double rating;
  final int downloadCount;
  final String version;
  final String latestVersion;
  final PluginInstallStatus installStatus;
  final double installProgress;
  final List<String> screenshots;
  final List<String> categories;
  final List<String> permissions;
  final List<VersionEntry> versionHistory;
  final List<PluginReview> reviews;
  final bool isFeatured;
  final bool isEditorPick;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.iconEmoji,
    required this.accentColor,
    this.rating = 4.5,
    this.downloadCount = 0,
    this.version = '1.0.0',
    this.latestVersion = '1.0.0',
    this.installStatus = PluginInstallStatus.notInstalled,
    this.installProgress = 0.0,
    this.screenshots = const [],
    this.categories = const [],
    this.permissions = const [],
    this.versionHistory = const [],
    this.reviews = const [],
    this.isFeatured = false,
    this.isEditorPick = false,
  });
}

/// 版本记录
class VersionEntry {
  final String version;
  final String date;
  final List<String> changes;
  const VersionEntry({required this.version, required this.date, this.changes = const []});
}

/// 用户评价
class PluginReview {
  final String userName;
  final double rating;
  final String content;
  final String date;
  const PluginReview({required this.userName, required this.rating, required this.content, required this.date});
}

// ============================================================================
// State Management
// ============================================================================

class PluginStoreState {
  final List<PluginInfo> allPlugins;
  final List<PluginInfo> filteredPlugins;
  final String searchQuery;
  final String selectedCategory;
  final int currentTab;
  final PluginInfo? selectedPlugin;
  final bool isLoading;

  const PluginStoreState({
    this.allPlugins = const [],
    this.filteredPlugins = const [],
    this.searchQuery = '',
    this.selectedCategory = '全部',
    this.currentTab = 0,
    this.selectedPlugin,
    this.isLoading = false,
  });

  PluginStoreState copyWith({
    List<PluginInfo>? allPlugins,
    List<PluginInfo>? filteredPlugins,
    String? searchQuery,
    String? selectedCategory,
    int? currentTab,
    PluginInfo? selectedPlugin,
    bool clearSelection = false,
    bool? isLoading,
  }) {
    return PluginStoreState(
      allPlugins: allPlugins ?? this.allPlugins,
      filteredPlugins: filteredPlugins ?? this.filteredPlugins,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      currentTab: currentTab ?? this.currentTab,
      selectedPlugin: clearSelection ? null : (selectedPlugin ?? this.selectedPlugin),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PluginStoreNotifier extends StateNotifier<PluginStoreState> {
  PluginStoreNotifier() : super(const PluginStoreState(isLoading: true)) {
    _loadPlugins();
  }

  void _loadPlugins() {
    Future.delayed(const Duration(milliseconds: 500), () {
      state = state.copyWith(allPlugins: _samplePlugins, filteredPlugins: _samplePlugins, isLoading: false);
    });
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query, filteredPlugins: _applyFilters(query, state.selectedCategory));
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category, filteredPlugins: _applyFilters(state.searchQuery, category));
  }

  void switchTab(int tab) {
    state = state.copyWith(currentTab: tab, clearSelection: true);
    if (tab == 1) {
      final installed = state.allPlugins
          .where((p) => p.installStatus == PluginInstallStatus.installed || p.installStatus == PluginInstallStatus.needsUpdate)
          .toList();
      state = state.copyWith(filteredPlugins: installed);
    } else {
      search(state.searchQuery);
    }
  }

  void selectPlugin(PluginInfo plugin) { state = state.copyWith(selectedPlugin: plugin); }
  void clearSelection() { state = state.copyWith(clearSelection: true); }

  Future<void> installPlugin(String pluginId) async {
    final plugins = state.allPlugins.map((p) {
      if (p.id != pluginId) return p;
      return PluginInfo(id: p.id, name: p.name, author: p.author, description: p.description,
        iconEmoji: p.iconEmoji, accentColor: p.accentColor, rating: p.rating, downloadCount: p.downloadCount,
        version: p.version, latestVersion: p.latestVersion, installStatus: PluginInstallStatus.installing,
        installProgress: 0.0, screenshots: p.screenshots, categories: p.categories, permissions: p.permissions,
        versionHistory: p.versionHistory, reviews: p.reviews, isFeatured: p.isFeatured, isEditorPick: p.isEditorPick);
    }).toList();
    state = state.copyWith(allPlugins: plugins);
    for (double i = 0; i <= 1.0; i += 0.1) {
      await Future.delayed(const Duration(milliseconds: 200));
      final updated = state.allPlugins.map((p) {
        if (p.id != pluginId) return p;
        return PluginInfo(id: p.id, name: p.name, author: p.author, description: p.description,
          iconEmoji: p.iconEmoji, accentColor: p.accentColor, rating: p.rating, downloadCount: p.downloadCount,
          version: p.version, latestVersion: p.latestVersion, installStatus: PluginInstallStatus.installing,
          installProgress: i, screenshots: p.screenshots, categories: p.categories, permissions: p.permissions,
          versionHistory: p.versionHistory, reviews: p.reviews, isFeatured: p.isFeatured, isEditorPick: p.isEditorPick);
      }).toList();
      state = state.copyWith(allPlugins: updated);
    }
    final done = state.allPlugins.map((p) {
      if (p.id != pluginId) return p;
      return PluginInfo(id: p.id, name: p.name, author: p.author, description: p.description,
        iconEmoji: p.iconEmoji, accentColor: p.accentColor, rating: p.rating, downloadCount: p.downloadCount + 1,
        version: p.version, latestVersion: p.latestVersion, installStatus: PluginInstallStatus.installed,
        installProgress: 1.0, screenshots: p.screenshots, categories: p.categories, permissions: p.permissions,
        versionHistory: p.versionHistory, reviews: p.reviews, isFeatured: p.isFeatured, isEditorPick: p.isEditorPick);
    }).toList();
    state = state.copyWith(allPlugins: done);
    search(state.searchQuery);
  }

  List<PluginInfo> _applyFilters(String query, String category) {
    var result = state.allPlugins;
    if (query.isNotEmpty) {
      result = result.where((p) => p.name.contains(query) || p.author.contains(query) || p.description.contains(query)).toList();
    }
    if (category != '全部') {
      result = result.where((p) => p.categories.contains(category)).toList();
    }
    return result;
  }

  static final List<PluginInfo> _samplePlugins = [
    PluginInfo(id: 'web_search', name: '网络搜索', author: 'XiaoSu Official',
      description: '实时搜索互联网信息，支持多种搜索引擎，自动提取关键内容并返回结构化结果。',
      iconEmoji: '🔍', accentColor: const Color(0xFF3B82F6), rating: 4.8, downloadCount: 12580,
      version: '2.3.1', latestVersion: '2.3.1', installStatus: PluginInstallStatus.installed,
      screenshots: ['搜索配置', '搜索结果', '高级选项'], categories: ['工具', '搜索'],
      permissions: ['网络访问', '内容读取'],
      versionHistory: [VersionEntry(version: '2.3.1', date: '2025-01-15', changes: ['优化搜索速度', '修复超时问题']),
        VersionEntry(version: '2.3.0', date: '2025-01-01', changes: ['新增图片搜索', '支持多语言'])],
      reviews: [PluginReview(userName: '开发者A', rating: 5.0, content: '非常好用，搜索速度快！', date: '2025-01-10'),
        PluginReview(userName: '用户B', rating: 4.0, content: '功能全面，希望增加更多搜索引擎。', date: '2025-01-08')],
      isFeatured: true, isEditorPick: true),
    PluginInfo(id: 'image_gen', name: '图片生成', author: 'Creative AI',
      description: 'AI 文生图引擎，支持多种风格（写实、动漫、油画等），高质量图片输出。',
      iconEmoji: '🎨', accentColor: const Color(0xFFE8895C), rating: 4.6, downloadCount: 8920,
      version: '1.5.0', latestVersion: '1.6.0', installStatus: PluginInstallStatus.needsUpdate,
      screenshots: ['生成示例', '风格选择', '参数配置'], categories: ['AI', '创作'],
      permissions: ['网络访问', '存储写入'],
      versionHistory: [VersionEntry(version: '1.6.0', date: '2025-01-20', changes: ['新增油画风格', '提升分辨率'])],
      reviews: [PluginReview(userName: '设计师C', rating: 5.0, content: '生成质量很高！', date: '2025-01-18')],
      isFeatured: true),
    PluginInfo(id: 'code_exec', name: '代码执行', author: 'DevTools',
      description: '沙箱环境执行 Python/JavaScript 代码，安全隔离，支持文件 I/O。',
      iconEmoji: '💻', accentColor: const Color(0xFF6C63FF), rating: 4.7, downloadCount: 6750,
      version: '3.0.2', latestVersion: '3.0.2', installStatus: PluginInstallStatus.installed,
      categories: ['开发', '工具'], permissions: ['沙箱执行', '文件系统'], isEditorPick: true),
    PluginInfo(id: 'pdf_tools', name: 'PDF 工具箱', author: 'DocMaster',
      description: 'PDF 解析、生成、合并、拆分、OCR 识别，一站式文档处理。',
      iconEmoji: '📄', accentColor: const Color(0xFFEF4444), rating: 4.3, downloadCount: 4520,
      categories: ['文档', '工具'], permissions: ['文件读写', '存储访问']),
    PluginInfo(id: 'data_analysis', name: '数据分析', author: 'DataLab',
      description: '数据清洗、统计分析、可视化图表生成，支持 CSV/Excel 导入。',
      iconEmoji: '📊', accentColor: const Color(0xFF10B981), rating: 4.5, downloadCount: 3210,
      categories: ['数据', '分析'], permissions: ['文件读取', '计算资源'], isFeatured: true),
    PluginInfo(id: 'calendar', name: '日程管理', author: 'Productivity+',
      description: '智能日程安排，支持日历同步、提醒设置、冲突检测。',
      iconEmoji: '📅', accentColor: const Color(0xFF8B5CF6), rating: 4.4, downloadCount: 2890,
      categories: ['效率', '工具'], permissions: ['日历读写', '通知推送']),
    PluginInfo(id: 'translator', name: '多语翻译', author: 'LinguaAI',
      description: '支持 50+ 语言互译，专业术语优化，上下文感知翻译。',
      iconEmoji: '🌐', accentColor: const Color(0xFF14B8A6), rating: 4.9, downloadCount: 15600,
      version: '4.0.1', latestVersion: '4.0.1', installStatus: PluginInstallStatus.installed,
      categories: ['工具', 'AI'], permissions: ['网络访问'], isEditorPick: true),
    PluginInfo(id: 'email_bot', name: '邮件助手', author: 'MailBot',
      description: '自动邮件分类、智能回复建议、重要邮件提醒。',
      iconEmoji: '📧', accentColor: const Color(0xFFF59E0B), rating: 4.2, downloadCount: 1850,
      categories: ['效率', '通讯'], permissions: ['邮件读写', '网络访问']),
  ];
}

final pluginStoreProvider = StateNotifierProvider<PluginStoreNotifier, PluginStoreState>(
  (ref) => PluginStoreNotifier(),
);

// ============================================================================
// 主界面
// ============================================================================

class PluginStoreScreen extends ConsumerStatefulWidget {
  const PluginStoreScreen({super.key});
  @override
  ConsumerState<PluginStoreScreen> createState() => _PluginStoreScreenState();
}

class _PluginStoreScreenState extends ConsumerState<PluginStoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  static const List<String> _categories = ['全部', '工具', 'AI', '开发', '文档', '数据', '效率', '创作', '通讯'];

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeState = ref.watch(pluginStoreProvider);
    final notifier = ref.read(pluginStoreProvider.notifier);
    if (storeState.selectedPlugin != null) return _buildPluginDetail(isDark, storeState, notifier);
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(children: [
          _buildSearchBar(isDark, notifier),
          _buildCategoryTabs(isDark, storeState, notifier),
          _buildPageTabs(isDark, storeState, notifier),
          Expanded(child: storeState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : storeState.currentTab == 0
              ? _buildStoreContent(isDark, storeState, notifier)
              : _buildInstalledList(isDark, storeState, notifier)),
        ]),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, PluginStoreNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(controller: _searchController, onChanged: notifier.search,
        decoration: InputDecoration(hintText: '搜索插件...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20))));
  }

  Widget _buildCategoryTabs(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    return SizedBox(height: 40,
      child: ListView.separated(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = state.selectedCategory == cat;
          return ChoiceChip(label: Text(cat, style: const TextStyle(fontSize: 12)),
            selected: selected, onSelected: (_) => notifier.selectCategory(cat),
            selectedColor: AppColors.primary(isDark).withOpacity(0.2),
            labelStyle: TextStyle(color: selected ? AppColors.primary(isDark) : AppColors.textSecondary(isDark),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            side: BorderSide(color: selected ? AppColors.primary(isDark) : isDark ? AppColors.dividerDark : AppColors.dividerLight));
        }));
  }

  Widget _buildPageTabs(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [
      _pageTab(isDark, '发现', 0, state, notifier), const SizedBox(width: 24),
      _pageTab(isDark, '已安装', 1, state, notifier), const Spacer(),
      if (state.currentTab == 1) Text('${state.filteredPlugins.length} 个插件',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark))),
    ]));
  }

  Widget _pageTab(bool isDark, String label, int index, PluginStoreState state, PluginStoreNotifier notifier) {
    final selected = state.currentTab == index;
    return InkWell(onTap: () => notifier.switchTab(index),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: selected ? AppColors.primary(isDark) : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary(isDark) : AppColors.textSecondary(isDark)))));
  }

  Widget _buildStoreContent(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
      _buildFeaturedSection(isDark, state, notifier),
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text('全部插件', style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(isDark)))),
      ...state.filteredPlugins.map((p) => _buildPluginCard(isDark, p, notifier)),
      if (state.filteredPlugins.isEmpty) Padding(padding: const EdgeInsets.all(40),
        child: Center(child: Text('没有找到匹配的插件',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint(isDark))))),
    ]);
  }

  Widget _buildFeaturedSection(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    final featured = state.allPlugins.where((p) => p.isEditorPick).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Row(children: [
        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)), const SizedBox(width: 6),
        Text('编辑精选', style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(isDark))),
      ])),
      SizedBox(height: 160, child: ListView.separated(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: featured.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _buildFeaturedCard(isDark, featured[i], notifier))),
    ]);
  }

  Widget _buildFeaturedCard(bool isDark, PluginInfo plugin, PluginStoreNotifier notifier) {
    return GestureDetector(onTap: () => notifier.selectPlugin(plugin),
      child: Container(width: 260, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [plugin.accentColor.withOpacity(0.15), plugin.accentColor.withOpacity(0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: plugin.accentColor.withOpacity(0.2), width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(
              color: plugin.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(plugin.iconEmoji, style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plugin.name, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(isDark))),
              Text(plugin.author, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark))),
            ])),
          ]),
          const SizedBox(height: 12),
          Expanded(child: Text(plugin.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
            maxLines: 3, overflow: TextOverflow.ellipsis)),
          Row(children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)), const SizedBox(width: 2),
            Text('${plugin.rating}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary(isDark))),
            const SizedBox(width: 12),
            Text('${_formatCount(plugin.downloadCount)} 下载',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint(isDark))),
          ]),
        ])));
  }

  Widget _buildPluginCard(bool isDark, PluginInfo plugin, PluginStoreNotifier notifier) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(onTap: () => notifier.selectPlugin(plugin), borderRadius: BorderRadius.circular(14),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(
              color: plugin.accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(plugin.iconEmoji, style: const TextStyle(fontSize: 26)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plugin.name, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(isDark))),
                if (plugin.isEditorPick) ...[const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text('精选', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))))],
              ]),
              const SizedBox(height: 2),
              Text(plugin.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)), const SizedBox(width: 2),
                Text('${plugin.rating}', style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark))),
                const SizedBox(width: 8),
                Text('${_formatCount(plugin.downloadCount)} 下载', style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark))),
                const SizedBox(width: 8),
                Text('v${plugin.version}', style: TextStyle(fontSize: 11, color: AppColors.textHint(isDark))),
              ]),
              if (plugin.installStatus == PluginInstallStatus.installing) Padding(padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: plugin.installProgress,
                    backgroundColor: isDark ? AppColors.surfaceVariantLight : AppColors.surfaceVariantLight,
                    valueColor: AlwaysStoppedAnimation(plugin.accentColor), minHeight: 3))),
            ])),
            const SizedBox(width: 12),
            _buildInstallButton(isDark, plugin, notifier),
          ])))));
  }

  Widget _buildInstallButton(bool isDark, PluginInfo plugin, PluginStoreNotifier notifier) {
    switch (plugin.installStatus) {
      case PluginInstallStatus.notInstalled:
        return FilledButton.tonal(onPressed: () => notifier.installPlugin(plugin.id),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), minimumSize: const Size(60, 32)),
          child: const Text('安装', style: TextStyle(fontSize: 12)));
      case PluginInstallStatus.installing:
        return SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2,
          value: plugin.installProgress, color: plugin.accentColor));
      case PluginInstallStatus.installed:
        return BadgeWidget(text: '已安装', color: AppColors.successLight.withOpacity(0.1), textColor: AppColors.successLight);
      case PluginInstallStatus.needsUpdate:
        return FilledButton(onPressed: () => notifier.installPlugin(plugin.id),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), minimumSize: const Size(60, 32)),
          child: const Text('更新', style: TextStyle(fontSize: 12)));
    }
  }

  Widget _buildInstalledList(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    if (state.filteredPlugins.isEmpty) return const EmptyStateView(
      icon: Icons.extension_outlined, title: '暂无已安装插件', subtitle: '去发现页安装一些插件吧');
    return ListView.builder(padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: state.filteredPlugins.length,
      itemBuilder: (_, i) => _buildPluginCard(isDark, state.filteredPlugins[i], notifier));
  }

  Widget _buildPluginDetail(bool isDark, PluginStoreState state, PluginStoreNotifier notifier) {
    final plugin = state.selectedPlugin!;
    return Scaffold(backgroundColor: AppColors.background(isDark),
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverAppBar(pinned: true, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: notifier.clearSelection),
          title: Text(plugin.name), actions: [IconButton(icon: const Icon(Icons.share_rounded), onPressed: () {})]),
        SliverToBoxAdapter(child: _buildDetailHeader(isDark, plugin, notifier)),
        if (plugin.screenshots.isNotEmpty) SliverToBoxAdapter(child: _buildScreenshotsSection(isDark, plugin)),
        SliverToBoxAdapter(child: _buildDescriptionSection(isDark, plugin)),
        if (plugin.permissions.isNotEmpty) SliverToBoxAdapter(child: _buildPermissionsSection(isDark, plugin)),
        if (plugin.versionHistory.isNotEmpty) SliverToBoxAdapter(child: _buildVersionHistorySection(isDark, plugin)),
        if (plugin.reviews.isNotEmpty) SliverToBoxAdapter(child: _buildReviewsSection(isDark, plugin)),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ])));
  }

  Widget _buildDetailHeader(bool isDark, PluginInfo plugin, PluginStoreNotifier notifier) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(
          color: plugin.accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(plugin.iconEmoji, style: const TextStyle(fontSize: 34)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plugin.name, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 2),
          Text(plugin.author, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary(isDark))),
          const SizedBox(height: 4),
          Text('v${plugin.version} · ${_formatCount(plugin.downloadCount)} 下载',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark))),
        ])),
        _buildInstallButton(isDark, plugin, notifier),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildStatItem(isDark, '评分', '${plugin.rating}', Icons.star_rounded, const Color(0xFFF59E0B)),
        _buildStatItem(isDark, '下载', _formatCount(plugin.downloadCount), Icons.download_rounded, AppColors.infoLight),
        _buildStatItem(isDark, '版本', plugin.version, Icons.tag_rounded, AppColors.secondaryLight),
      ]),
    ]));
  }

  Widget _buildStatItem(bool isDark, String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, size: 20, color: color), const SizedBox(height: 4),
      Text(value, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(isDark))),
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark))),
    ]);
  }

  Widget _buildScreenshotsSection(bool isDark, PluginInfo plugin) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text('截图预览', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(isDark)))),
      SizedBox(height: 160, child: ListView.separated(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: plugin.screenshots.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Container(width: 240,
          decoration: BoxDecoration(color: plugin.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight, width: 0.5)),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_rounded, size: 32, color: plugin.accentColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(plugin.screenshots[i], style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark))),
          ]))))),
    ]);
  }

  Widget _buildDescriptionSection(bool isDark, PluginInfo plugin) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('功能描述', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(isDark))),
      const SizedBox(height: 8),
      Text(plugin.description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary(isDark), height: 1.6)),
    ]));
  }

  Widget _buildPermissionsSection(bool isDark, PluginInfo plugin) {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('权限说明', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(isDark))),
      const SizedBox(height: 8),
      ...plugin.permissions.map((perm) => Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [Icon(Icons.shield_outlined, size: 16, color: AppColors.warningLight),
          const SizedBox(width: 8),
          Text(perm, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(isDark)))]))),
    ]));
  }

  Widget _buildVersionHistorySection(bool isDark, PluginInfo plugin) {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('版本历史', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(isDark))),
      const SizedBox(height: 8),
      ...plugin.versionHistory.map((v) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceVariantLight : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('v${v.version}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary(isDark))),
            const SizedBox(width: 8),
            Text(v.date, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint(isDark)))]),
          const SizedBox(height: 6),
          ...v.changes.map((c) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: AppColors.textHint(isDark), fontSize: 12)),
              Expanded(child: Text(c, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(isDark)))),
            ]))),
        ]))),
    ]));
  }

  Widget _buildReviewsSection(bool isDark, PluginInfo plugin) {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('用户评价', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(isDark))),
      const SizedBox(height: 8),
      ...plugin.reviews.map((r) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceVariantLight : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 12, backgroundColor: AppColors.primary(isDark).withOpacity(0.2),
              child: Text(r.userName[0], style: TextStyle(fontSize: 12, color: AppColors.primary(isDark)))),
            const SizedBox(width: 8),
            Text(r.userName, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary(isDark))),
            const Spacer(),
            Row(children: List.generate(5, (i) => Icon(
              i < r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 12, color: const Color(0xFFF59E0B)))),
          ]),
          const SizedBox(height: 6),
          Text(r.content, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 4),
          Text(r.date, style: TextStyle(fontSize: 10, color: AppColors.textHint(isDark))),
        ]))),
    ]));
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

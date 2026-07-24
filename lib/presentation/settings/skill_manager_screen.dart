import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';

/// 技能管理界面
/// 展示已安装技能列表、技能详情、启用/禁用、安装新技能入口
class SkillManagerScreen extends ConsumerStatefulWidget {
  const SkillManagerScreen({super.key});

  @override
  ConsumerState<SkillManagerScreen> createState() =>
      _SkillManagerScreenState();
}

class _SkillManagerScreenState extends ConsumerState<SkillManagerScreen> {
  /// 已安装技能列表
  final List<_SkillInfo> _skills = [
    _SkillInfo(
      id: 'web_search',
      name: '网络搜索',
      description: '联网搜索互联网上的实时信息，支持多种搜索引擎',
      version: '1.2.0',
      icon: Icons.search_rounded,
      color: AppColors.infoLight,
      tools: ['search_web', 'fetch_page'],
      isEnabled: true,
    ),
    _SkillInfo(
      id: 'image_gen',
      name: '图片生成',
      description: '通过文字描述生成高质量图片，支持多种风格和尺寸',
      version: '2.0.1',
      icon: Icons.image_rounded,
      color: AppColors.primaryLight,
      tools: ['generate_image', 'edit_image'],
      isEnabled: true,
    ),
    _SkillInfo(
      id: 'code_executor',
      name: '代码执行',
      description: '在沙箱环境中执行代码，支持 Python、JavaScript 等',
      version: '1.5.0',
      icon: Icons.code_rounded,
      color: AppColors.secondaryLight,
      tools: ['execute_code', 'run_shell'],
      isEnabled: true,
    ),
    _SkillInfo(
      id: 'file_manager',
      name: '文件管理',
      description: '读写文件、处理文档、转换格式等文件操作能力',
      version: '1.1.0',
      icon: Icons.folder_rounded,
      color: AppColors.warningLight,
      tools: ['read_file', 'write_file', 'convert_format'],
      isEnabled: true,
    ),
    _SkillInfo(
      id: 'data_analysis',
      name: '数据分析',
      description: '数据清洗、统计分析、可视化图表生成',
      version: '1.0.0',
      icon: Icons.analytics_rounded,
      color: AppColors.successLight,
      tools: ['analyze_data', 'create_chart', 'export_report'],
      isEnabled: false,
    ),
  ];

  /// 当前展开详情的技能 ID
  String? _expandedSkillId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledCount = _skills.where((s) => s.isEnabled).length;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('技能管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 安装新技能按钮
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () {
                _showInstallSheet(context, isDark);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('安装'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary(isDark),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 统计信息
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '已安装',
                    '${_skills.length}',
                    isDark: true,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    '已启用',
                    '$enabledCount',
                    isDark: true,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    '工具数',
                    '${_skills.fold<int>(0, (sum, s) => sum + s.tools.length)}',
                    isDark: true,
                  ),
                ),
              ],
            ),
          ),

          // 技能列表
          ..._skills.map((skill) {
            return _buildSkillCard(context, skill, isDark);
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value,
      {required bool isDark}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 构建技能卡片
  Widget _buildSkillCard(
    BuildContext context,
    _SkillInfo skill,
    bool isDark,
  ) {
    final isExpanded = _expandedSkillId == skill.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // 技能概要行
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedSkillId = isExpanded ? null : skill.id;
                });
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 技能图标
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: skill.isEnabled
                            ? skill.color.withOpacity(0.12)
                            : AppColors.textHint(isDark).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        skill.icon,
                        color: skill.isEnabled
                            ? skill.color
                            : AppColors.textHint(isDark),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 技能信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                skill.name,
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: skill.isEnabled
                                      ? AppColors.textPrimary(isDark)
                                      : AppColors.textSecondary(isDark),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant(isDark: isDark),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: Text(
                                  'v${skill.version}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textHint(isDark),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            skill.description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 启用/禁用开关
                    Switch(
                      value: skill.isEnabled,
                      onChanged: (value) {
                        setState(() => skill.isEnabled = value);
                      },
                      activeColor: skill.color,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 展开的详情区
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  // 描述
                  Text(
                    skill.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary(isDark),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 提供的工具
                  Text(
                    '提供的工具',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skill.tools.map((tool) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: skill.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: skill.color.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.build_rounded,
                              size: 12,
                              color: skill.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tool,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: skill.color,
                                fontSize: 11,
                                fontFamily: 'JetBrains Mono, monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 操作按钮
                  Row(
                    children: [
                      // 配置
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: 技能配置
                          },
                          icon: const Icon(Icons.settings_rounded, size: 16),
                          label: const Text('配置'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 更新
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showSnackBar('检查更新中...');
                          },
                          icon: const Icon(Icons.update_rounded, size: 16),
                          label: const Text('检查更新'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 显示安装技能面板
  void _showInstallSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖拽条
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '技能商店',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStoreItem(
                        context,
                        name: '高级搜索',
                        desc: '支持 Google、Bing 等多引擎搜索',
                        icon: Icons.travel_explore_rounded,
                        color: AppColors.infoLight,
                        isDark: isDark,
                      ),
                      _buildStoreItem(
                        context,
                        name: 'PDF 处理',
                        desc: 'PDF 解析、生成、合并、拆分',
                        icon: Icons.picture_as_pdf_rounded,
                        color: AppColors.errorLight,
                        isDark: isDark,
                      ),
                      _buildStoreItem(
                        context,
                        name: '表格处理',
                        desc: 'Excel 读写、数据分析、图表生成',
                        icon: Icons.table_chart_rounded,
                        color: AppColors.successLight,
                        isDark: isDark,
                      ),
                      _buildStoreItem(
                        context,
                        name: '语音合成',
                        desc: '文字转语音，支持多种音色',
                        icon: Icons.record_voice_over_rounded,
                        color: AppColors.secondaryLight,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建商店项
  Widget _buildStoreItem(
    BuildContext context, {
    required String name,
    required String desc,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              _showSnackBar('安装中...');
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text('安装', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// 显示 SnackBar
  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// 技能信息数据
class _SkillInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final IconData icon;
  final Color color;
  final List<String> tools;
  bool isEnabled;

  _SkillInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.icon,
    required this.color,
    required this.tools,
    this.isEnabled = true,
  });
}

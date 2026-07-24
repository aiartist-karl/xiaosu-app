import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_widgets.dart';

// ============================================================================
// 数据模型
// ============================================================================

/// 资源使用数据点
class MetricDataPoint {
  final DateTime timestamp;
  final double value;
  const MetricDataPoint({required this.timestamp, required this.value});
}

/// 系统资源指标
class SystemMetrics {
  final List<MetricDataPoint> cpuHistory;
  final List<MetricDataPoint> memoryHistory;
  final List<MetricDataPoint> diskHistory;
  final double cpuUsage;
  final double memoryUsage;
  final double memoryTotalGB;
  final double diskUsage;
  final double diskTotalGB;

  const SystemMetrics({
    this.cpuHistory = const [],
    this.memoryHistory = const [],
    this.diskHistory = const [],
    this.cpuUsage = 0,
    this.memoryUsage = 0,
    this.memoryTotalGB = 16,
    this.diskUsage = 0,
    this.diskTotalGB = 512,
  });
}

/// LLM 性能数据
class LlmPerformance {
  final List<MetricDataPoint> latencyHistory;
  final List<MetricDataPoint> tokensPerSecHistory;
  final double avgLatencyMs;
  final double avgTokensPerSec;
  final String currentModel;
  final Map<String, double> modelLatencies;

  const LlmPerformance({
    this.latencyHistory = const [],
    this.tokensPerSecHistory = const [],
    this.avgLatencyMs = 0,
    this.avgTokensPerSec = 0,
    this.currentModel = 'GPT-4o',
    this.modelLatencies = const {},
  });
}

/// 技能执行统计
class SkillExecutionStats {
  final Map<String, double> usageShare;
  final Map<String, double> executionTimeRanking;
  final Map<String, double> successRates;

  const SkillExecutionStats({
    this.usageShare = const {},
    this.executionTimeRanking = const {},
    this.successRates = const {},
  });
}

/// 网络监控数据
class NetworkStats {
  final int totalApiCalls;
  final int dailyApiCalls;
  final double bandwidthMB;
  final double cacheHitRate;
  final List<MetricDataPoint> apiCallHistory;

  const NetworkStats({
    this.totalApiCalls = 0,
    this.dailyApiCalls = 0,
    this.bandwidthMB = 0,
    this.cacheHitRate = 0,
    this.apiCallHistory = const [],
  });
}

/// 安全事件
class SecurityEvent {
  final DateTime timestamp;
  final String title;
  final String description;
  final SecuritySeverity severity;
  final bool isResolved;

  const SecurityEvent({
    required this.timestamp,
    required this.title,
    required this.description,
    required this.severity,
    this.isResolved = false,
  });
}

enum SecuritySeverity { low, medium, high, critical }

/// 性能评分
class PerformanceScore {
  final int overallScore;
  final int cpuScore;
  final int memoryScore;
  final int networkScore;
  final List<String> suggestions;

  const PerformanceScore({
    this.overallScore = 0,
    this.cpuScore = 0,
    this.memoryScore = 0,
    this.networkScore = 0,
    this.suggestions = const [],
  });
}

// ============================================================================
// State Management
// ============================================================================

class MonitorDashboardState {
  final SystemMetrics systemMetrics;
  final LlmPerformance llmPerformance;
  final SkillExecutionStats skillStats;
  final NetworkStats networkStats;
  final List<SecurityEvent> securityEvents;
  final PerformanceScore performanceScore;
  final bool isMonitoring;
  final int selectedTab;

  const MonitorDashboardState({
    this.systemMetrics = const SystemMetrics(),
    this.llmPerformance = const LlmPerformance(),
    this.skillStats = const SkillExecutionStats(),
    this.networkStats = const NetworkStats(),
    this.securityEvents = const [],
    this.performanceScore = const PerformanceScore(),
    this.isMonitoring = true,
    this.selectedTab = 0,
  });

  MonitorDashboardState copyWith({
    SystemMetrics? systemMetrics,
    LlmPerformance? llmPerformance,
    SkillExecutionStats? skillStats,
    NetworkStats? networkStats,
    List<SecurityEvent>? securityEvents,
    PerformanceScore? performanceScore,
    bool? isMonitoring,
    int? selectedTab,
  }) {
    return MonitorDashboardState(
      systemMetrics: systemMetrics ?? this.systemMetrics,
      llmPerformance: llmPerformance ?? this.llmPerformance,
      skillStats: skillStats ?? this.skillStats,
      networkStats: networkStats ?? this.networkStats,
      securityEvents: securityEvents ?? this.securityEvents,
      performanceScore: performanceScore ?? this.performanceScore,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

class MonitorDashboardNotifier extends StateNotifier<MonitorDashboardState> {
  Timer? _updateTimer;

  MonitorDashboardNotifier() : super(const MonitorDashboardState()) {
    _initializeData();
    _startMonitoring();
  }

  void _initializeData() {
    final now = DateTime.now();
    final cpuHistory = List.generate(60, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(seconds: 59 - i)),
      value: 20 + math.Random().nextDouble() * 40,
    ));
    final memHistory = List.generate(60, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(seconds: 59 - i)),
      value: 45 + math.Random().nextDouble() * 15,
    ));
    final diskHistory = List.generate(60, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(seconds: 59 - i)),
      value: 62 + math.Random().nextDouble() * 5,
    ));
    final latencyHistory = List.generate(30, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(seconds: 29 - i)),
      value: 800 + math.Random().nextDouble() * 600,
    ));
    final tpsHistory = List.generate(30, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(seconds: 29 - i)),
      value: 15 + math.Random().nextDouble() * 25,
    ));
    final apiHistory = List.generate(24, (i) => MetricDataPoint(
      timestamp: now.subtract(Duration(hours: 23 - i)),
      value: 50 + math.Random().nextDouble() * 150,
    ));

    state = state.copyWith(
      systemMetrics: SystemMetrics(
        cpuHistory: cpuHistory, memoryHistory: memHistory,
        diskHistory: diskHistory,
        cpuUsage: cpuHistory.last.value,
        memoryUsage: memHistory.last.value,
        memoryTotalGB: 16,
        diskUsage: diskHistory.last.value,
        diskTotalGB: 512,
      ),
      llmPerformance: LlmPerformance(
        latencyHistory: latencyHistory, tokensPerSecHistory: tpsHistory,
        avgLatencyMs: latencyHistory.map((p) => p.value).reduce((a, b) => a + b) / latencyHistory.length,
        avgTokensPerSec: tpsHistory.map((p) => p.value).reduce((a, b) => a + b) / tpsHistory.length,
        modelLatencies: {'GPT-4o': 850.0, 'Claude 3.5': 920.0, 'Qwen-Max': 680.0},
      ),
      skillStats: SkillExecutionStats(
        usageShare: {'网络搜索': 28, '图片生成': 18, '代码执行': 22, '翻译': 15, '数据分析': 17},
        executionTimeRanking: {'网络搜索': 2.3, '图片生成': 8.5, '代码执行': 1.2, '翻译': 0.8, '数据分析': 4.1},
        successRates: {'网络搜索': 98.2, '图片生成': 95.6, '代码执行': 99.1, '翻译': 99.5, '数据分析': 97.8},
      ),
      networkStats: NetworkStats(
        totalApiCalls: 12458, dailyApiCalls: 342,
        bandwidthMB: 256.8, cacheHitRate: 72.5,
        apiCallHistory: apiHistory,
      ),
      securityEvents: [
        SecurityEvent(timestamp: now.subtract(const Duration(minutes: 5)),
          title: '异常 API 调用频率', description: '检测到某 API Key 请求频率超过阈值',
          severity: SecuritySeverity.medium, isResolved: false),
        SecurityEvent(timestamp: now.subtract(const Duration(hours: 2)),
          title: '凭证更新', description: 'API Key 已成功轮换',
          severity: SecuritySeverity.low, isResolved: true),
        SecurityEvent(timestamp: now.subtract(const Duration(hours: 8)),
          title: '未授权访问尝试', description: '来自 IP 192.168.1.105 的未授权请求被拦截',
          severity: SecuritySeverity.high, isResolved: true),
      ],
      performanceScore: PerformanceScore(
        overallScore: 82, cpuScore: 78, memoryScore: 85,
        networkScore: 83,
        suggestions: [
          '建议清理缓存以释放 320MB 内存空间',
          '图片生成插件可启用 GPU 加速提升 40% 性能',
          '建议将非活跃对话归档以减少内存占用',
        ],
      ),
    );
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!state.isMonitoring) return;
      final now = DateTime.now();
      final rng = math.Random();
      final cpu = (state.systemMetrics.cpuUsage + (rng.nextDouble() - 0.5) * 8)
        .clamp(5.0, 95.0);
      final mem = (state.systemMetrics.memoryUsage + (rng.nextDouble() - 0.5) * 2)
        .clamp(30.0, 90.0);

      final cpuHistory = [...state.systemMetrics.cpuHistory.skip(1),
        MetricDataPoint(timestamp: now, value: cpu)];
      final memHistory = [...state.systemMetrics.memoryHistory.skip(1),
        MetricDataPoint(timestamp: now, value: mem)];

      state = state.copyWith(
        systemMetrics: SystemMetrics(
          cpuHistory: cpuHistory,
          memoryHistory: memHistory,
          diskHistory: state.systemMetrics.diskHistory,
          cpuUsage: cpu,
          memoryUsage: mem,
          memoryTotalGB: state.systemMetrics.memoryTotalGB,
          diskUsage: state.systemMetrics.diskUsage,
          diskTotalGB: state.systemMetrics.diskTotalGB,
        ),
      );
    });
  }

  void toggleMonitoring() {
    state = state.copyWith(isMonitoring: !state.isMonitoring);
  }

  void switchTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

final monitorDashboardProvider =
    StateNotifierProvider<MonitorDashboardNotifier, MonitorDashboardState>(
  (ref) => MonitorDashboardNotifier(),
);

// ============================================================================
// 主界面
// ============================================================================

class MonitorDashboard extends ConsumerStatefulWidget {
  const MonitorDashboard({super.key});

  @override
  ConsumerState<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends ConsumerState<MonitorDashboard>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(monitorDashboardProvider);
    final notifier = ref.read(monitorDashboardProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, state, notifier),
            _buildTabBar(isDark, state, notifier),
            Expanded(
              child: IndexedStack(
                index: state.selectedTab,
                children: [
                  _buildSystemTab(isDark, state),
                  _buildLlmTab(isDark, state),
                  _buildSkillTab(isDark, state),
                  _buildNetworkTab(isDark, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 顶部 Header ───
  Widget _buildHeader(
    bool isDark, MonitorDashboardState state, MonitorDashboardNotifier notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('系统监控', style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.textPrimary(isDark))),
              const SizedBox(height: 2),
              Text('实时性能监控与分析',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary(isDark))),
            ],
          ),
          const Spacer(),
          // 性能评分
          _buildScoreBadge(isDark, state.performanceScore.overallScore),
          const SizedBox(width: 12),
          // 监控开关
          GestureDetector(
            onTap: notifier.toggleMonitoring,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: state.isMonitoring
                    ? AppColors.successLight.withOpacity(0.12)
                    : AppColors.surfaceVariant(isDark: isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: state.isMonitoring
                        ? AppColors.successLight : AppColors.textHint(isDark),
                      shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(state.isMonitoring ? '监控中' : '已暂停',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: state.isMonitoring
                        ? AppColors.successLight : AppColors.textSecondary(isDark))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(bool isDark, int score) {
    final color = score >= 80 ? AppColors.successLight
        : score >= 60 ? AppColors.warningLight : AppColors.errorLight;
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$score', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text('分', style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }

  // ─── Tab Bar ───
  Widget _buildTabBar(
    bool isDark, MonitorDashboardState state, MonitorDashboardNotifier notifier) {
    const tabs = ['系统资源', 'LLM 性能', '技能统计', '网络监控'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = state.selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => notifier.switchTab(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                    ? AppColors.primary(isDark).withOpacity(0.1)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                      ? AppColors.primary(isDark).withOpacity(0.3)
                      : isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    width: 0.5),
                ),
                child: Center(
                  child: Text(tabs[i], style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                      ? AppColors.primary(isDark)
                      : AppColors.textSecondary(isDark),
                  )),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── 系统资源 Tab ───
  Widget _buildSystemTab(bool isDark, MonitorDashboardState state) {
    final m = state.systemMetrics;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // CPU / Memory / Disk 指标卡
          Row(
            children: [
              Expanded(child: _buildMetricCard(isDark, 'CPU', m.cpuUsage,
                '${m.cpuUsage.toStringAsFixed(1)}%', Colors.orange,
                icon: Icons.memory_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(isDark, '内存', m.memoryUsage,
                '${m.memoryUsage.toStringAsFixed(1)}% / ${m.memoryTotalGB}GB',
                Colors.blue, icon: Icons.storage_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(isDark, '磁盘', m.diskUsage,
                '${m.diskUsage.toStringAsFixed(1)}% / ${m.diskTotalGB}GB',
                Colors.purple, icon: Icons.disk_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          // CPU 图表
          _buildChartCard(isDark, 'CPU 使用率', m.cpuHistory, Colors.orange, '60s'),
          const SizedBox(height: 16),
          // 内存图表
          _buildChartCard(isDark, '内存使用率', m.memoryHistory, Colors.blue, '60s'),
          const SizedBox(height: 16),
          // 磁盘图表
          _buildChartCard(isDark, '磁盘 I/O', m.diskHistory, Colors.purple, '60s'),
          // 性能建议
          const SizedBox(height: 16),
          _buildSuggestionsCard(isDark, state.performanceScore),
        ],
      ),
    );
  }

  Widget _buildMetricCard(bool isDark, String title, double value,
      String subtitle, Color color, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary(isDark))),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(bool isDark, String title,
      List<MetricDataPoint> data, Color color, String timeRange) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary(isDark))),
              const Spacer(),
              Text(timeRange, style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                data: data, color: color, isDark: isDark,
                fillOpacity: 0.08),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最低: ${data.isEmpty ? "-" : data.map((d) => d.value).reduce(math.min).toStringAsFixed(1)}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint(isDark))),
              Text('最高: ${data.isEmpty ? "-" : data.map((d) => d.value).reduce(math.max).toStringAsFixed(1)}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint(isDark))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(bool isDark, PerformanceScore score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded, size: 18,
                color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text('优化建议', style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          ...score.suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4, height: 4, margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary(isDark), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary(isDark)))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── LLM 性能 Tab ───
  Widget _buildLlmTab(bool isDark, MonitorDashboardState state) {
    final llm = state.llmPerformance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildLlmStatCard(isDark, '平均延迟',
                '${llm.avgLatencyMs.toStringAsFixed(0)}ms', Icons.timer_rounded,
                AppColors.warningLight)),
              const SizedBox(width: 12),
              Expanded(child: _buildLlmStatCard(isDark, 'Tokens/s',
                llm.avgTokensPerSec.toStringAsFixed(1), Icons.speed_rounded,
                AppColors.successLight)),
            ],
          ),
          const SizedBox(height: 16),
          // 延迟分布
          _buildChartCard(isDark, '延迟分布 (ms)', llm.latencyHistory,
            AppColors.warningLight, '60s'),
          const SizedBox(height: 16),
          // Tokens/s 曲线
          _buildChartCard(isDark, 'Tokens/s 吞吐量', llm.tokensPerSecHistory,
            AppColors.successLight, '60s'),
          const SizedBox(height: 16),
          // 模型对比
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模型延迟对比', style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 12),
                ...llm.modelLatencies.entries.map((e) {
                  final maxLat = llm.modelLatencies.values.reduce(math.max);
                  final ratio = e.value / maxLat;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary(isDark))),
                            Text('${e.value.toStringAsFixed(0)}ms',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary(isDark))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariantLight,
                            valueColor: AlwaysStoppedAnimation(
                              e.key == llm.currentModel
                                ? AppColors.primary(isDark)
                                : AppColors.textHint(isDark).withOpacity(0.4)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLlmStatCard(bool isDark, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint(isDark))),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary(isDark))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 技能统计 Tab ───
  Widget _buildSkillTab(bool isDark, MonitorDashboardState state) {
    final stats = state.skillStats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 使用占比饼图
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('技能使用占比', style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _PieChartPainter(
                            data: stats.usageShare.values.toList(),
                            colors: _pieColors,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: stats.usageShare.entries.toList().asMap().entries.map((e) {
                            final idx = e.key;
                            final entry = e.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: _pieColors[idx % _pieColors.length],
                                      borderRadius: BorderRadius.circular(2)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${entry.key} ${entry.value.toStringAsFixed(0)}%',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary(isDark))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 执行时间排行
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('执行时间排行 (秒)', style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 12),
                ...(() {
                  final sorted = stats.executionTimeRanking.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final maxTime = sorted.first.value;
                  return sorted.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(width: 70, child: Text(e.key,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textPrimary(isDark)),
                            overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: e.value / maxTime,
                                backgroundColor: isDark
                                  ? AppColors.surfaceVariantDark
                                  : AppColors.surfaceVariantLight,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.secondaryLight.withOpacity(0.7)),
                                minHeight: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 40, child: Text('${e.value}s',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textHint(isDark)),
                            textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  });
                })(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 成功率列表
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成功率', style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 12),
                ...stats.successRates.entries.map((e) {
                  final color = e.value >= 98 ? AppColors.successLight
                    : e.value >= 95 ? AppColors.warningLight
                    : AppColors.errorLight;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 80, child: Text(e.key,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary(isDark)))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: e.value / 100,
                              backgroundColor: color.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.value}%', style: AppTextStyles.labelSmall
                          .copyWith(color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 网络监控 Tab ───
  Widget _buildNetworkTab(bool isDark, MonitorDashboardState state) {
    final net = state.networkStats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 网络指标卡
          Row(
            children: [
              Expanded(child: _buildNetworkCard(isDark, '总 API 调用',
                _formatNumber(net.totalApiCalls), Icons.api_rounded,
                AppColors.primary(isDark))),
              const SizedBox(width: 12),
              Expanded(child: _buildNetworkCard(isDark, '今日调用',
                '${net.dailyApiCalls}', Icons.today_rounded,
                AppColors.infoLight)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildNetworkCard(isDark, '流量消耗',
                '${net.bandwidthMB} MB', Icons.data_usage_rounded,
                AppColors.secondaryLight)),
              const SizedBox(width: 12),
              Expanded(child: _buildNetworkCard(isDark, '缓存命中率',
                '${net.cacheHitRate}%', Icons.cached_rounded,
                AppColors.successLight)),
            ],
          ),
          const SizedBox(height: 16),
          // API 调用量趋势
          _buildChartCard(isDark, 'API 调用量 (24h)', net.apiCallHistory,
            AppColors.primary(isDark), '24h'),
          const SizedBox(height: 16),
          // 安全事件
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security_rounded, size: 18,
                      color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text('安全事件', style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.textPrimary(isDark))),
                  ],
                ),
                const SizedBox(height: 12),
                ...state.securityEvents.map((event) {
                  final sevColor = switch (event.severity) {
                    SecuritySeverity.low => AppColors.infoLight,
                    SecuritySeverity.medium => AppColors.warningLight,
                    SecuritySeverity.high => const Color(0xFFEF4444),
                    SecuritySeverity.critical => const Color(0xFFDC2626),
                  };
                  final sevLabel = switch (event.severity) {
                    SecuritySeverity.low => '低',
                    SecuritySeverity.medium => '中',
                    SecuritySeverity.high => '高',
                    SecuritySeverity.critical => '严重',
                  };
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sevColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sevColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(sevLabel, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: sevColor)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.textPrimary(isDark))),
                              const SizedBox(height: 2),
                              Text(event.description,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint(isDark))),
                              Text(_timeAgo(event.timestamp),
                                style: TextStyle(fontSize: 10,
                                  color: AppColors.textHint(isDark))),
                            ],
                          ),
                        ),
                        if (event.isResolved)
                          BadgeWidget(text: '已解决',
                            color: AppColors.successLight.withOpacity(0.1),
                            textColor: AppColors.successLight),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(bool isDark, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 2),
          Text(title, style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint(isDark))),
        ],
      ),
    );
  }

  // ─── 工具方法 ───
  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  String _formatNumber(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// 饼图颜色
const _pieColors = [
  Color(0xFFE8895C), Color(0xFF6C63FF), Color(0xFF10B981),
  Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEC4899),
];

// ============================================================================
// Custom Painters
// ============================================================================

class _LineChartPainter extends CustomPainter {
  final List<MetricDataPoint> data;
  final Color color;
  final bool isDark;
  final double fillOpacity;

  _LineChartPainter({
    required this.data,
    required this.color,
    required this.isDark,
    this.fillOpacity = 0.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final values = data.map((d) => d.value).toList();
    final minV = values.reduce(math.min) * 0.9;
    final maxV = values.reduce(math.max) * 1.1;
    final range = maxV - minV;
    if (range == 0) return;

    final dx = size.width / (data.length - 1);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // 填充
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()
      ..color = color.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}

class _PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  final bool isDark;

  _PieChartPainter({
    required this.data,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.reduce((a, b) => a + b);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < data.length; i++) {
      final sweep = (data[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    // 中心空白
    canvas.drawCircle(center, radius * 0.5, Paint()
      ..color = isDark ? const Color(0xFF1A1D27) : Colors.white
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) => true;
}



// ============================================================================
// 小酥 AI 助手 - P1 技能注册中心 (P1SkillRegistry)
// ============================================================================
// 集中注册所有 P1 级别的外部能力技能
// 负责技能实例化、依赖检查、初始化顺序控制、状态监控
// ============================================================================

import 'dart:async';

import '../core/skill/skill.dart';
import 'cloud_sync/cloud_sync_skill.dart';

// ============================================================================
// P1 技能导入
// ============================================================================
// EmailSkill — 邮件收发技能
import '../skills/email/email_skill.dart';

// DocGenSkill — 文档生成技能（PDF / Word / PPT）
import '../skills/doc_gen/doc_gen_skill.dart';

// SocialMediaSkill — 社交媒体运营技能（小红书/微博等）
import '../skills/social/social_media_skill.dart';

// VideoGenSkill — 视频生成技能
import '../skills/video/video_gen_skill.dart';

// PodcastSkill — 播客生成技能
import '../skills/podcast/podcast_skill.dart';

// BrowserSkill — 浏览器自动化技能
import '../skills/browser/browser_skill.dart';

// LarkSkill — 飞书集成技能
import '../skills/lark/lark_skill.dart';

// TopicTrackingSkill — 话题追踪技能
import '../skills/tracking/topic_tracking_skill.dart';

// ProDomainSkill — 专业域名/知识付费技能
import '../skills/pro_domain/pro_domain_skill.dart';

// ForbiddenWordSkill — 多平台违禁词检测技能
import '../skills/forbidden_word/forbidden_word_skill.dart';

// ChartSkill — 数据图表生成技能
import '../skills/chart/chart_skill.dart';

// ============================================================================
// 技能依赖图
// ============================================================================

/// 技能依赖声明
/// key = 技能 ID，value = 该技能依赖的其他技能 ID 列表
const Map<String, List<String>> _p1DependencyGraph = {
  'email': [],
  'doc_gen': [],
  'social_media': ['image_gen'],
  'video_gen': ['image_gen'],
  'podcast': [],
  'browser': ['web_search'],
  'lark': ['email'],
  'topic_tracking': ['web_search'],
  'pro_domain': ['web_search'],
  'forbidden_word': [],
  'chart': [],
  'cloud_sync': [],
};

/// 技能初始化优先级
/// 数字越小越先初始化
const Map<String, int> _p1InitPriority = {
  'cloud_sync': 10,
  'forbidden_word': 10,
  'chart': 10,
  'email': 20,
  'doc_gen': 20,
  'podcast': 20,
  'browser': 30,
  'web_search': 30, // P0 但作为 P1 依赖需要提前就绪
  'lark': 40,
  'topic_tracking': 50,
  'pro_domain': 50,
  'social_media': 60,
  'video_gen': 60,
};

/// P1 技能健康检查状态
class P1SkillHealthStatus {
  final String skillId;
  final String skillName;
  final SkillStatus status;
  final bool dependencySatisfied;
  final List<String> missingDependencies;
  final String? errorMessage;
  final int toolCount;
  final Duration? initDuration;

  const P1SkillHealthStatus({
    required this.skillId,
    required this.skillName,
    required this.status,
    this.dependencySatisfied = true,
    this.missingDependencies = const [],
    this.errorMessage,
    this.toolCount = 0,
    this.initDuration,
  });

  Map<String, dynamic> toJson() => {
        'skill_id': skillId,
        'skill_name': skillName,
        'status': status.value,
        'dependency_satisfied': dependencySatisfied,
        'missing_dependencies': missingDependencies,
        if (errorMessage != null) 'error_message': errorMessage,
        'tool_count': toolCount,
        if (initDuration != null) 'init_duration_ms': initDuration!.inMilliseconds,
      };
}

// ============================================================================
// P1SkillRegistry
// ============================================================================

/// P1 技能注册中心
/// 管理所有 P1 级别技能的注册、依赖检查、初始化和健康监控
class P1SkillRegistry {
  /// 核心技能注册表引用
  final SkillRegistry _registry;

  /// 日志器
  final SkillLogger _logger = const SkillLogger('P1SkillRegistry');

  /// 已注册的 P1 技能 ID 列表
  final List<String> _registeredSkillIds = [];

  /// 技能初始化耗时记录
  final Map<String, Duration> _initDurations = {};

  /// 注册状态
  bool _registered = false;

  P1SkillRegistry({required SkillRegistry registry}) : _registry = registry;

  /// 是否已完成注册
  bool get isRegistered => _registered;

  /// 已注册 P1 技能数量
  int get registeredCount => _registeredSkillIds.length;

  /// 获取已注册 P1 技能 ID
  List<String> get registeredSkillIds => List.unmodifiable(_registeredSkillIds);

  // ============================================================================
  // 核心方法：注册所有 P1 技能
  // ============================================================================

  /// 注册所有 P1 技能到核心 SkillRegistry
  ///
  /// 注册流程：
  /// 1. 检查依赖完整性（P0 基础技能是否已就绪）
  /// 2. 按依赖关系排序初始化顺序
  /// 3. 依次实例化并注册各技能
  /// 4. 记录注册结果
  Future<P1RegistrationReport> registerAllP1Skills({
    int? sessionId,
  }) async {
    if (_registered) {
      _logger.warning('P1 技能已注册，跳过重复注册');
      return P1RegistrationReport(
        success: true,
        totalAttempted: _registeredSkillIds.length,
        succeeded: _registeredSkillIds.length,
        failed: 0,
        failedSkills: const [],
        message: 'P1 技能已就绪',
      );
    }

    _logger.info('开始注册 P1 技能...');
    final stopwatch = Stopwatch()..start();

    // Step 1: 检查依赖
    final dependencyCheck = _checkAllDependencies();
    if (dependencyCheck.hasMissing) {
      _logger.warning('部分技能依赖未满足: ${dependencyCheck.missingDeps}');
    }

    // Step 2: 拓扑排序确定初始化顺序
    final initOrder = _topologicalSort();
    _logger.info('初始化顺序: ${initOrder.join(" -> ")}');

    // Step 3: 按序注册技能
    int succeeded = 0;
    int failed = 0;
    final failedSkills = <String>[];

    for (final skillId in initOrder) {
      try {
        final skill = _createSkillInstance(skillId);
        if (skill == null) {
          _logger.warning('无法创建技能实例: $skillId');
          failed++;
          failedSkills.add(skillId);
          continue;
        }

        // 检查该技能的依赖是否满足
        final deps = _p1DependencyGraph[skillId] ?? [];
        final missingDeps = deps.where((d) => !_registry.isRegistered(d)).toList();
        if (missingDeps.isNotEmpty) {
          _logger.warning('跳过 $skillId，缺少依赖: ${missingDeps.join(", ")}');
          failed++;
          failedSkills.add(skillId);
          continue;
        }

        // 注册到核心注册表
        final initStopwatch = Stopwatch()..start();
        final result = await _registry.registerSkill(skill, autoInit: true, sessionId: sessionId);
        initStopwatch.stop();

        if (result.success) {
          _registeredSkillIds.add(skillId);
          _initDurations[skillId] = initStopwatch.elapsed;
          succeeded++;
          _logger.info('✓ 注册成功: ${skill.manifest.name} (${initStopwatch.elapsedMilliseconds}ms)');
        } else {
          failed++;
          failedSkills.add(skillId);
          _logger.error('注册失败: $skillId - ${result.error}');
        }
      } catch (e) {
        failed++;
        failedSkills.add(skillId);
        _logger.error('注册异常: $skillId', e);
      }
    }

    stopwatch.stop();
    _registered = true;

    final report = P1RegistrationReport(
      success: failed == 0,
      totalAttempted: initOrder.length,
      succeeded: succeeded,
      failed: failed,
      failedSkills: failedSkills,
      message: failed == 0
          ? 'P1 技能全部注册成功 (${succeeded}/${initOrder.length})，耗时 ${stopwatch.elapsedMilliseconds}ms'
          : 'P1 技能注册完成 ($succeeded 成功, $failed 失败)，耗时 ${stopwatch.elapsedMilliseconds}ms',
      duration: stopwatch.elapsed,
    );

    _logger.info(report.message);
    return report;
  }

  // ============================================================================
  // 技能实例化工厂
  // ============================================================================

  /// 根据技能 ID 创建对应的 Skill 实例
  Skill? _createSkillInstance(String skillId) {
    return switch (skillId) {
      'email' => EmailSkill(),
      'doc_gen' => DocGenSkill(),
      'social_media' => SocialMediaSkill(),
      'video_gen' => VideoGenSkill(),
      'podcast' => PodcastSkill(),
      'browser' => BrowserSkill(),
      'lark' => LarkSkill(),
      'topic_tracking' => TopicTrackingSkill(),
      'pro_domain' => ProDomainSkill(),
      'forbidden_word' => ForbiddenWordSkill(),
      'chart' => ChartSkill(),
      'cloud_sync' => CloudSyncSkill(),
      _ => null,
    };
  }

  // ============================================================================
  // 依赖检查
  // ============================================================================

  /// 检查所有 P1 技能的依赖
  P1DependencyReport _checkAllDependencies() {
    final missing = <String, List<String>>{};

    for (final entry in _p1DependencyGraph.entries) {
      final skillId = entry.key;
      final deps = entry.value;
      final missingDeps = <String>[];

      for (final dep in deps) {
        // P1 之间的依赖和 P0 的依赖都检查
        if (!_registry.isRegistered(dep) && !_p1DependencyGraph.containsKey(dep)) {
          missingDeps.add(dep);
        }
      }

      if (missingDeps.isNotEmpty) {
        missing[skillId] = missingDeps;
      }
    }

    return P1DependencyReport(missingDeps: missing);
  }

  /// 拓扑排序确定初始化顺序
  List<String> _topologicalSort() {
    final allSkillIds = _p1DependencyGraph.keys.toList();
    final sorted = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String id) {
      if (visited.contains(id)) return;
      if (visiting.contains(id)) {
        _logger.warning('检测到循环依赖: $id');
        return;
      }

      visiting.add(id);

      final deps = _p1DependencyGraph[id] ?? [];
      for (final dep in deps) {
        // 仅排序 P1 技能间的依赖
        if (_p1DependencyGraph.containsKey(dep)) {
          visit(dep);
        }
      }

      visiting.remove(id);
      visited.add(id);
      sorted.add(id);
    }

    // 按优先级排序后拓扑
    allSkillIds.sort((a, b) {
      final pa = _p1InitPriority[a] ?? 100;
      final pb = _p1InitPriority[b] ?? 100;
      return pa.compareTo(pb);
    });

    for (final id in allSkillIds) {
      visit(id);
    }

    return sorted;
  }

  // ============================================================================
  // 健康监控
  // ============================================================================

  /// 获取所有 P1 技能的健康状态
  List<P1SkillHealthStatus> getHealthStatuses() {
    final statuses = <P1SkillHealthStatus>[];

    for (final skillId in _registeredSkillIds) {
      final skill = _registry.getSkill(skillId);
      if (skill == null) continue;

      final deps = _p1DependencyGraph[skillId] ?? [];
      final missingDeps = deps.where((d) => !_registry.isRegistered(d)).toList();

      statuses.add(P1SkillHealthStatus(
        skillId: skillId,
        skillName: skill.manifest.name,
        status: skill.status,
        dependencySatisfied: missingDeps.isEmpty,
        missingDependencies: missingDeps,
        errorMessage: skill.errorMessage,
        toolCount: skill.tools.length,
        initDuration: _initDurations[skillId],
      ));
    }

    return statuses;
  }

  /// 生成技能状态监控面板数据
  Map<String, dynamic> getDashboardData() {
    final stats = _registry.getStats();
    final p1Stats = getHealthStatuses();

    int readyCount = 0;
    int errorCount = 0;
    int pausedCount = 0;
    int totalTools = 0;

    for (final s in p1Stats) {
      if (s.status == SkillStatus.ready) readyCount++;
      if (s.status == SkillStatus.error) errorCount++;
      if (s.status == SkillStatus.paused) pausedCount++;
      totalTools += s.toolCount;
    }

    return {
      'p1_total': p1Stats.length,
      'p1_ready': readyCount,
      'p1_error': errorCount,
      'p1_paused': pausedCount,
      'p1_total_tools': totalTools,
      'core_total_skills': stats.totalSkills,
      'core_ready_skills': stats.readySkills,
      'core_total_tools': stats.totalTools,
      'skills': p1Stats.map((s) => s.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 获取技能 ID 对应的中文名称
  static String getSkillDisplayName(String skillId) {
    return switch (skillId) {
      'email' => '邮件',
      'doc_gen' => '文档生成',
      'social_media' => '社交媒体',
      'video_gen' => '视频生成',
      'podcast' => '播客生成',
      'browser' => '浏览器',
      'lark' => '飞书',
      'topic_tracking' => '话题追踪',
      'pro_domain' => '专业域名',
      'forbidden_word' => '违禁词检测',
      'chart' => '数据图表',
      'cloud_sync' => '云同步',
      _ => skillId,
    };
  }

  /// 检查指定 P1 技能的依赖是否满足
  bool checkDependency(String skillId) {
    final deps = _p1DependencyGraph[skillId] ?? [];
    return deps.every((d) => _registry.isRegistered(d));
  }
}

// ============================================================================
// 注册报告与依赖报告
// ============================================================================

/// P1 注册报告
class P1RegistrationReport {
  final bool success;
  final int totalAttempted;
  final int succeeded;
  final int failed;
  final List<String> failedSkills;
  final String message;
  final Duration? duration;

  const P1RegistrationReport({
    required this.success,
    required this.totalAttempted,
    required this.succeeded,
    required this.failed,
    required this.failedSkills,
    required this.message,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'total_attempted': totalAttempted,
        'succeeded': succeeded,
        'failed': failed,
        'failed_skills': failedSkills,
        'message': message,
        if (duration != null) 'duration_ms': duration!.inMilliseconds,
      };
}

/// P1 依赖检查报告
class P1DependencyReport {
  /// 缺失的依赖: key = 技能 ID, value = 缺失的依赖列表
  final Map<String, List<String>> missingDeps;

  P1DependencyReport({required this.missingDeps});

  bool get hasMissing => missingDeps.isNotEmpty;

  /// 获取所有缺失的依赖（去重）
  List<String> get allMissing =>
      missingDeps.values.expand((e) => e).toSet().toList();

  Map<String, dynamic> toJson() => {
        'has_missing': hasMissing,
        'missing': missingDeps,
        'all_missing': allMissing,
      };
}

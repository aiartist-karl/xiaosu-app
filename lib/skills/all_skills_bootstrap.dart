// ============================================================================
// 小酥 AI 助手 - 全功能技能总注册入口 (AllSkillsBootstrap)
// ============================================================================
// 统一注册 P0 内置技能 + P1 全部技能
// 执行依赖初始化、技能自检、健康检查，输出技能清单日志
// ============================================================================

import 'dart:async';

import '../core/skill/skill.dart';
import '../core/skill/skill_registry.dart';

// P0 内置技能
import '../skills/web_search/web_search_skill.dart';
import '../skills/image_gen/image_gen_skill.dart';
import '../skills/tts/tts_skill.dart';
import '../skills/code_sandbox/code_sandbox_skill.dart';

// P1 技能
import '../skills/cloud_sync/cloud_sync_skill.dart';
import '../skills/email/email_skill.dart';
import '../skills/doc_gen/doc_gen_skill.dart';
import '../skills/social/social_media_skill.dart';
import '../skills/video/video_gen_skill.dart';
import '../skills/podcast/podcast_skill.dart';
import '../skills/browser/browser_skill.dart';
import '../skills/lark/lark_skill.dart';
import '../skills/tracking/topic_tracking_skill.dart';
import '../skills/pro_domain/pro_domain_skill.dart';
import '../skills/forbidden_word/forbidden_word_skill.dart';
import '../skills/chart/chart_skill.dart';

// ============================================================================
// 技能级别与清单
// ============================================================================

/// 技能级别
enum SkillTier {
  p0('P0', '核心内置'),
  p1('P1', '扩展能力');

  final String label;
  final String description;
  const SkillTier(this.label, this.description);
}

/// 技能注册条目
class _SkillEntry {
  final Skill skill;
  final SkillTier tier;
  final List<String> dependsOn;
  final bool eagerInit;

  const _SkillEntry({
    required this.skill,
    required this.tier,
    this.dependsOn = const [],
    this.eagerInit = false,
  });

  String get id => skill.manifest.id;
  String get name => skill.manifest.name;
}

/// 技能自检结果
class SkillSelfCheckResult {
  final String skillId;
  final String skillName;
  final bool passed;
  final List<String> checks;
  final String? failureReason;

  const SkillSelfCheckResult({
    required this.skillId,
    required this.skillName,
    required this.passed,
    this.checks = const [],
    this.failureReason,
  });

  Map<String, dynamic> toJson() => {
        'skill_id': skillId,
        'skill_name': skillName,
        'passed': passed,
        'checks': checks,
        if (failureReason != null) 'failure_reason': failureReason,
      };
}

/// 引导完成报告
class BootstrapReport {
  final bool success;
  final int totalP0;
  final int totalP1;
  final int succeeded;
  final int failed;
  final int selfCheckPassed;
  final int selfCheckFailed;
  final List<String> registeredSkillIds;
  final List<SkillSelfCheckResult> selfCheckResults;
  final Duration duration;

  const BootstrapReport({
    required this.success,
    required this.totalP0,
    required this.totalP1,
    required this.succeeded,
    required this.failed,
    required this.selfCheckPassed,
    required this.selfCheckFailed,
    required this.registeredSkillIds,
    required this.selfCheckResults,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'total_p0': totalP0,
        'total_p1': totalP1,
        'succeeded': succeeded,
        'failed': failed,
        'self_check_passed': selfCheckPassed,
        'self_check_failed': selfCheckFailed,
        'registered_skill_ids': registeredSkillIds,
        'self_check_results': selfCheckResults.map((r) => r.toJson()).toList(),
        'duration_ms': duration.inMilliseconds,
      };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════╗');
    buffer.writeln('║      小酥 AI - 技能系统引导报告              ║');
    buffer.writeln('╠══════════════════════════════════════════════╣');
    buffer.writeln('║ 状态: ${success ? "✓ 全部成功" : "✗ 部分失败"}                    ');
    buffer.writeln('║ P0 核心技能: $totalP0 个');
    buffer.writeln('║ P1 扩展技能: $totalP1 个');
    buffer.writeln('║ 注册成功: $succeeded | 失败: $failed');
    buffer.writeln('║ 自检通过: $selfCheckPassed | 未通过: $selfCheckFailed');
    buffer.writeln('║ 总耗时: ${duration.inMilliseconds}ms');
    buffer.writeln('╚══════════════════════════════════════════════╝');
    return buffer.toString();
  }
}

// ============================================================================
// AllSkillsBootstrap 主类
// ============================================================================

/// 全功能技能总注册入口
/// 统一管理 P0/P1 技能的注册、初始化、自检和健康监控
class AllSkillsBootstrap {
  /// 技能上下文工厂
  static SkillContext Function(int? sessionId)? _contextFactory;

  /// 日志器
  static final SkillLogger _logger = const SkillLogger('AllSkillsBootstrap');

  /// 是否已引导
  static bool _bootstrapped = false;

  /// 所有技能条目
  static final List<_SkillEntry> _allEntries = [];

  // ============================================================================
  // 核心方法：引导初始化
  // ============================================================================

  /// 初始化所有技能系统
  ///
  /// 流程：
  /// 1. 注册 P0 内置技能（搜索/生图/TTS/代码沙箱）
  /// 2. 注册 P1 全部技能（12 个扩展技能）
  /// 3. 初始化技能依赖
  /// 4. 执行技能自检
  /// 5. 输出技能清单日志
  static Future<BootstrapReport> initialize({
    required SkillRegistry skillRegistry,
    required SkillContext Function(int? sessionId) contextFactory,
    int? sessionId,
  }) async {
    if (_bootstrapped) {
      _logger.warning('技能系统已引导，跳过重复初始化');
      return _buildReport(
        success: true,
        registeredIds: skillRegistry.getAllSkills().map((s) => s.manifest.id).toList(),
      );
    }

    _contextFactory = contextFactory;
    final stopwatch = Stopwatch()..start();

    _logger.info('========================================');
    _logger.info('  小酥 AI - 技能系统引导开始');
    _logger.info('========================================');

    final registeredIds = <String>[];
    int p0Count = 0;
    int p1Count = 0;
    int succeeded = 0;
    int failed = 0;

    // ─── Step 1: 注册 P0 内置技能 ───────────────────────────────
    _logger.info('[Step 1/5] 注册 P0 内置技能...');
    final p0Skills = _buildP0Skills();
    for (final entry in p0Skills) {
      final result = await _registerSingle(skillRegistry, entry, sessionId);
      if (result) {
        registeredIds.add(entry.id);
        p0Count++;
        succeeded++;
      } else {
        failed++;
      }
    }
    _logger.info('  P0 技能注册完成: $p0Count 个');

    // ─── Step 2: 注册 P1 全部技能 ───────────────────────────────
    _logger.info('[Step 2/5] 注册 P1 扩展技能...');
    final p1Skills = _buildP1Skills();
    for (final entry in p1Skills) {
      // 检查依赖
      final depsReady = entry.dependsOn.every((d) => skillRegistry.isRegistered(d));
      if (!depsReady) {
        final missing = entry.dependsOn.where((d) => !skillRegistry.isRegistered(d)).toList();
        _logger.warning('  跳过 ${entry.name}，缺少依赖: ${missing.join(", ")}');
        failed++;
        continue;
      }

      final result = await _registerSingle(skillRegistry, entry, sessionId);
      if (result) {
        registeredIds.add(entry.id);
        p1Count++;
        succeeded++;
      } else {
        failed++;
      }
    }
    _logger.info('  P1 技能注册完成: $p1Count 个');

    // ─── Step 3: 初始化技能依赖 ─────────────────────────────────
    _logger.info('[Step 3/5] 初始化技能依赖关系...');
    await _initializeDependencies(skillRegistry, sessionId);
    _logger.info('  依赖初始化完成');

    // ─── Step 4: 执行技能自检 ───────────────────────────────────
    _logger.info('[Step 4/5] 执行技能自检...');
    final selfCheckResults = await _runSelfChecks(skillRegistry);
    int selfCheckPassed = selfCheckResults.where((r) => r.passed).length;
    int selfCheckFailed = selfCheckResults.where((r) => !r.passed).length;
    _logger.info('  自检完成: $selfCheckPassed 通过, $selfCheckFailed 未通过');

    // ─── Step 5: 输出技能清单日志 ───────────────────────────────
    _logger.info('[Step 5/5] 输出技能清单...');
    _printSkillManifest(skillRegistry);

    stopwatch.stop();
    _bootstrapped = true;

    final report = BootstrapReport(
      success: failed == 0,
      totalP0: p0Count,
      totalP1: p1Count,
      succeeded: succeeded,
      failed: failed,
      selfCheckPassed: selfCheckPassed,
      selfCheckFailed: selfCheckFailed,
      registeredSkillIds: registeredIds,
      selfCheckResults: selfCheckResults,
      duration: stopwatch.elapsed,
    );

    _logger.info(report.toString());
    return report;
  }

  // ============================================================================
  // P0 技能列表
  // ============================================================================

  static List<_SkillEntry> _buildP0Skills() {
    return [
      _SkillEntry(
        skill: WebSearchSkill(),
        tier: SkillTier.p0,
        eagerInit: true,
      ),
      _SkillEntry(
        skill: ImageGenSkill(),
        tier: SkillTier.p0,
        eagerInit: false,
      ),
      _SkillEntry(
        skill: TtsSkill(),
        tier: SkillTier.p0,
        eagerInit: false,
      ),
      _SkillEntry(
        skill: CodeSandboxSkill(),
        tier: SkillTier.p0,
        eagerInit: false,
      ),
    ];
  }

  // ============================================================================
  // P1 技能列表
  // ============================================================================

  static List<_SkillEntry> _buildP1Skills() {
    return [
      // 无依赖 - 先注册
      _SkillEntry(
        skill: CloudSyncSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      _SkillEntry(
        skill: EmailSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      _SkillEntry(
        skill: DocGenSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      _SkillEntry(
        skill: PodcastSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      _SkillEntry(
        skill: ForbiddenWordSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      _SkillEntry(
        skill: ChartSkill(),
        tier: SkillTier.p1,
        dependsOn: [],
      ),
      // 有依赖
      _SkillEntry(
        skill: SocialMediaSkill(),
        tier: SkillTier.p1,
        dependsOn: ['image_gen'],
      ),
      _SkillEntry(
        skill: VideoGenSkill(),
        tier: SkillTier.p1,
        dependsOn: ['image_gen'],
      ),
      _SkillEntry(
        skill: BrowserSkill(),
        tier: SkillTier.p1,
        dependsOn: ['web_search'],
      ),
      _SkillEntry(
        skill: LarkSkill(),
        tier: SkillTier.p1,
        dependsOn: ['email'],
      ),
      _SkillEntry(
        skill: TopicTrackingSkill(),
        tier: SkillTier.p1,
        dependsOn: ['web_search'],
      ),
      _SkillEntry(
        skill: ProDomainSkill(),
        tier: SkillTier.p1,
        dependsOn: ['web_search'],
      ),
    ];
  }

  // ============================================================================
  // 单个技能注册
  // ============================================================================

  static Future<bool> _registerSingle(
    SkillRegistry registry,
    _SkillEntry entry,
    int? sessionId,
  ) async {
    try {
      final result = await registry.registerSkill(
        entry.skill,
        autoInit: entry.eagerInit,
        sessionId: sessionId,
      );

      if (result.success) {
        final tier = entry.tier.label;
        final initStr = entry.eagerInit ? ' [eager]' : ' [lazy]';
        _logger.info('  ✓ [$tier] ${entry.name}$initStr');
        return true;
      } else {
        _logger.error('  ✗ [${entry.tier.label}] ${entry.name} - ${result.error}');
        return false;
      }
    } catch (e) {
      _logger.error('  ✗ [${entry.tier.label}] ${entry.name} - 异常: $e');
      return false;
    }
  }

  // ============================================================================
  // 依赖初始化
  // ============================================================================

  static Future<void> _initializeDependencies(
    SkillRegistry registry,
    int? sessionId,
  ) async {
    final context = _contextFactory!(sessionId);

    // 遍历所有已注册但未初始化的技能
    for (final skill in registry.getAllSkills()) {
      if (skill.status == SkillStatus.uninitialized) {
        try {
          // 检查依赖是否满足
          final deps = skill.manifest.dependencies;
          final depsReady = deps.every((d) => registry.isRegistered(d));
          if (!depsReady) continue;

          await skill.initialize(context);
        } catch (e) {
          _logger.error('${skill.manifest.name} 初始化失败', e);
        }
      }
    }
  }

  // ============================================================================
  // 技能自检
  // ============================================================================

  static Future<List<SkillSelfCheckResult>> _runSelfChecks(
    SkillRegistry registry,
  ) async {
    final results = <SkillSelfCheckResult>[];
    final context = _contextFactory!(null);

    for (final skill in registry.getAllSkills()) {
      final checks = <String>[];
      bool allPassed = true;
      String? failureReason;

      // 检查 1: 清单完整性
      final manifest = skill.manifest;
      if (manifest.id.isNotEmpty && manifest.name.isNotEmpty) {
        checks.add('清单完整性: ✓');
      } else {
        checks.add('清单完整性: ✗');
        allPassed = false;
        failureReason = '清单信息不完整';
      }

      // 检查 2: 工具定义
      if (skill.tools.isNotEmpty) {
        checks.add('工具定义: ✓ (${skill.tools.length} 个工具)');
      } else {
        checks.add('工具定义: ✗ (无工具)');
        // 没有工具不一定算失败，但标记
      }

      // 检查 3: 工具名称唯一性
      final toolNames = skill.tools.map((t) => t.name).toSet();
      if (toolNames.length == skill.tools.length) {
        checks.add('工具唯一性: ✓');
      } else {
        checks.add('工具唯一性: ✗ (存在重复)');
        allPassed = false;
        failureReason = '工具名称重复';
      }

      // 检查 4: 状态检查
      if (skill.status == SkillStatus.ready || skill.status == SkillStatus.uninitialized) {
        checks.add('状态: ✓ (${skill.status.value})');
      } else {
        checks.add('状态: ✗ (${skill.status.value})');
        allPassed = false;
        failureReason = '状态异常: ${skill.status.value}';
      }

      // 检查 5: 依赖满足
      final deps = manifest.dependencies;
      if (deps.isEmpty || deps.every((d) => registry.isRegistered(d))) {
        checks.add('依赖: ✓');
      } else {
        checks.add('依赖: ✗ (缺失)');
        allPassed = false;
        failureReason = '依赖未满足';
      }

      results.add(SkillSelfCheckResult(
        skillId: manifest.id,
        skillName: manifest.name,
        passed: allPassed,
        checks: checks,
        failureReason: failureReason,
      ));
    }

    return results;
  }

  // ============================================================================
  // 输出技能清单
  // ============================================================================

  static void _printSkillManifest(SkillRegistry registry) {
    final allSkills = registry.getAllSkills();
    final stats = registry.getStats();

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('┌──────────────────────────────────────────────┐');
    buffer.writeln('│          小酥 AI - 技能清单                   │');
    buffer.writeln('├──────────────────────────────────────────────┤');
    buffer.writeln('│ 总计: ${stats.totalSkills} 个技能 | ${stats.totalTools} 个工具');
    buffer.writeln('│ 就绪: ${stats.readySkills} | 异常: ${stats.errorSkills} | 暂停: ${stats.pausedSkills}');
    buffer.writeln('├──────────────────────────────────────────────┤');

    // P0 技能
    buffer.writeln('│ 【P0 核心内置】');
    for (final skill in allSkills) {
      if (_isP0Skill(skill.manifest.id)) {
        final statusIcon = skill.status == SkillStatus.ready ? '✓' : '○';
        buffer.writeln('│   $statusIcon ${skill.manifest.name} v${skill.manifest.version} '
            '(${skill.tools.length} 工具)');
      }
    }

    // P1 技能
    buffer.writeln('│ 【P1 扩展能力】');
    for (final skill in allSkills) {
      if (!_isP0Skill(skill.manifest.id)) {
        final statusIcon = skill.status == SkillStatus.ready ? '✓' : '○';
        buffer.writeln('│   $statusIcon ${skill.manifest.name} v${skill.manifest.version} '
            '(${skill.tools.length} 工具)');
      }
    }

    buffer.writeln('└──────────────────────────────────────────────┘');

    _logger.info(buffer.toString());
  }

  /// 判断是否为 P0 技能
  static bool _isP0Skill(String skillId) {
    const p0Ids = {'web_search', 'image_gen', 'tts', 'code_sandbox'};
    return p0Ids.contains(skillId);
  }

  // ============================================================================
  // 查询接口
  // ============================================================================

  /// 列出所有已注册技能的名称
  static List<String> listAllSkills({SkillRegistry? registry}) {
    if (registry == null) return _allEntries.map((e) => e.name).toList();
    return registry.getAllSkills().map((s) => s.manifest.name).toList();
  }

  /// 获取所有技能的健康状态
  static Map<String, SkillStatus> getHealthStatus({SkillRegistry? registry}) {
    if (registry == null) {
      return Map.fromEntries(
        _allEntries.map((e) => MapEntry(e.id, e.skill.status)),
      );
    }
    return Map.fromEntries(
      registry.getAllSkills().map((s) => MapEntry(s.manifest.id, s.status)),
    );
  }

  /// 获取详细技能信息
  static List<Map<String, dynamic>> getSkillDetails({SkillRegistry? registry}) {
    if (registry == null) {
      return _allEntries.map((e) => e.skill.toSummary()).toList();
    }
    return registry.getAllSkills().map((s) => s.toSummary()).toList();
  }

  /// 构建默认报告（用于已引导的情况）
  static BootstrapReport _buildReport({
    required bool success,
    required List<String> registeredIds,
  }) {
    return BootstrapReport(
      success: success,
      totalP0: 4,
      totalP1: 12,
      succeeded: registeredIds.length,
      failed: 0,
      selfCheckPassed: registeredIds.length,
      selfCheckFailed: 0,
      registeredSkillIds: registeredIds,
      selfCheckResults: const [],
      duration: Duration.zero,
    );
  }
}

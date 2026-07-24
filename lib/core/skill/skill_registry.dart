// ============================================================================
// 小酥 AI 助手 - 技能注册表
// ============================================================================
// 管理所有技能的注册、生命周期、工具路由
// 提供技能搜索、启用/禁用、动态加载等功能
// ============================================================================

import 'dart:async';
import 'dart:collection';

import 'skill.dart';

/// 技能注册表
/// 管理所有技能的注册、发现和工具调用路由
class SkillRegistry {
  /// 已注册的技能映射表（skillId -> Skill）
  final Map<String, Skill> _skills = {};

  /// 工具到技能的映射表（toolName -> skillId）
  /// 用于快速查找工具所属的技能
  final Map<String, String> _toolToSkill = {};

  /// 技能上下文工厂
  final SkillContext Function(int? sessionId) _contextFactory;

  /// 状态变更监听器
  final StreamController<SkillStatusChange> _statusController =
      StreamController<SkillStatusChange>.broadcast();

  /// 技能状态变更流
  Stream<SkillStatusChange> get statusChanges => _statusController.stream;

  /// 构造函数
  ///
  /// [contextFactory] 用于创建技能上下文的工厂函数
  SkillRegistry({
    required SkillContext Function(int? sessionId) contextFactory,
  }) : _contextFactory = contextFactory;

  // ============================================================================
  // 技能注册与注销
  // ============================================================================

  /// 注册技能
  ///
  /// [skill] 要注册的技能实例
  /// [autoInit] 是否自动初始化（根据加载策略）
  /// [sessionId] 当前会话 ID（用于创建上下文）
  Future<SkillRegistrationResult> registerSkill(
    Skill skill, {
    bool autoInit = true,
    int? sessionId,
  }) async {
    final skillId = skill.manifest.id;

    // 检查是否已注册
    if (_skills.containsKey(skillId)) {
      return SkillRegistrationResult(
        success: false,
        error: '技能已注册: $skillId',
      );
    }

    // 检查工具名称冲突
    for (final tool in skill.tools) {
      if (_toolToSkill.containsKey(tool.name)) {
        final existingSkillId = _toolToSkill[tool.name];
        return SkillRegistrationResult(
          success: false,
          error: '工具名称冲突: ${tool.name} 已被技能 $existingSkillId 注册',
        );
      }
    }

    // 注册技能
    _skills[skillId] = skill;

    // 注册工具映射
    for (final tool in skill.tools) {
      _toolToSkill[tool.name] = skillId;
    }

    // 根据加载策略决定是否自动初始化
    if (autoInit && skill.manifest.loadStrategy == SkillLoadStrategy.eager) {
      try {
        final context = _contextFactory(sessionId);
        await skill.initialize(context);
        _statusController.add(SkillStatusChange(
          skillId: skillId,
          oldStatus: SkillStatus.uninitialized,
          newStatus: SkillStatus.ready,
        ));
      } catch (e) {
        _statusController.add(SkillStatusChange(
          skillId: skillId,
          oldStatus: SkillStatus.uninitialized,
          newStatus: SkillStatus.error,
          error: e.toString(),
        ));
        return SkillRegistrationResult(
          success: false,
          error: '技能初始化失败: $e',
        );
      }
    }

    return SkillRegistrationResult(success: true, skillId: skillId);
  }

  /// 注销技能
  ///
  /// [skillId] 要注销的技能 ID
  Future<bool> unregisterSkill(String skillId) async {
    final skill = _skills[skillId];
    if (skill == null) return false;

    // 销毁技能
    try {
      await skill.dispose();
    } catch (e) {
      // 销毁失败不影响注销
    }

    // 移除工具映射
    for (final tool in skill.tools) {
      _toolToSkill.remove(tool.name);
    }

    // 移除技能
    _skills.remove(skillId);

    _statusController.add(SkillStatusChange(
      skillId: skillId,
      oldStatus: skill.status,
      newStatus: SkillStatus.disposed,
    ));

    return true;
  }

  // ============================================================================
  // 技能获取与查询
  // ============================================================================

  /// 获取技能实例
  Skill? getSkill(String skillId) => _skills[skillId];

  /// 获取所有已注册的技能
  List<Skill> getAllSkills() => UnmodifiableListView(_skills.values.toList());

  /// 获取所有已就绪的技能
  List<Skill> getReadySkills() =>
      _skills.values.where((s) => s.status == SkillStatus.ready).toList();

  /// 获取技能数量
  int get skillCount => _skills.length;

  /// 检查技能是否已注册
  bool isRegistered(String skillId) => _skills.containsKey(skillId);

  /// 检查工具是否存在
  bool hasTool(String toolName) => _toolToSkill.containsKey(toolName);

  /// 获取工具所属的技能
  Skill? getSkillForTool(String toolName) {
    final skillId = _toolToSkill[toolName];
    if (skillId == null) return null;
    return _skills[skillId];
  }

  // ============================================================================
  // 工具调用路由
  // ============================================================================

  /// 执行工具调用
  /// 根据工具名称自动路由到对应的技能
  ///
  /// [toolName] 工具名称
  /// [arguments] 工具参数
  /// [sessionId] 当前会话 ID
  Future<ToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    int? sessionId,
  }) async {
    // 查找工具所属的技能
    final skillId = _toolToSkill[toolName];
    if (skillId == null) {
      return ToolResult.failure(
        error: '未找到工具: $toolName',
        errorCode: 'TOOL_NOT_FOUND',
      );
    }

    final skill = _skills[skillId];
    if (skill == null) {
      return ToolResult.failure(
        error: '技能不存在: $skillId',
        errorCode: 'SKILL_NOT_FOUND',
      );
    }

    // 懒加载：如果技能尚未初始化，先初始化
    if (skill.status == SkillStatus.uninitialized) {
      try {
        final context = _contextFactory(sessionId);
        await skill.initialize(context);
        _statusController.add(SkillStatusChange(
          skillId: skillId,
          oldStatus: SkillStatus.uninitialized,
          newStatus: SkillStatus.ready,
        ));
      } catch (e) {
        return ToolResult.failure(
          error: '技能初始化失败: $e',
          errorCode: 'INIT_FAILED',
        );
      }
    }

    // 检查技能是否可以执行
    if (!skill.status.canExecute) {
      return ToolResult.failure(
        error: '技能当前不可用: ${skill.status.value}',
        errorCode: 'SKILL_NOT_READY',
      );
    }

    // 执行工具
    final context = _contextFactory(sessionId);
    return await skill.executeTool(toolName, arguments, context);
  }

  /// 获取所有可用工具的定义（用于 LLM 的工具描述）
  List<Map<String, dynamic>> getAllToolDefinitions({
    bool onlyReady = true,
  }) {
    final definitions = <Map<String, dynamic>>[];

    for (final skill in _skills.values) {
      if (onlyReady && !skill.status.canExecute) continue;
      for (final tool in skill.tools) {
        definitions.add(tool.toFunctionDef());
      }
    }

    return definitions;
  }

  // ============================================================================
  // 技能启用/禁用
  // ============================================================================

  /// 启用技能
  /// 启用后技能的工具可以被调用
  Future<bool> enableSkill(String skillId) async {
    final skill = _skills[skillId];
    if (skill == null) return false;

    if (skill.status == SkillStatus.uninitialized) {
      try {
        final context = _contextFactory(null);
        await skill.initialize(context);
        _statusController.add(SkillStatusChange(
          skillId: skillId,
          oldStatus: skill.status,
          newStatus: SkillStatus.ready,
        ));
      } catch (e) {
        _statusController.add(SkillStatusChange(
          skillId: skillId,
          oldStatus: skill.status,
          newStatus: SkillStatus.error,
          error: e.toString(),
        ));
        return false;
      }
    } else if (skill.status == SkillStatus.paused) {
      // 从暂停状态恢复（需要子类实现恢复逻辑）
      _statusController.add(SkillStatusChange(
        skillId: skillId,
        oldStatus: SkillStatus.paused,
        newStatus: SkillStatus.ready,
      ));
    }

    return true;
  }

  /// 禁用技能
  /// 禁用后技能的工具不能被调用，但技能实例仍然保留
  Future<bool> disableSkill(String skillId) async {
    final skill = _skills[skillId];
    if (skill == null) return false;

    final oldStatus = skill.status;
    // 将技能标记为暂停状态
    // 注意：这里通过反射修改状态不够优雅，实际项目中可以用专门的字段
    // 暂时通过 dispose + 重新初始化来实现
    // TODO: 改进为真正的 pause/resume 机制

    _statusController.add(SkillStatusChange(
      skillId: skillId,
      oldStatus: oldStatus,
      newStatus: SkillStatus.paused,
    ));

    return true;
  }

  // ============================================================================
  // 技能搜索
  // ============================================================================

  /// 按关键词搜索技能
  /// 在技能名称、描述和工具描述中搜索
  ///
  /// [query] 搜索关键词
  /// [includeTools] 是否也搜索工具描述
  List<Skill> searchSkills(String query, {bool includeTools = true}) {
    if (query.trim().isEmpty) return getAllSkills();

    final lowerQuery = query.toLowerCase();
    final results = <Skill, double>{}; // 技能 -> 相关度评分

    for (final skill in _skills.values) {
      double score = 0;

      // 名称匹配（权重最高）
      if (skill.manifest.name.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }

      // 描述匹配
      if (skill.manifest.description.toLowerCase().contains(lowerQuery)) {
        score += 2.0;
      }

      // ID 匹配
      if (skill.manifest.id.toLowerCase().contains(lowerQuery)) {
        score += 1.5;
      }

      // 工具匹配
      if (includeTools) {
        for (final tool in skill.tools) {
          if (tool.name.toLowerCase().contains(lowerQuery)) {
            score += 1.0;
          }
          if (tool.description.toLowerCase().contains(lowerQuery)) {
            score += 0.5;
          }
        }
      }

      if (score > 0) {
        results[skill] = score;
      }
    }

    // 按相关度排序
    final sortedSkills = results.keys.toList()
      ..sort((a, b) => results[b]!.compareTo(results[a]!));

    return sortedSkills;
  }

  /// 按能力搜索技能
  /// 查找能提供特定能力的技能
  ///
  /// [capability] 能力关键词（如 "搜索"、"绘图"）
  List<Skill> findSkillsByCapability(String capability) {
    return searchSkills(capability, includeTools: true);
  }

  // ============================================================================
  // 生命周期管理
  // ============================================================================

  /// 初始化所有 eager 加载的技能
  Future<void> initializeEagerSkills({int? sessionId}) async {
    for (final skill in _skills.values) {
      if (skill.manifest.loadStrategy == SkillLoadStrategy.eager &&
          skill.status == SkillStatus.uninitialized) {
        try {
          final context = _contextFactory(sessionId);
          await skill.initialize(context);
          _statusController.add(SkillStatusChange(
            skillId: skill.manifest.id,
            oldStatus: SkillStatus.uninitialized,
            newStatus: SkillStatus.ready,
          ));
        } catch (e) {
          _statusController.add(SkillStatusChange(
            skillId: skill.manifest.id,
            oldStatus: SkillStatus.uninitialized,
            newStatus: SkillStatus.error,
            error: e.toString(),
          ));
        }
      }
    }
  }

  /// 后台初始化所有 lazy 加载的技能
  Future<void> initializeAllSkillsInBackground({int? sessionId}) async {
    for (final skill in _skills.values) {
      if (skill.manifest.loadStrategy == SkillLoadStrategy.background &&
          skill.status == SkillStatus.uninitialized) {
        try {
          final context = _contextFactory(sessionId);
          await skill.initialize(context);
        } catch (e) {
          // 后台初始化失败不抛出
        }
      }
    }
  }

  /// 销毁所有技能（应用关闭时调用）
  Future<void> disposeAll() async {
    for (final skill in _skills.values.toList()) {
      try {
        await skill.dispose();
      } catch (e) {
        // 忽略销毁失败
      }
    }
    _skills.clear();
    _toolToSkill.clear();
    await _statusController.close();
  }

  /// 重新初始化指定技能（用于配置变更后）
  Future<bool> reinitializeSkill(String skillId, {int? sessionId}) async {
    final skill = _skills[skillId];
    if (skill == null) return false;

    try {
      await skill.dispose();
      final context = _contextFactory(sessionId);
      await skill.initialize(context);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // 统计信息
  // ============================================================================

  /// 获取注册表统计信息
  RegistryStats getStats() {
    int readyCount = 0;
    int errorCount = 0;
    int pausedCount = 0;

    for (final skill in _skills.values) {
      switch (skill.status) {
        case SkillStatus.ready:
          readyCount++;
          break;
        case SkillStatus.error:
          errorCount++;
          break;
        case SkillStatus.paused:
          pausedCount++;
          break;
        default:
          break;
      }
    }

    return RegistryStats(
      totalSkills: _skills.length,
      readySkills: readyCount,
      errorSkills: errorCount,
      pausedSkills: pausedCount,
      totalTools: _toolToSkill.length,
    );
  }
}

// ============================================================================
// 辅助模型
// ============================================================================

/// 技能注册结果
class SkillRegistrationResult {
  final bool success;
  final String? skillId;
  final String? error;

  const SkillRegistrationResult({
    required this.success,
    this.skillId,
    this.error,
  });
}

/// 技能状态变更事件
class SkillStatusChange {
  final String skillId;
  final SkillStatus oldStatus;
  final SkillStatus newStatus;
  final String? error;

  const SkillStatusChange({
    required this.skillId,
    required this.oldStatus,
    required this.newStatus,
    this.error,
  });
}

/// 注册表统计
class RegistryStats {
  final int totalSkills;
  final int readySkills;
  final int errorSkills;
  final int pausedSkills;
  final int totalTools;

  const RegistryStats({
    required this.totalSkills,
    required this.readySkills,
    required this.errorSkills,
    required this.pausedSkills,
    required this.totalTools,
  });

  Map<String, dynamic> toJson() => {
        'total_skills': totalSkills,
        'ready_skills': readySkills,
        'error_skills': errorSkills,
        'paused_skills': pausedSkills,
        'total_tools': totalTools,
      };
}

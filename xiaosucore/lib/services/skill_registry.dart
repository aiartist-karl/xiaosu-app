// ============================================================================
// 小酥 - 服务层技能注册表
// ============================================================================

import '../core/skill/skill.dart';
import '../core/skill/skill_registry.dart';
import '../skills/p1_skill_registry.dart';

/// 服务层技能注册表 - 桥接Core层注册表和UI层
class SkillRegistryService {
  static final SkillRegistryService instance = SkillRegistryService._();
  SkillRegistryService._();

  final SkillRegistry _registry = SkillRegistry.instance;

  /// 初始化并注册所有技能
  Future<void> initialize() async {
    // 注册P1技能
    P1SkillRegistry.registerAll(_registry);
    await _registry.initializeAll();
  }

  /// 获取所有技能
  List<BaseSkill> get allSkills => _registry.allSkills;

  /// 获取技能
  BaseSkill? get(String skillId) => _registry.get(skillId);

  /// 搜索技能
  List<BaseSkill> search(String query) => _registry.search(query);

  /// 执行技能
  Future<SkillResult> execute(String skillId, SkillContext context) {
    return _registry.execute(skillId, context);
  }

  /// 启用/禁用技能
  void toggleSkill(String skillId, {required bool enabled}) {
    final skill = _registry.get(skillId);
    if (skill != null) skill.enabled = enabled;
  }

  /// 技能数量
  int get length => _registry.length;
}

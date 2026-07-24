// ============================================================================
// 小酥 - 技能注册表（Core层）
// ============================================================================

import 'skill.dart';

/// 技能注册表
class SkillRegistry {
  static final SkillRegistry instance = SkillRegistry._();
  SkillRegistry._();

  final Map<String, BaseSkill> _skills = {};

  /// 注册技能
  void register(BaseSkill skill) {
    _skills[skill.skillId] = skill;
  }

  /// 批量注册
  void registerAll(List<BaseSkill> skills) {
    for (final skill in skills) {
      register(skill);
    }
  }

  /// 取消注册
  void unregister(String skillId) {
    _skills.remove(skillId);
  }

  /// 获取技能
  BaseSkill? get(String skillId) => _skills[skillId];

  /// 获取所有技能
  List<BaseSkill> get allSkills => _skills.values.toList();

  /// 按名称搜索技能
  List<BaseSkill> search(String query) {
    final q = query.toLowerCase();
    return _skills.values.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q)
    ).toList();
  }

  /// 执行技能
  Future<SkillResult> execute(String skillId, SkillContext context) async {
    final skill = _skills[skillId];
    if (skill == null) return SkillResult.fail('技能未找到: $skillId');
    if (!skill.enabled) return SkillResult.fail('技能已禁用: ${skill.name}');
    try {
      return await skill.execute(context);
    } catch (e) {
      return SkillResult.fail('技能执行失败: $e');
    }
  }

  /// 初始化所有技能
  Future<void> initializeAll() async {
    for (final skill in _skills.values) {
      await skill.initialize();
    }
  }

  /// 释放所有技能
  Future<void> disposeAll() async {
    for (final skill in _skills.values) {
      await skill.dispose();
    }
    _skills.clear();
  }

  /// 技能数量
  int get length => _skills.length;
}

// ============================================================================
// 小酥 - 全部技能引导
// ============================================================================

import '../core/skill/skill_registry.dart';
import 'p1_skill_registry.dart';

/// 全部技能引导 - 初始化所有技能
class AllSkillsBootstrap {
  static Future<void> initialize(SkillRegistry registry) async {
    P1SkillRegistry.registerAll(registry);
    await registry.initializeAll();
  }
}

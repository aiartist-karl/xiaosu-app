// ============================================================================
// 小酥 - P2 引导初始化
// ============================================================================

import 'services/service_locator.dart';
import 'services/skill_registry.dart';

/// P2阶段引导 - 初始化高级功能
class P2Bootstrap {
  static Future<void> initialize() async {
    // 初始化核心服务
    await ServiceLocator.instance.initialize();
    // 初始化技能
    await SkillRegistryService.instance.initialize();
  }
}

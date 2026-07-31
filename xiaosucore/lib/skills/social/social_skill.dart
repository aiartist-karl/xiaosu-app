// ============================================================================
// 小酥 - 社交媒体技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 社交媒体技能
class SocialSkill extends BaseSkill {
  @override
  String get skillId => 'social';
  @override
  String get name => '社交媒体';
  @override
  String get description => '社交平台内容管理与发布';

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final platform = context.parameters['platform'] as String? ?? '';
    final action = context.parameters['action'] as String? ?? 'post';
    final content = context.parameters['content'] as String? ?? '';
    if (content.isEmpty) return SkillResult.fail('请提供内容');
    try {
      final response = await ApiGateway.instance.post(
        '/api/social/$platform/$action', body: {'content': content},
      );
      if (response.success) return SkillResult.ok('发布成功');
      return SkillResult.fail('发布失败: ${response.error}');
    } catch (e) {
      return SkillResult.fail('社交媒体错误: $e');
    }
  }
}

// ============================================================================
// 小酥 - 播客制作技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 播客制作技能
class PodcastSkill extends BaseSkill {
  @override
  String get skillId => 'podcast';
  @override
  String get name => '播客制作';
  @override
  String get description => 'AI生成播客音频内容';

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final topic = context.parameters['topic'] as String? ?? '';
    final mode = context.parameters['mode'] as String? ?? 'solo';
    if (topic.isEmpty) return SkillResult.fail('请提供播客主题');
    try {
      final response = await ApiGateway.instance.post(
        '/api/podcast/generate', body: {'topic': topic, 'mode': mode},
      );
      if (response.success && response.data != null) {
        return SkillResult.ok('播客生成中', data: {'taskId': response.data!['taskId']});
      }
      return SkillResult.fail('播客生成失败');
    } catch (e) {
      return SkillResult.fail('播客错误: $e');
    }
  }
}

// ============================================================================
// 小酥 - 视频生成技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 视频生成技能
class VideoSkill extends BaseSkill {
  @override
  String get skillId => 'video';
  @override
  String get name => '视频生成';
  @override
  String get description => 'AI生成短视频';

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final prompt = context.parameters['prompt'] as String? ?? '';
    if (prompt.isEmpty) return SkillResult.fail('请提供视频描述');
    try {
      final response = await ApiGateway.instance.post(
        '/api/video/generate', body: {'prompt': prompt, 'duration': context.parameters['duration'] ?? 5},
      );
      if (response.success && response.data != null) {
        return SkillResult.ok('视频生成中', data: {'taskId': response.data!['taskId']});
      }
      return SkillResult.fail('视频生成失败');
    } catch (e) {
      return SkillResult.fail('视频生成错误: $e');
    }
  }
}

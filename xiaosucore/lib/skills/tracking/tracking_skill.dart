// ============================================================================
// 小酥 - 话题追踪技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 话题追踪技能
class TrackingSkill extends BaseSkill {
  @override
  String get skillId => 'tracking';
  @override
  String get name => '话题追踪';
  @override
  String get description => '持续追踪话题动态，定期生成简报';

  @override
  Map<String, dynamic> get parameters => {
    'topic': {'type': 'string', 'required': true, 'description': '追踪话题'},
    'action': {'type': 'string', 'default': 'create', 'description': '操作: create/status/brief'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final topic = context.parameters['topic'] as String? ?? '';
    final action = context.parameters['action'] as String? ?? 'create';
    if (topic.isEmpty) return SkillResult.fail('请提供追踪话题');

    try {
      final response = await ApiGateway.instance.post(
        '/api/tracking/$action', body: {'topic': topic},
      );
      if (response.success && response.data != null) {
        return SkillResult.ok('话题追踪已设置', data: response.data);
      }
      return SkillResult.fail('话题追踪失败');
    } catch (e) {
      return SkillResult.fail('话题追踪错误: $e');
    }
  }
}

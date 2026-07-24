// ============================================================================
// 小酥 - 飞书技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 飞书集成技能
class LarkSkill extends BaseSkill {
  @override
  String get skillId => 'lark';
  @override
  String get name => '飞书集成';
  @override
  String get description => '飞书消息发送与文档操作';

  @override
  Map<String, dynamic> get parameters => {
    'action': {'type': 'string', 'required': true, 'description': '操作类型: send_message/create_doc'},
    'content': {'type': 'string', 'required': true, 'description': '内容'},
    'target': {'type': 'string', 'description': '目标（用户/群组/文档ID）'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final action = context.parameters['action'] as String? ?? '';
    final content = context.parameters['content'] as String? ?? '';

    if (action.isEmpty || content.isEmpty) {
      return SkillResult.fail('请提供操作类型和内容');
    }

    try {
      final response = await ApiGateway.instance.post(
        '/api/lark/$action',
        body: {'content': content, 'target': context.parameters['target']},
      );
      if (response.success) {
        return SkillResult.ok('飞书操作完成: $action');
      }
      return SkillResult.fail('飞书操作失败: ${response.error}');
    } catch (e) {
      return SkillResult.fail('飞书错误: $e');
    }
  }
}

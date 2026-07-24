// ============================================================================
// 小酥 - 邮件技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 邮件技能 - 发送邮件
class EmailSkill extends BaseSkill {
  @override
  String get skillId => 'email';
  @override
  String get name => '邮件助手';
  @override
  String get description => '发送和管理邮件';

  @override
  Map<String, dynamic> get parameters => {
    'to': {'type': 'string', 'required': true, 'description': '收件人邮箱'},
    'subject': {'type': 'string', 'required': true, 'description': '邮件主题'},
    'body': {'type': 'string', 'required': true, 'description': '邮件正文'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final to = context.parameters['to'] as String? ?? '';
    final subject = context.parameters['subject'] as String? ?? '';
    final body = context.parameters['body'] as String? ?? '';

    if (to.isEmpty || subject.isEmpty) return SkillResult.fail('请提供收件人和主题');

    try {
      final response = await ApiGateway.instance.post(
        '/api/email/send',
        body: {'to': to, 'subject': subject, 'body': body},
      );
      if (response.success) {
        return SkillResult.ok('邮件已发送到 $to');
      }
      return SkillResult.fail('发送失败: ${response.error}');
    } catch (e) {
      return SkillResult.fail('邮件发送错误: $e');
    }
  }
}

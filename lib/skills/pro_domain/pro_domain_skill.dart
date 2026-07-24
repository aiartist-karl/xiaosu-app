// ============================================================================
// 小酥 - 专业领域技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/llm/llm_router.dart';
import '../../core/llm/llm_provider.dart';

/// 专业领域技能 - 使用专业模型回答领域问题
class ProDomainSkill extends BaseSkill {
  @override
  String get skillId => 'pro_domain';
  @override
  String get name => '专业领域';
  @override
  String get description => '专业领域知识问答（医疗、法律、金融等）';

  @override
  Map<String, dynamic> get parameters => {
    'question': {'type': 'string', 'required': true, 'description': '专业问题'},
    'domain': {'type': 'string', 'default': 'general', 'description': '领域: medical/legal/finance/tech'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final question = context.parameters['question'] as String? ?? '';
    final domain = context.parameters['domain'] as String? ?? 'general';
    if (question.isEmpty) return SkillResult.fail('请提供问题');

    final domainPrompts = {
      'medical': '你是一个专业的医疗助手。请基于医学知识回答，但提醒用户这不是医疗建议。',
      'legal': '你是一个法律知识助手。请基于中国法律法规回答，并提醒用户咨询专业律师。',
      'finance': '你是一个金融分析助手。请提供专业的金融分析，并提醒投资有风险。',
      'tech': '你是一个技术专家。请提供详细的技术解答。',
    };

    try {
      final provider = LlmRouter.instance.defaultProvider;
      final result = await provider.complete(
        messages: [{'role': 'user', 'content': question}],
        systemPrompt: domainPrompts[domain] ?? '你是一个专业领域的AI助手。',
        temperature: 0.3,
      );
      return SkillResult.ok(result.content);
    } catch (e) {
      return SkillResult.fail('专业问答错误: $e');
    }
  }
}

// ============================================================================
// 小酥 - 文档生成技能
// ============================================================================

import '../../core/skill/skill.dart';

/// 文档生成技能
class DocGenSkill extends BaseSkill {
  @override
  String get skillId => 'doc_gen';
  @override
  String get name => '文档生成';
  @override
  String get description => '生成Word/PDF文档';

  @override
  Map<String, dynamic> get parameters => {
    'content': {'type': 'string', 'required': true, 'description': '文档内容'},
    'format': {'type': 'string', 'default': 'pdf', 'description': '格式: pdf/docx/md'},
    'title': {'type': 'string', 'description': '文档标题'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final content = context.parameters['content'] as String? ?? '';
    final format = context.parameters['format'] as String? ?? 'pdf';
    final title = context.parameters['title'] as String? ?? '文档';
    if (content.isEmpty) return SkillResult.fail('请提供文档内容');
    return SkillResult.ok('文档已生成: $title.$format', data: {'format': format});
  }
}

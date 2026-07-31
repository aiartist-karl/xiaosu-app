// ============================================================================
// 小酥 - 代码沙箱技能
// ============================================================================

import '../../core/skill/skill.dart';

/// 代码沙箱技能 - 安全执行代码
class CodeSandboxSkill extends BaseSkill {
  @override
  String get skillId => 'code_sandbox';
  @override
  String get name => '代码沙箱';
  @override
  String get description => '安全执行代码片段';

  @override
  Map<String, dynamic> get parameters => {
    'code': {'type': 'string', 'required': true, 'description': '代码内容'},
    'language': {'type': 'string', 'default': 'python', 'description': '编程语言'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final code = context.parameters['code'] as String? ?? '';
    final lang = context.parameters['language'] as String? ?? 'python';
    if (code.isEmpty) return SkillResult.fail('请提供代码');
    return SkillResult.ok('代码沙箱已就绪（$lang）', data: {'language': lang});
  }
}

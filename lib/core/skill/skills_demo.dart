// ============================================================================
// 小酥 - 示例技能集合
// ============================================================================

import 'skill.dart';

/// 联网搜索技能
class WebSearchSkill extends BaseSkill {
  WebSearchSkill();

  @override
  String get skillId => 'web_search';

  @override
  String get name => '联网搜索';

  @override
  String get description => '搜索互联网上的实时信息';

  @override
  Map<String, dynamic> get parameters => {
        'query': {'type': 'string', 'description': '搜索关键词', 'required': true},
      };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final query = context.parameters['query'] ?? '';
    // 模拟搜索延迟
    await Future.delayed(const Duration(milliseconds: 300));
    return SkillResult.ok(
      '搜索结果：关于「$query」的示例搜索结果，包含 5 条相关信息。',
      data: {'count': 5, 'query': query},
    );
  }
}

/// 图片生成技能
class ImageGenSkill extends BaseSkill {
  ImageGenSkill();

  @override
  String get skillId => 'image_gen';

  @override
  String get name => '图片生成';

  @override
  String get description => '根据文字描述生成图片';

  @override
  Map<String, dynamic> get parameters => {
        'prompt': {'type': 'string', 'description': '图片描述', 'required': true},
        'style': {'type': 'string', 'description': '风格（写实/动漫/油画）', 'required': false},
      };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final prompt = context.parameters['prompt'] ?? '';
    final style = context.parameters['style'] ?? '写实';
    await Future.delayed(const Duration(milliseconds: 500));
    return SkillResult.ok(
      '已生成图片：「$prompt」（风格：$style），分辨率 1024x1024',
      data: {'prompt': prompt, 'style': style, 'resolution': '1024x1024'},
    );
  }
}

/// 代码执行技能
class CodeExecSkill extends BaseSkill {
  CodeExecSkill();

  @override
  String get skillId => 'code_exec';

  @override
  String get name => '代码执行';

  @override
  String get description => '在沙箱环境中执行 Python 代码';

  @override
  Map<String, dynamic> get parameters => {
        'code': {'type': 'string', 'description': 'Python 代码', 'required': true},
        'timeout': {'type': 'int', 'description': '超时秒数', 'required': false},
      };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final code = context.parameters['code'] ?? '';
    await Future.delayed(const Duration(milliseconds: 200));
    // 模拟执行
    final lineCount = code.split('\n').length;
    return SkillResult.ok(
      '代码执行完成（$lineCount 行），无错误输出。',
      data: {'lines': lineCount, 'exit_code': 0},
    );
  }
}

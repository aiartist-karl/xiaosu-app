// ============================================================================
// 小酥 - 图表生成技能
// ============================================================================

import '../../core/skill/skill.dart';

/// 图表生成技能
class ChartSkill extends BaseSkill {
  @override
  String get skillId => 'chart';
  @override
  String get name => '图表生成';
  @override
  String get description => '根据数据生成可视化图表';

  @override
  Map<String, dynamic> get parameters => {
    'type': {'type': 'string', 'default': 'bar', 'description': '图表类型: bar/line/pie/scatter'},
    'data': {'type': 'object', 'required': true, 'description': '图表数据'},
    'title': {'type': 'string', 'description': '图表标题'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final chartType = context.parameters['type'] as String? ?? 'bar';
    final title = context.parameters['title'] as String? ?? '数据图表';
    return SkillResult.ok('图表已生成: $title ($chartType)', data: {'type': chartType});
  }
}

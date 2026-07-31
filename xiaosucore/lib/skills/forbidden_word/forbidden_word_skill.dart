// ============================================================================
// 小酥 - 违禁词检测技能
// ============================================================================

import '../../core/skill/skill.dart';

/// 违禁词检测技能
class ForbiddenWordSkill extends BaseSkill {
  @override
  String get skillId => 'forbidden_word';
  @override
  String get name => '违禁词检测';
  @override
  String get description => '检测文本中的平台违禁词';

  // 常见违禁词库（简化版）
  static const List<String> _forbiddenWords = [
    '最好', '最佳', '第一', '最强', '最优', '顶级', '极品', '绝对',
    '100%', '全网最低', '史上最强', '独一无二', '万能', '无敌',
    '秒杀', '抢购', '限时', '仅此一次', '错过不再',
  ];

  @override
  Map<String, dynamic> get parameters => {
    'text': {'type': 'string', 'required': true, 'description': '待检测文本'},
    'platform': {'type': 'string', 'default': 'all', 'description': '平台: xiaohongshu/douyin/gongzhonghao/all'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final text = context.parameters['text'] as String? ?? '';
    if (text.isEmpty) return SkillResult.fail('请提供待检测文本');

    final found = <String>[];
    for (final word in _forbiddenWords) {
      if (text.contains(word)) {
        found.add(word);
      }
    }

    if (found.isEmpty) {
      return SkillResult.ok('✅ 未检测到违禁词，文本安全');
    } else {
      return SkillResult.ok(
        '⚠️ 检测到 ${found.length} 个违禁词：${found.join("、")}\n建议修改后再发布',
        data: {'words': found, 'count': found.length},
      );
    }
  }
}

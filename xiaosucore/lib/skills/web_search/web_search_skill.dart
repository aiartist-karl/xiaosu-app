// ============================================================================
// 小酥 - 网络搜索技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 网络搜索技能
class WebSearchSkill extends BaseSkill {
  @override
  String get skillId => 'web_search';
  @override
  String get name => '网络搜索';
  @override
  String get description => '联网搜索获取最新信息';

  @override
  Map<String, dynamic> get parameters => {
    'query': {'type': 'string', 'required': true, 'description': '搜索关键词'},
    'maxResults': {'type': 'int', 'default': 5, 'description': '最大结果数'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final query = context.parameters['query'] as String? ?? '';
    if (query.isEmpty) return SkillResult.fail('请提供搜索关键词');

    try {
      final response = await ApiGateway.instance.get(
        '/api/search',
        queryParams: {
          'q': query,
          'limit': (context.parameters['maxResults'] ?? 5).toString(),
        },
      );

      if (response.success && response.data != null) {
        final results = response.data!['results'] as List? ?? [];
        final summary = results.map((r) => '- ${r['title']}: ${r['snippet']}').join('\n');
        return SkillResult.ok(summary.isEmpty ? '未找到相关结果' : summary, data: {'results': results});
      }
      return SkillResult.fail('搜索失败');
    } catch (e) {
      return SkillResult.fail('搜索错误: $e');
    }
  }
}

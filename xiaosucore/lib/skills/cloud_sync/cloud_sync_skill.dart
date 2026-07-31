// ============================================================================
// 小酥 - 云同步技能
// ============================================================================

import '../../core/skill/skill.dart';
import '../../core/gateway/api_gateway.dart';

/// 云同步技能
class CloudSyncSkill extends BaseSkill {
  @override
  String get skillId => 'cloud_sync';
  @override
  String get name => '云同步';
  @override
  String get description => '数据云端同步与备份';

  @override
  Map<String, dynamic> get parameters => {
    'action': {'type': 'string', 'required': true, 'description': '操作: upload/download/sync'},
    'dataType': {'type': 'string', 'default': 'all', 'description': '数据类型: conversations/memories/settings/all'},
  };

  @override
  Future<SkillResult> execute(SkillContext context) async {
    final action = context.parameters['action'] as String? ?? 'sync';
    final dataType = context.parameters['dataType'] as String? ?? 'all';

    try {
      final response = await ApiGateway.instance.post(
        '/api/sync/$action', body: {'dataType': dataType},
      );
      if (response.success) {
        return SkillResult.ok('云同步完成: $action');
      }
      return SkillResult.fail('同步失败: ${response.error}');
    } catch (e) {
      return SkillResult.fail('同步错误: $e');
    }
  }
}

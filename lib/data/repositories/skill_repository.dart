// ============================================================================
// 小酥 - 技能市场数据仓库层
// Phase 6: 封装 Coze Studio 技能市场 API 调用
// ============================================================================

import '../../core/gateway/api_gateway.dart';
import '../models/skill_model.dart';

/// 技能市场数据仓库 - 封装 Coze Studio 技能相关 API
///
/// 支持：
/// - 浏览技能市场列表
/// - 安装技能到当前空间
/// - 调用已安装技能
class SkillRepository {
  final ApiGateway _api;

  SkillRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // API 路径常量
  // ==========================================================================
  static const String _pathList = '/v3/skill/list';
  static const String _pathInstall = '/v3/skill/install';
  static const String _pathInvoke = '/v3/skill/invoke';

  // ==========================================================================
  // 技能市场操作
  // ==========================================================================

  /// 获取技能列表
  ///
  /// GET /v3/skill/list
  /// Query: page, page_size, keyword?, category?
  Future<ApiResponse<List<CozeSkill>>> fetchSkillList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _api.get(
        _pathList,
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取技能列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final skillsRaw = data['skills'] ?? data['data'];
      if (skillsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final skills = skillsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeSkill.fromJson(e))
          .toList();

      return ApiResponse.ok(skills);
    } catch (e) {
      return ApiResponse.fail('获取技能列表异常: ${e.toString()}');
    }
  }

  /// 安装技能
  ///
  /// POST /v3/skill/install
  /// Body: { skill_id }
  Future<ApiResponse<CozeSkill>> installSkill(String skillId) async {
    try {
      final response = await _api.post(
        _pathInstall,
        body: {'skill_id': skillId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '安装技能失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final skillData = data['skill'] as Map<String, dynamic>? ?? data;
      return ApiResponse.ok(CozeSkill.fromJson(skillData));
    } catch (e) {
      return ApiResponse.fail('安装技能异常: ${e.toString()}');
    }
  }

  /// 调用技能
  ///
  /// POST /v3/skill/invoke
  /// Body: { skill_id, params: {...} }
  Future<ApiResponse<Map<String, dynamic>>> invokeSkill(
    String skillId, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final body = <String, dynamic>{
        'skill_id': skillId,
        'params': params,
      };

      final response = await _api.post(
        _pathInvoke,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '调用技能失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final result = data['result'] as Map<String, dynamic>? ?? data;
      return ApiResponse.ok(result);
    } catch (e) {
      return ApiResponse.fail('调用技能异常: ${e.toString()}');
    }
  }

  /// 搜索技能（关键词搜索）
  Future<ApiResponse<List<CozeSkill>>> searchSkills(String query) async {
    return fetchSkillList(keyword: query);
  }

  /// 获取已安装技能列表
  Future<ApiResponse<List<CozeSkill>>> fetchInstalledSkills() async {
    final result = await fetchSkillList();
    if (!result.success) return result;

    final installed = result.data?.where((s) => s.status == CozeSkillStatus.installed).toList() ?? [];
    return ApiResponse.ok(installed);
  }
}

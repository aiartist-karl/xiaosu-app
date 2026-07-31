// ============================================================================
// 小酥 - 用户信息数据仓库层
// Phase 6: 封装 Coze Studio 用户信息 / 空间管理 API 调用
// ============================================================================

import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';
import '../models/user_model.dart';

/// 用户信息数据仓库 - 封装 Coze Studio 用户和空间相关 API
///
/// 认证方式：
/// - 用户信息：Session Cookie（内部 API）
/// - 空间管理：PAT Token（OpenAPI）或 JWT（workspace-service）
class UserRepository {
  final ApiGateway _api;

  UserRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // API 路径常量
  // ==========================================================================
  // 用户信息（内部 API，Session 认证）
  static const String _pathAccountInfo = '/api/passport/account/info/v2';
  // 空间管理（内部 API，Session 认证）
  static const String _pathSpaceList = '/api/space/list';
  static const String _pathSpaceInfo = '/api/space/info';

  // ==========================================================================
  // 用户信息
  // ==========================================================================

  /// 获取当前用户信息
  ///
  /// POST /api/passport/account/info/v2
  /// Auth: Session Cookie
  Future<ApiResponse<CozeUserInfo>> getUserInfo() async {
    try {
      final response = await _api.post(
        _pathAccountInfo,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取用户信息失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      // 解析用户信息
      // Coze Studio 返回格式: { user_id, name, avatar_url, ... }
      final userInfo = CozeUserInfo(
        userId: data['user_id'] as String? ?? '',
        name: data['name'] as String? ?? data['nickname'] as String? ?? '用户',
        avatar: data['avatar_url'] as String? ?? data['avatar'] as String?,
        email: data['email'] as String?,
        createdAt: data['created_at'] != null
            ? DateTime.tryParse(data['created_at'] as String)
            : null,
      );

      return ApiResponse.ok(userInfo);
    } catch (e) {
      return ApiResponse.fail('获取用户信息异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 空间管理
  // ==========================================================================

  /// 获取工作空间列表
  ///
  /// POST /api/space/list
  /// Auth: Session Cookie
  Future<ApiResponse<List<CozeWorkspace>>> getSpaceList() async {
    try {
      final response = await _api.post(
        _pathSpaceList,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取空间列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final spacesRaw = data['spaces'] ?? data['data'];
      if (spacesRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final spaces = spacesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeWorkspace(
                id: e['id'] as String? ?? e['space_id'] as String? ?? '',
                name: e['name'] as String? ?? '',
                description: e['description'] as String?,
                iconUrl: e['icon_url'] as String? ?? e['avatar_url'] as String?,
                role: e['role'] as String? ?? 'member',
                createdAt: e['created_at'] != null
                    ? DateTime.tryParse(e['created_at'] as String)
                    : null,
              ))
          .toList();

      return ApiResponse.ok(spaces);
    } catch (e) {
      return ApiResponse.fail('获取空间列表异常: ${e.toString()}');
    }
  }

  /// 获取空间详情
  ///
  /// POST /api/space/info
  /// Auth: Session Cookie
  /// Body: { space_id }
  Future<ApiResponse<CozeWorkspace>> getSpaceDetail(String spaceId) async {
    try {
      final response = await _api.post(
        _pathSpaceInfo,
        body: {'space_id': spaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取空间详情失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      final spaceData = data['space'] as Map<String, dynamic>? ?? data;
      final workspace = CozeWorkspace(
        id: spaceData['id'] as String? ?? spaceData['space_id'] as String? ?? '',
        name: spaceData['name'] as String? ?? '',
        description: spaceData['description'] as String?,
        iconUrl: spaceData['icon_url'] as String? ?? spaceData['avatar_url'] as String?,
        role: spaceData['role'] as String? ?? 'member',
        createdAt: spaceData['created_at'] != null
            ? DateTime.tryParse(spaceData['created_at'] as String)
            : null,
      );

      return ApiResponse.ok(workspace);
    } catch (e) {
      return ApiResponse.fail('获取空间详情异常: ${e.toString()}');
    }
  }

  /// 切换当前工作空间
  ///
  /// 更新本地缓存的当前空间 ID
  /// 实际切换由 AppConfig.cozeStudioSpaceId 更新完成
  Future<ApiResponse<void>> switchSpace(String spaceId) async {
    try {
      // 验证空间是否可访问
      final detailResult = await getSpaceDetail(spaceId);
      if (!detailResult.success) {
        return ApiResponse.fail('切换空间失败: ${detailResult.error}');
      }

      // 成功则返回（实际的空间切换由上层调用方更新 AppConfig）
      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('切换空间异常: ${e.toString()}');
    }
  }

  /// 登录并获取 Session
  ///
  /// POST /api/passport/web/email/login
  /// Body: { email, password }
  Future<ApiResponse<CozeUserInfo>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.login(email: email, password: password);

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '登录失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('登录响应数据为空');
      }

      // 登录成功后获取用户信息
      final userInfoResult = await getUserInfo();
      if (userInfoResult.success && userInfoResult.data != null) {
        return ApiResponse.ok(userInfoResult.data!);
      }

      // 如果获取用户信息失败，从登录响应中提取基本信息
      final userInfo = CozeUserInfo(
        userId: data['user_id'] as String? ?? AppConfig.cozeStudioUserId,
        name: data['name'] as String? ?? data['nickname'] as String? ?? '用户',
        avatar: data['avatar_url'] as String? ?? data['avatar'] as String?,
        email: email,
      );

      return ApiResponse.ok(userInfo);
    } catch (e) {
      return ApiResponse.fail('登录异常: ${e.toString()}');
    }
  }
}

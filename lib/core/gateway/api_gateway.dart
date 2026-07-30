// ============================================================================
// 小酥 - API Gateway（统一API管理）
// Phase 2: 使用 Session Cookie 认证，通过 CredentialManager 持久化
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'credential_manager.dart';

/// API响应封装
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode = 200,
  });

  factory ApiResponse.ok(T data) => ApiResponse(success: true, data: data);
  factory ApiResponse.fail(String error, {int statusCode = 400}) =>
      ApiResponse(success: false, error: error, statusCode: statusCode);
}

/// 认证类型
enum CozeAuthType {
  session, // Session Cookie（主要认证方式）
  pat,     // PAT Token (Bearer)（兼容）
  none,    // 无需认证
}

/// API Gateway - 使用 Session Cookie 认证
class ApiGateway {
  static final ApiGateway instance = ApiGateway._();
  ApiGateway._();

  final http.Client _client = http.Client();
  final String _baseUrl = AppConfig.serverHost;
  int _retryCount = 3;

  // 认证凭证
  String? _sessionKey;
  String? _patToken;

  // ==========================================================================
  // 认证管理
  // ==========================================================================

  /// 初始化：从 CredentialManager 恢复 Session Key
  /// 应用启动时调用
  Future<void> init() async {
    final savedSession = await CredentialManager.instance.getCozeSessionKey();
    if (savedSession != null && savedSession.isNotEmpty) {
      _sessionKey = savedSession;
    }
  }

  /// 设置 Session Key（用于内部 /api/ 接口 + OpenAPI）
  void setSessionKey(String sessionKey) {
    _sessionKey = sessionKey;
    // 同时持久化
    CredentialManager.instance.saveCozeSessionKey(sessionKey);
  }

  /// 获取当前 Session Key
  String? get sessionKey => _sessionKey;

  /// 设置 PAT Token（用于 OpenAPI v1/v3，兼容旧接口）
  void setPatToken(String token) {
    _patToken = token;
  }

  /// 获取当前 PAT Token
  String? get patToken => _patToken;

  /// 清除所有认证信息（登出）
  Future<void> logout() async {
    _patToken = null;
    _sessionKey = null;
    await CredentialManager.instance.clearCozeAuth();
  }

  /// 清除所有认证信息（内存）
  void clearAuth() {
    _patToken = null;
    _sessionKey = null;
  }

  /// 检查是否已认证（优先 session，兼容 pat）
  bool get isAuthenticated => _sessionKey != null && _sessionKey!.isNotEmpty;

  /// 设置重试次数
  void setRetryCount(int count) => _retryCount = count;

  // ==========================================================================
  // HTTP 方法
  // ==========================================================================

  /// GET请求
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    return _request('GET', path,
        headers: headers, queryParams: queryParams, authType: authType);
  }

  /// POST请求
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    return _request('POST', path, body: body, headers: headers, authType: authType);
  }

  /// PUT请求
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    return _request('PUT', path, body: body, headers: headers, authType: authType);
  }

  /// DELETE请求
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? headers,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    return _request('DELETE', path, headers: headers, authType: authType);
  }

  // ==========================================================================
  // SSE 流式请求（用于 /v3/chat 等流式接口）
  // ==========================================================================

  /// 发送 SSE 流式请求，返回原始响应流
  /// 调用方自行处理 SSE 解析
  Future<http.StreamedResponse> postStream(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final defaultHeaders = _buildHeaders(authType: authType, extraHeaders: headers);
    defaultHeaders['Accept'] = 'text/event-stream';

    final request = http.Request('POST', uri);
    request.headers.addAll(defaultHeaders);
    if (body != null) {
      request.body = jsonEncode(body);
    }

    return await _client.send(request);
  }

  // ==========================================================================
  // 登录认证（获取 Session Cookie）
  // ==========================================================================

  /// 使用邮箱密码登录 Coze Studio，获取 session_key
  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl${AppConfig.apiLogin}');
    final body = {
      'email': email,
      'password': password,
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 提取 Set-Cookie 中的 session_key
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null) {
          final sessionKey = _extractSessionKey(setCookies);
          if (sessionKey != null) {
            // 使用 setSessionKey 方法，会自动持久化
            setSessionKey(sessionKey);
          }
        }

        final data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        return ApiResponse.ok(data);
      } else {
        return ApiResponse.fail(
          '登录失败: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.fail('登录请求异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 构建请求头（根据认证类型）
  Map<String, String> _buildHeaders({
    CozeAuthType authType = CozeAuthType.session,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    switch (authType) {
      case CozeAuthType.pat:
        if (_patToken != null) {
          headers['Authorization'] = 'Bearer $_patToken';
        }
        break;
      case CozeAuthType.session:
        if (_sessionKey != null) {
          headers['Cookie'] = 'session_key=$_sessionKey';
        }
        break;
      case CozeAuthType.none:
        break;
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  /// 从 Set-Cookie 中提取 session_key
  String? _extractSessionKey(String setCookieHeader) {
    // 格式可能为: session_key=xxx; Path=/; HttpOnly
    final parts = setCookieHeader.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('session_key=')) {
        return trimmed.substring('session_key='.length);
      }
    }
    // 也可能在多个 cookie 中
    final cookies = setCookieHeader.split(',');
    for (final cookie in cookies) {
      final cookieParts = cookie.split(';');
      for (final part in cookieParts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('session_key=')) {
          return trimmed.substring('session_key='.length);
        }
      }
    }
    return null;
  }

  /// 解析 Coze Studio 错误响应
  String _parseCozeError(int statusCode, String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      // Coze Studio 错误格式: {"code": xxx, "msg": "error message"}
      if (data is Map<String, dynamic>) {
        final msg = data['msg'] ?? data['message'] ?? data['error'];
        if (msg != null) return 'Coze Studio 错误: $msg';
      }
    } catch (_) {}
    return '请求失败 (HTTP $statusCode)';
  }

  /// 通用请求方法（带重试 + Coze Studio 认证）
  Future<ApiResponse<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    CozeAuthType authType = CozeAuthType.session,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    final defaultHeaders = _buildHeaders(authType: authType, extraHeaders: headers);

    Exception? lastError;
    for (int attempt = 0; attempt < _retryCount; attempt++) {
      try {
        http.Response response;
        switch (method) {
          case 'GET':
            response = await _client.get(uri, headers: defaultHeaders);
            break;
          case 'POST':
            response = await _client.post(uri,
                headers: defaultHeaders,
                body: body != null ? jsonEncode(body) : null);
            break;
          case 'PUT':
            response = await _client.put(uri,
                headers: defaultHeaders,
                body: body != null ? jsonEncode(body) : null);
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: defaultHeaders);
            break;
          default:
            return ApiResponse.fail('不支持的HTTP方法: $method');
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = response.body.isNotEmpty
              ? jsonDecode(response.body) as Map<String, dynamic>
              : <String, dynamic>{};
          return ApiResponse.ok(data);
        } else {
          final errorMsg = _parseCozeError(response.statusCode, response.body);
          return ApiResponse.fail(errorMsg, statusCode: response.statusCode);
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _retryCount - 1) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    }

    return ApiResponse.fail('请求失败: ${lastError?.toString() ?? '未知错误'}');
  }

  /// 关闭
  void dispose() {
    _client.close();
  }
}

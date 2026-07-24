// ============================================================================
// 小酥 - API Gateway（统一API管理）
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

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

/// API Gateway
class ApiGateway {
  static final ApiGateway instance = ApiGateway._();
  ApiGateway._();

  final http.Client _client = http.Client();
  final String _baseUrl = AppConfig.serverHost;
  int _retryCount = 3;

  /// 设置重试次数
  void setRetryCount(int count) => _retryCount = count;

  /// GET请求
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    return _request('GET', path, headers: headers, queryParams: queryParams);
  }

  /// POST请求
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _request('POST', path, body: body, headers: headers);
  }

  /// PUT请求
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _request('PUT', path, body: body, headers: headers);
  }

  /// DELETE请求
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _request('DELETE', path, headers: headers);
  }

  /// 通用请求方法（带重试）
  Future<ApiResponse<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

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
          return ApiResponse.fail(
            '请求失败: ${response.statusCode}',
            statusCode: response.statusCode,
          );
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
  void dispose() => _client.close();
}

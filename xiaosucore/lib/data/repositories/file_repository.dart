// ============================================================================
// 小酥 - 文件管理数据仓库层
// Phase 6: 封装 Coze Studio 文件管理 API 调用
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';
import '../models/file_model.dart';

/// 文件管理数据仓库 - 封装 Coze Studio 文件相关 API
///
/// 支持：
/// - 文件上传（multipart/form-data）
/// - 文件列表查询
/// - 文件下载
class FileRepository {
  final ApiGateway _api;

  FileRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // API 路径常量
  // ==========================================================================
  static const String _pathUpload = '/v1/files/upload';
  static const String _pathList = '/v1/files';
  static const String _pathDownload = '/v1/files';

  // ==========================================================================
  // 文件操作
  // ==========================================================================

  /// 上传文件
  ///
  /// POST /v1/files/upload
  /// Content-Type: multipart/form-data
  /// Body: file (binary), purpose?
  Future<ApiResponse<CozeFile>> uploadFile({
    required String filePath,
    required List<int> fileBytes,
    String? fileName,
    String purpose = 'bot_file',
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.cozeStudioHost}$_pathUpload');

      // 构建 multipart 请求
      final request = http.MultipartRequest('POST', uri);

      // 添加认证头（使用 Session Cookie）
      final sessionKey = _api.sessionKey;
      if (sessionKey != null) {
        request.headers['Cookie'] = 'session_key=$sessionKey';
      }

      // 添加文件
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName ?? filePath.split('/').last,
      ));

      // 添加用途字段
      request.fields['purpose'] = purpose;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};

        final fileData = data['file'] as Map<String, dynamic>? ?? data;
        return ApiResponse.ok(CozeFile.fromJson(fileData));
      } else {
        return ApiResponse.fail(
          '上传文件失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.fail('上传文件异常: ${e.toString()}');
    }
  }

  /// 获取文件列表
  ///
  /// GET /v1/files
  /// Query: purpose?, page?, page_size?
  Future<ApiResponse<List<CozeFile>>> fetchFileList({
    String? purpose,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (purpose != null) queryParams['purpose'] = purpose;

      final response = await _api.get(
        _pathList,
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取文件列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(const []);
      }

      final filesRaw = data['files'] ?? data['data'];
      if (filesRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final files = filesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CozeFile.fromJson(e))
          .toList();

      return ApiResponse.ok(files);
    } catch (e) {
      return ApiResponse.fail('获取文件列表异常: ${e.toString()}');
    }
  }

  /// 获取文件下载 URL
  ///
  /// GET /v1/files/{file_id}/download
  Future<ApiResponse<String>> downloadFile(String fileId) async {
    try {
      final path = '$_pathDownload/$fileId/download';

      final response = await _api.get(
        path,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取下载链接失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      final downloadUrl = data?['url'] as String?;
      if (downloadUrl == null) {
        return ApiResponse.fail('未获取到下载链接');
      }

      return ApiResponse.ok(downloadUrl);
    } catch (e) {
      return ApiResponse.fail('获取下载链接异常: ${e.toString()}');
    }
  }

  /// 删除文件
  ///
  /// DELETE /v1/files/{file_id}
  Future<ApiResponse<void>> deleteFile(String fileId) async {
    try {
      final path = '$_pathDownload/$fileId';

      final response = await _api.delete(
        path,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '删除文件失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除文件异常: ${e.toString()}');
    }
  }
}

// ============================================================================
// 小酥 v2 - 知识库数据仓库层
// Phase 5: 封装 Coze Studio 知识库 API 调用
// ============================================================================

import '../models/knowledge_model.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 知识库数据仓库 - 封装所有知识库相关 API 调用
///
/// 支持两种认证方式：
/// - PAT Token: 用于 OpenAPI v1 端点（/v1/datasets 等）
/// - Session Cookie: 用于内部 API 端点（/api/knowledge/* 等）
class KnowledgeRepository {
  final ApiGateway _api;

  KnowledgeRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // 知识库 CRUD（OpenAPI v1 - PAT 认证）
  // ==========================================================================

  /// 获取知识库列表
  ///
  /// GET /v1/datasets
  Future<ApiResponse<List<KnowledgeDataset>>> fetchKnowledgeList({
    int page = 0,
    int pageSize = 20,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, String>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      final response = await _api.get(
        '/v1/datasets',
        queryParams: queryParams,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取知识库列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final datasetsRaw = data?['datasets'] ?? data?['data'];
      if (datasetsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final datasets = datasetsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => KnowledgeDataset.fromV1Api(e))
          .toList();

      return ApiResponse.ok(datasets);
    } catch (e) {
      return ApiResponse.fail('获取知识库列表异常: ${e.toString()}');
    }
  }

  /// 创建知识库
  ///
  /// POST /v1/datasets
  Future<ApiResponse<KnowledgeDataset>> createKnowledge({
    required String name,
    String description = '',
    KnowledgeFormatType formatType = KnowledgeFormatType.text,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'name': name,
        'description': description,
        'format_type': formatType.index,
      };

      final response = await _api.post(
        '/v1/datasets',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '创建知识库失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final datasetData = data?['data'] as Map<String, dynamic>? ?? data;
      if (datasetData == null) {
        return ApiResponse.fail('创建知识库返回数据为空');
      }

      final dataset = KnowledgeDataset.fromV1Api(datasetData);
      return ApiResponse.ok(dataset);
    } catch (e) {
      return ApiResponse.fail('创建知识库异常: ${e.toString()}');
    }
  }

  /// 更新知识库
  ///
  /// PUT /v1/datasets/:dataset_id
  Future<ApiResponse<KnowledgeDataset>> updateKnowledge(
    String datasetId, {
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };

      final response = await _api.put(
        '/v1/datasets/$datasetId',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '更新知识库失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final datasetData = data?['data'] as Map<String, dynamic>? ?? data;
      if (datasetData == null) {
        return ApiResponse.fail('更新知识库返回数据为空');
      }

      final dataset = KnowledgeDataset.fromV1Api(datasetData);
      return ApiResponse.ok(dataset);
    } catch (e) {
      return ApiResponse.fail('更新知识库异常: ${e.toString()}');
    }
  }

  /// 删除知识库
  ///
  /// DELETE /v1/datasets/:dataset_id
  Future<ApiResponse<void>> deleteKnowledge(String datasetId) async {
    try {
      final response = await _api.delete(
        '/v1/datasets/$datasetId',
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '删除知识库失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除知识库异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 知识库 CRUD（内部 API - Session 认证）
  // ==========================================================================

  /// 获取知识库列表（内部 API）
  ///
  /// POST /api/knowledge/list
  Future<ApiResponse<List<KnowledgeDataset>>> fetchKnowledgeListInternal({
    int page = 0,
    int pageSize = 20,
    String? keyword,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': page,
        'page_size': pageSize,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      };

      final response = await _api.post(
        '/api/knowledge/list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取知识库列表失败（内部 API）',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final listRaw = data?['knowledge_list'] ?? data?['datasets'] ?? data?['data'] ?? data?['list'];
      if (listRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final datasets = listRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => KnowledgeDataset.fromInternalApi(e))
          .toList();

      return ApiResponse.ok(datasets);
    } catch (e) {
      return ApiResponse.fail('获取知识库列表异常（内部 API）: ${e.toString()}');
    }
  }

  /// 获取知识库详情（内部 API）
  ///
  /// POST /api/knowledge/detail
  Future<ApiResponse<KnowledgeDataset>> fetchKnowledgeDetail(String datasetId) async {
    try {
      final response = await _api.post(
        '/api/knowledge/detail',
        body: {
          'dataset_id': datasetId,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取知识库详情失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final datasetData = data?['data'] as Map<String, dynamic>? ?? data;
      if (datasetData == null) {
        return ApiResponse.fail('知识库详情数据为空');
      }

      final dataset = KnowledgeDataset.fromInternalApi(datasetData);
      return ApiResponse.ok(dataset);
    } catch (e) {
      return ApiResponse.fail('获取知识库详情异常: ${e.toString()}');
    }
  }

  /// 创建知识库（内部 API）
  ///
  /// POST /api/knowledge/create
  Future<ApiResponse<KnowledgeDataset>> createKnowledgeInternal({
    required String name,
    String description = '',
    KnowledgeFormatType formatType = KnowledgeFormatType.text,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'name': name,
        'description': description,
        'format_type': formatType.index,
      };

      final response = await _api.post(
        '/api/knowledge/create',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '创建知识库失败（内部 API）',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final datasetData = data?['data'] as Map<String, dynamic>? ?? data;
      if (datasetData == null) {
        return ApiResponse.fail('创建知识库返回数据为空（内部 API）');
      }

      final dataset = KnowledgeDataset.fromInternalApi(datasetData);
      return ApiResponse.ok(dataset);
    } catch (e) {
      return ApiResponse.fail('创建知识库异常（内部 API）: ${e.toString()}');
    }
  }

  /// 删除知识库（内部 API）
  ///
  /// POST /api/knowledge/delete
  Future<ApiResponse<void>> deleteKnowledgeInternal(String datasetId) async {
    try {
      final response = await _api.post(
        '/api/knowledge/delete',
        body: {
          'dataset_id': datasetId,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '删除知识库失败（内部 API）',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除知识库异常（内部 API）: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 文档管理（内部 API）
  // ==========================================================================

  /// 获取文档列表
  ///
  /// POST /api/knowledge/document/list
  Future<ApiResponse<List<KnowledgeDocument>>> fetchDocumentList(
    String datasetId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': page,
        'page_size': pageSize,
      };

      final response = await _api.post(
        '/api/knowledge/document/list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取文档列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final docsRaw = data?['document_list'] ?? data?['documents'] ?? data?['data'] ?? data?['list'];
      if (docsRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final docs = docsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => KnowledgeDocument.fromApi(e))
          .toList();

      return ApiResponse.ok(docs);
    } catch (e) {
      return ApiResponse.fail('获取文档列表异常: ${e.toString()}');
    }
  }

  /// 上传/创建文档
  ///
  /// POST /api/knowledge/document/create
  ///
  /// 支持两种上传方式：
  /// 1. 文件上传：传 filePath / fileContent
  /// 2. URL 导入：传 url
  Future<ApiResponse<KnowledgeDocument>> uploadDocument(
    String datasetId, {
    String? fileName,
    String? fileContent,
    String? fileUrl,
    String? documentType, // pdf / docx / txt / url / csv / xlsx
  }) async {
    try {
      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'space_id': AppConfig.cozeStudioSpaceId,
        if (fileName != null) 'name': fileName,
        if (fileName != null) 'file_name': fileName,
        if (fileContent != null) 'content': fileContent,
        if (fileContent != null) 'text': fileContent,
        if (fileUrl != null) 'url': fileUrl,
        if (documentType != null) 'type': documentType,
        if (documentType != null) 'document_type': documentType,
      };

      final response = await _api.post(
        '/api/knowledge/document/create',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '上传文档失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final docData = data?['data'] as Map<String, dynamic>? ?? data;
      if (docData == null) {
        return ApiResponse.fail('上传文档返回数据为空');
      }

      final doc = KnowledgeDocument.fromApi(docData);
      return ApiResponse.ok(doc);
    } catch (e) {
      return ApiResponse.fail('上传文档异常: ${e.toString()}');
    }
  }

  /// 通过 OpenAPI 创建文档
  ///
  /// POST /open_api/knowledge/document/create
  Future<ApiResponse<KnowledgeDocument>> uploadDocumentViaOpenApi(
    String datasetId, {
    required String documentName,
    String? textContent,
    String? sourceUrl,
    String documentType = 'text',
  }) async {
    try {
      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'document_name': documentName,
        'document_type': documentType,
        if (textContent != null) 'content': textContent,
        if (textContent != null) 'text': textContent,
        if (sourceUrl != null) 'source_url': sourceUrl,
        'space_id': AppConfig.cozeStudioSpaceId,
      };

      final response = await _api.post(
        '/open_api/knowledge/document/create',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '通过 OpenAPI 上传文档失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final docData = data?['data'] as Map<String, dynamic>? ?? data;
      if (docData == null) {
        return ApiResponse.fail('OpenAPI 上传文档返回数据为空');
      }

      final doc = KnowledgeDocument.fromApi(docData);
      return ApiResponse.ok(doc);
    } catch (e) {
      return ApiResponse.fail('通过 OpenAPI 上传文档异常: ${e.toString()}');
    }
  }

  /// 删除文档
  ///
  /// POST /api/knowledge/document/delete
  Future<ApiResponse<void>> deleteDocument(
    String datasetId,
    String documentId,
  ) async {
    try {
      final response = await _api.post(
        '/api/knowledge/document/delete',
        body: {
          'dataset_id': datasetId,
          'document_id': documentId,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '删除文档失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除文档异常: ${e.toString()}');
    }
  }

  /// 获取文档处理进度
  ///
  /// POST /api/knowledge/document/progress/get
  Future<ApiResponse<Map<String, dynamic>>> getDocumentProgress(
    String datasetId,
    List<String> documentIds,
  ) async {
    try {
      final response = await _api.post(
        '/api/knowledge/document/progress/get',
        body: {
          'dataset_id': datasetId,
          'document_ids': documentIds,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取文档处理进度失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(response.data ?? {});
    } catch (e) {
      return ApiResponse.fail('获取文档处理进度异常: ${e.toString()}');
    }
  }

  /// 文档重新分片
  ///
  /// POST /api/knowledge/document/resegment
  Future<ApiResponse<void>> resegmentDocument(String datasetId, String documentId) async {
    try {
      final response = await _api.post(
        '/api/knowledge/document/resegment',
        body: {
          'dataset_id': datasetId,
          'document_id': documentId,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '文档重新分片失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('文档重新分片异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 知识检索
  // ==========================================================================

  /// 知识检索（语义搜索 + 相似度排序）
  ///
  /// POST /api/knowledge/search
  /// 支持 topK、相似度阈值、元数据过滤
  Future<ApiResponse<KnowledgeSearchResult>> searchKnowledge(
    String datasetId,
    String query, {
    int topK = 5,
    double? scoreThreshold,
    List<String>? documentIds,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'query': query,
        'top_k': topK,
        'space_id': AppConfig.cozeStudioSpaceId,
        if (scoreThreshold != null) 'score_threshold': scoreThreshold,
        if (documentIds != null && documentIds.isNotEmpty) 'document_ids': documentIds,
        if (filters != null) 'filters': filters,
        'rerank': true, // 启用重排序以获得更好的相似度结果
      };

      final response = await _api.post(
        '/api/knowledge/search',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '知识检索失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.ok(KnowledgeSearchResult(
          chunks: const [],
          query: query,
        ));
      }

      final result = KnowledgeSearchResult.fromApi(data, query: query);
      return ApiResponse.ok(result);
    } catch (e) {
      return ApiResponse.fail('知识检索异常: ${e.toString()}');
    }
  }

  /// 多知识库联合检索
  ///
  /// 在多个知识库中同时搜索，结果按相似度统一排序
  Future<ApiResponse<KnowledgeSearchResult>> searchMultiKnowledge(
    List<String> datasetIds,
    String query, {
    int topK = 5,
    double? scoreThreshold,
  }) async {
    try {
      final allChunks = <_ScoredChunk>[];

      // 并行请求所有知识库
      final futures = datasetIds.map((datasetId) async {
        final result = await searchKnowledge(
          datasetId,
          query,
          topK: topK,
          scoreThreshold: scoreThreshold,
        );
        return result;
      });

      final results = await Future.wait(futures);

      for (final result in results) {
        if (result.success && result.data != null) {
          for (final chunk in result.data!.chunks) {
            allChunks.add(_ScoredChunk(chunk: chunk));
          }
        }
      }

      // 按相似度降序排序，取 topK
      allChunks.sort((a, b) => b.chunk.score.compareTo(a.chunk.score));
      final topChunks = allChunks.take(topK).map((e) => e.chunk).toList();

      return ApiResponse.ok(KnowledgeSearchResult(
        chunks: topChunks,
        query: query,
        totalCount: topChunks.length,
      ));
    } catch (e) {
      return ApiResponse.fail('多知识库检索异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 切片管理
  // ==========================================================================

  /// 获取切片列表
  ///
  /// POST /api/knowledge/slice/list
  Future<ApiResponse<List<KnowledgeChunk>>> fetchSliceList({
    required String datasetId,
    required String documentId,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'document_id': documentId,
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': page,
        'page_size': pageSize,
      };

      final response = await _api.post(
        '/api/knowledge/slice/list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取切片列表失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final slicesRaw = data?['slice_list'] ?? data?['chunks'] ?? data?['data'];
      if (slicesRaw is! List) {
        return ApiResponse.ok(const []);
      }

      final slices = slicesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => KnowledgeChunk.fromApi(e))
          .toList();

      return ApiResponse.ok(slices);
    } catch (e) {
      return ApiResponse.fail('获取切片列表异常: ${e.toString()}');
    }
  }

  /// 创建/更新切片
  ///
  /// POST /api/knowledge/slice/create 或 POST /api/knowledge/slice/update
  Future<ApiResponse<KnowledgeChunk>> upsertSlice({
    required String datasetId,
    required String documentId,
    required String content,
    String? sliceId, // 有则为更新，无则为创建
  }) async {
    try {
      final path = sliceId != null
          ? '/api/knowledge/slice/update'
          : '/api/knowledge/slice/create';

      final body = <String, dynamic>{
        'dataset_id': datasetId,
        'document_id': documentId,
        'content': content,
        'space_id': AppConfig.cozeStudioSpaceId,
        if (sliceId != null) 'slice_id': sliceId,
      };

      final response = await _api.post(
        path,
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '操作切片失败',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final sliceData = data?['data'] as Map<String, dynamic>? ?? data;
      if (sliceData == null) {
        return ApiResponse.fail('操作切片返回数据为空');
      }

      final slice = KnowledgeChunk.fromApi(sliceData);
      return ApiResponse.ok(slice);
    } catch (e) {
      return ApiResponse.fail('操作切片异常: ${e.toString()}');
    }
  }

  /// 删除切片
  ///
  /// POST /api/knowledge/slice/delete
  Future<ApiResponse<void>> deleteSlice(String datasetId, String sliceId) async {
    try {
      final response = await _api.post(
        '/api/knowledge/slice/delete',
        body: {
          'dataset_id': datasetId,
          'slice_id': sliceId,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '删除切片失败',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.ok(null);
    } catch (e) {
      return ApiResponse.fail('删除切片异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 图片知识库
  // ==========================================================================

  /// 获取图片知识库列表
  ///
  /// POST /api/knowledge/photo/list
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchPhotoKnowledgeList(
    String datasetId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.post(
        '/api/knowledge/photo/list',
        body: {
          'dataset_id': datasetId,
          'space_id': AppConfig.cozeStudioSpaceId,
          'page_index': page,
          'page_size': pageSize,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(
          response.error ?? '获取图片知识库列表失败',
          statusCode: response.statusCode,
        );
      }

      final photos = response.data?['photo_list'] ?? response.data?['data'];
      if (photos is List) {
        return ApiResponse.ok(
          photos.whereType<Map<String, dynamic>>().toList(),
        );
      }

      return ApiResponse.ok(const []);
    } catch (e) {
      return ApiResponse.fail('获取图片知识库列表异常: ${e.toString()}');
    }
  }
}

/// 内部辅助类 - 带分数的切片用于排序
class _ScoredChunk {
  final KnowledgeChunk chunk;
  _ScoredChunk({required this.chunk});
}

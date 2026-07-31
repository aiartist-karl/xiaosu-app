// ============================================================================
// 小酥 v2 - 知识库管理器
// Phase 5: 知识库统一管理，支持多知识库检索与文档管理
// ============================================================================

import '../../data/models/knowledge_model.dart';
import '../../data/repositories/knowledge_repository.dart';

/// 知识库管理器
///
/// 职责：
/// 1. 管理知识库列表（缓存 + 远程同步）
/// 2. 文档上传、删除、状态追踪
/// 3. 知识检索（单库/多库联合检索，相似度排序）
/// 4. 切片管理
class KnowledgeManager {
  static final KnowledgeManager instance = KnowledgeManager._();
  KnowledgeManager._();

  final KnowledgeRepository _repo = KnowledgeRepository();

  // ==========================================================================
  // 缓存
  // ==========================================================================

  /// 知识库缓存 (dataset_id -> KnowledgeDataset)
  final Map<String, KnowledgeDataset> _datasetCache = {};

  /// 文档缓存 (dataset_id -> [KnowledgeDocument])
  final Map<String, List<KnowledgeDocument>> _documentCache = {};

  /// 是否已同步
  bool _isSynced = false;

  /// 知识库是否可用
  bool get isAvailable => _isSynced && _datasetCache.isNotEmpty;

  // ==========================================================================
  // 知识库列表管理
  // ==========================================================================

  /// 同步知识库列表
  ///
  /// 优先使用 OpenAPI v1（PAT），失败后回退到内部 API（Session）
  Future<bool> syncKnowledgeList() async {
    try {
      // 1. 尝试 OpenAPI v1
      final v1Result = await _repo.fetchKnowledgeList();
      if (v1Result.success && v1Result.data != null && v1Result.data!.isNotEmpty) {
        _datasetCache.clear();
        for (final ds in v1Result.data!) {
          _datasetCache[ds.id] = ds;
        }
        _isSynced = true;
        return true;
      }

      // 2. 回退到内部 API
      final internalResult = await _repo.fetchKnowledgeListInternal();
      if (internalResult.success && internalResult.data != null) {
        _datasetCache.clear();
        for (final ds in internalResult.data!) {
          _datasetCache[ds.id] = ds;
        }
        _isSynced = true;
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取所有知识库
  List<KnowledgeDataset> get allDatasets =>
      _datasetCache.values.toList();

  /// 获取知识库详情（优先缓存）
  Future<KnowledgeDataset?> getDataset(String datasetId) async {
    if (_datasetCache.containsKey(datasetId)) {
      return _datasetCache[datasetId];
    }

    // 从 API 获取
    try {
      final result = await _repo.fetchKnowledgeDetail(datasetId);
      if (result.success && result.data != null) {
        _datasetCache[datasetId] = result.data!;
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 创建知识库
  Future<KnowledgeDataset?> createDataset({
    required String name,
    String description = '',
    KnowledgeFormatType formatType = KnowledgeFormatType.text,
  }) async {
    try {
      // 优先使用 OpenAPI v1
      final result = await _repo.createKnowledge(
        name: name,
        description: description,
        formatType: formatType,
      );

      if (result.success && result.data != null) {
        _datasetCache[result.data!.id] = result.data!;
        return result.data!;
      }

      // 回退到内部 API
      final internalResult = await _repo.createKnowledgeInternal(
        name: name,
        description: description,
        formatType: formatType,
      );

      if (internalResult.success && internalResult.data != null) {
        _datasetCache[internalResult.data!.id] = internalResult.data!;
        return internalResult.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 更新知识库
  Future<bool> updateDataset(
    String datasetId, {
    String? name,
    String? description,
  }) async {
    try {
      final result = await _repo.updateKnowledge(
        datasetId,
        name: name,
        description: description,
      );

      if (result.success && result.data != null) {
        _datasetCache[datasetId] = result.data!;
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  /// 删除知识库
  Future<bool> deleteDataset(String datasetId) async {
    try {
      // 优先 OpenAPI v1
      final result = await _repo.deleteKnowledge(datasetId);
      if (result.success) {
        _datasetCache.remove(datasetId);
        _documentCache.remove(datasetId);
        return true;
      }

      // 回退到内部 API
      final internalResult = await _repo.deleteKnowledgeInternal(datasetId);
      if (internalResult.success) {
        _datasetCache.remove(datasetId);
        _documentCache.remove(datasetId);
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  // ==========================================================================
  // 文档管理
  // ==========================================================================

  /// 获取知识库下的文档列表
  Future<List<KnowledgeDocument>> getDocuments(String datasetId) async {
    if (_documentCache.containsKey(datasetId)) {
      return _documentCache[datasetId]!;
    }

    try {
      final result = await _repo.fetchDocumentList(datasetId);
      if (result.success && result.data != null) {
        _documentCache[datasetId] = result.data!;
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 上传文档到知识库
  ///
  /// 支持三种方式：
  /// 1. 文本内容直接上传
  /// 2. URL 导入
  /// 3. OpenAPI 方式
  Future<KnowledgeDocument?> uploadDocument(
    String datasetId, {
    String? fileName,
    String? fileContent,
    String? fileUrl,
    String? documentType,
  }) async {
    try {
      final result = await _repo.uploadDocument(
        datasetId,
        fileName: fileName,
        fileContent: fileContent,
        fileUrl: fileUrl,
        documentType: documentType,
      );

      if (result.success && result.data != null) {
        // 更新文档缓存
        _documentCache[datasetId] ??= [];
        _documentCache[datasetId]!.add(result.data!);

        // 更新知识库文档计数
        final ds = _datasetCache[datasetId];
        if (ds != null) {
          _datasetCache[datasetId] = ds.copyWith(
            documentCount: ds.documentCount + 1,
          );
        }

        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 删除文档
  Future<bool> deleteDocument(String datasetId, String documentId) async {
    try {
      final result = await _repo.deleteDocument(datasetId, documentId);
      if (result.success) {
        // 更新缓存
        _documentCache[datasetId]?.removeWhere((d) => d.id == documentId);

        final ds = _datasetCache[datasetId];
        if (ds != null && ds.documentCount > 0) {
          _datasetCache[datasetId] = ds.copyWith(
            documentCount: ds.documentCount - 1,
          );
        }

        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  /// 获取文档处理进度
  Future<Map<String, dynamic>?> getDocumentProgress(
    String datasetId,
    List<String> documentIds,
  ) async {
    try {
      final result = await _repo.getDocumentProgress(datasetId, documentIds);
      if (result.success) {
        return result.data;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 重新分片文档
  Future<bool> resegmentDocument(String datasetId, String documentId) async {
    try {
      final result = await _repo.resegmentDocument(datasetId, documentId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // 知识检索
  // ==========================================================================

  /// 单知识库检索
  ///
  /// 支持参数：
  /// - topK: 返回最多 K 个最相似的切片
  /// - scoreThreshold: 相似度阈值（0~1），低于此分数的结果会被过滤
  /// - documentIds: 限定在指定文档中检索
  Future<KnowledgeSearchResult?> searchKnowledge(
    String datasetId,
    String query, {
    int topK = 5,
    double? scoreThreshold,
    List<String>? documentIds,
  }) async {
    try {
      final result = await _repo.searchKnowledge(
        datasetId,
        query,
        topK: topK,
        scoreThreshold: scoreThreshold,
        documentIds: documentIds,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 多知识库联合检索
  ///
  /// 在多个知识库中同时搜索，结果按相似度统一排序后取 topK
  /// 适合用户需要跨多个知识库获取信息的场景
  Future<KnowledgeSearchResult?> searchMultiKnowledge(
    List<String> datasetIds,
    String query, {
    int topK = 5,
    double? scoreThreshold,
  }) async {
    try {
      if (datasetIds.isEmpty) return null;

      final result = await _repo.searchMultiKnowledge(
        datasetIds,
        query,
        topK: topK,
        scoreThreshold: scoreThreshold,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 在所有知识库中检索（使用缓存中的全部知识库 ID）
  Future<KnowledgeSearchResult?> searchAllKnowledge(
    String query, {
    int topK = 5,
    double? scoreThreshold,
  }) async {
    if (_datasetCache.isEmpty) {
      // 先尝试同步
      final synced = await syncKnowledgeList();
      if (!synced) return null;
    }

    final datasetIds = _datasetCache.keys.toList();
    if (datasetIds.isEmpty) return null;

    return searchMultiKnowledge(
      datasetIds,
      query,
      topK: topK,
      scoreThreshold: scoreThreshold,
    );
  }

  // ==========================================================================
  // 切片管理
  // ==========================================================================

  /// 获取文档切片列表
  Future<List<KnowledgeChunk>> getSlices({
    required String datasetId,
    required String documentId,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final result = await _repo.fetchSliceList(
        datasetId: datasetId,
        documentId: documentId,
        page: page,
        pageSize: pageSize,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 创建切片
  Future<KnowledgeChunk?> createSlice({
    required String datasetId,
    required String documentId,
    required String content,
  }) async {
    try {
      final result = await _repo.upsertSlice(
        datasetId: datasetId,
        documentId: documentId,
        content: content,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 更新切片
  Future<bool> updateSlice({
    required String datasetId,
    required String documentId,
    required String sliceId,
    required String content,
  }) async {
    try {
      final result = await _repo.upsertSlice(
        datasetId: datasetId,
        documentId: documentId,
        content: content,
        sliceId: sliceId,
      );

      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// 删除切片
  Future<bool> deleteSlice(String datasetId, String sliceId) async {
    try {
      final result = await _repo.deleteSlice(datasetId, sliceId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // 图片知识库
  // ==========================================================================

  /// 获取图片知识库内容
  Future<List<Map<String, dynamic>>> getPhotoKnowledge(
    String datasetId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final result = await _repo.fetchPhotoKnowledgeList(
        datasetId,
        page: page,
        pageSize: pageSize,
      );

      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  // ==========================================================================
  // 综合查询
  // ==========================================================================

  /// 搜索知识库（按名称/描述）
  List<KnowledgeDataset> searchDatasets(String query) {
    final q = query.toLowerCase();
    return _datasetCache.values.where((ds) =>
        ds.name.toLowerCase().contains(q) ||
        ds.description.toLowerCase().contains(q)
    ).toList();
  }

  /// 获取知识库统计信息
  Map<String, dynamic> get stats {
    int totalDocs = 0;
    int totalChars = 0;
    for (final ds in _datasetCache.values) {
      totalDocs += ds.documentCount;
      totalChars += ds.totalCharCount;
    }

    return {
      'total_datasets': _datasetCache.length,
      'total_documents': totalDocs,
      'total_chars': totalChars,
      'is_synced': _isSynced,
      'format_types': _datasetCache.values
          .map((ds) => ds.formatType.label)
          .toSet()
          .toList(),
    };
  }

  /// 清除缓存
  void clearCache() {
    _datasetCache.clear();
    _documentCache.clear();
    _isSynced = false;
  }
}

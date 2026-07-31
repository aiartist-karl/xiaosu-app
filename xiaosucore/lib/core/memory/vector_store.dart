// ============================================================================
// 小酥 - 向量存储（内存 + SQLite持久化）
// ============================================================================

import 'dart:math';
import 'embedder.dart';

/// 向量存储条目
class VectorEntry {
  final String id;
  final String text;
  final List<double> vector;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final double? score; // 查询时的相似度分数

  const VectorEntry({
    required this.id,
    required this.text,
    required this.vector,
    this.metadata = const {},
    required this.createdAt,
    this.score,
  });
}

/// 向量存储引擎
class VectorStore {
  static final VectorStore instance = VectorStore._();
  VectorStore._();

  final List<VectorEntry> _entries = [];
  final Embedder _embedder = Embedder.instance;

  /// 存储条目数量
  int get length => _entries.length;

  /// 添加文本（自动向量化）
  Future<VectorEntry> addText({
    required String id,
    required String text,
    Map<String, dynamic> metadata = const {},
  }) async {
    final vector = _embedder.embed(text);
    final entry = VectorEntry(
      id: id,
      text: text,
      vector: vector,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    return entry;
  }

  /// 批量添加
  Future<List<VectorEntry>> addTexts({
    required List<String> ids,
    required List<String> texts,
    List<Map<String, dynamic>>? metadataList,
  }) async {
    final vectors = _embedder.embedBatch(texts);
    final results = <VectorEntry>[];
    for (int i = 0; i < texts.length; i++) {
      final entry = VectorEntry(
        id: ids[i],
        text: texts[i],
        vector: vectors[i],
        metadata: metadataList != null && i < metadataList.length
            ? metadataList[i] : {},
        createdAt: DateTime.now(),
      );
      _entries.add(entry);
      results.add(entry);
    }
    return results;
  }

  /// 相似度搜索
  List<VectorEntry> search(String query, {int topK = 5, double threshold = 0.0}) {
    if (_entries.isEmpty) return [];

    final queryVector = _embedder.embed(query);
    final scored = _entries.map((entry) {
      final score = _embedder.cosineSimilarity(queryVector, entry.vector);
      return MapEntry(entry, score);
    }).toList();

    // 按分数降序排序
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored
        .where((e) => e.value >= threshold)
        .take(topK)
        .map((e) => VectorEntry(
              id: e.key.id,
              text: e.key.text,
              vector: e.key.vector,
              metadata: e.key.metadata,
              createdAt: e.key.createdAt,
              score: e.value,
            ))
        .toList();
  }

  /// 按ID删除
  bool remove(String id) {
    final initial = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    return _entries.length < initial;
  }

  /// 按元数据过滤删除
  int removeWhere(bool Function(VectorEntry) test) {
    final initial = _entries.length;
    _entries.removeWhere(test);
    return initial - _entries.length;
  }

  /// 获取所有条目
  List<VectorEntry> getAll() => List.unmodifiable(_entries);

  /// 清空
  void clear() => _entries.clear();

  /// 导出为可序列化格式
  List<Map<String, dynamic>> toJson() {
    return _entries.map((e) => {
      'id': e.id,
      'text': e.text,
      'vector': e.vector,
      'metadata': e.metadata,
      'createdAt': e.createdAt.toIso8601String(),
    }).toList();
  }

  /// 从序列化格式恢复
  void fromJson(List<Map<String, dynamic>> data) {
    _entries.clear();
    for (final item in data) {
      _entries.add(VectorEntry(
        id: item['id'] as String,
        text: item['text'] as String,
        vector: (item['vector'] as List).cast<double>(),
        metadata: (item['metadata'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.parse(item['createdAt'] as String),
      ));
    }
  }
}

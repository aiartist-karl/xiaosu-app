/// ============================================================================
/// 小酥 AI 助手 — 向量存储 (sqlite-vec)
/// ============================================================================
/// 封装 sqlite-vec 扩展的向量检索能力，包括：
///   - KNN 向量检索（余弦相似度）
///   - 批量插入
///   - 相似度阈值过滤
///   - 记忆类型过滤
///   - 向量索引管理
/// ============================================================================

import 'dart:math' as math;

import '../common/models.dart';

// ———————————————————————————————— 向量记录 ————————————————————————————————

/// 向量存储中的记录
///
/// 每条记录包含唯一 ID、原始文本、向量化表示、元数据等。
class VectorRecord {
  /// 记录唯一 ID（与记忆表中的 ID 对应）
  final String id;

  /// 原始文本内容
  final String content;

  /// 向量表示
  final List<double> vector;

  /// 记忆类型（用于过滤）
  final MemoryType memoryType;

  /// 关联的会话 ID
  final String? sessionId;

  /// 创建时间
  final DateTime createdAt;

  /// 最近访问时间
  final DateTime? lastAccessedAt;

  /// 访问次数
  final int accessCount;

  /// 重要度评分 (0.0 ~ 1.0)
  final double importance;

  /// 附加元数据
  final Map<String, dynamic> metadata;

  const VectorRecord({
    required this.id,
    required this.content,
    required this.vector,
    this.memoryType = MemoryType.episodic,
    this.sessionId,
    required this.createdAt,
    this.lastAccessedAt,
    this.accessCount = 0,
    this.importance = 0.5,
    this.metadata = const {},
  });

  /// 转为 Map 便于存储
  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'vector': vector,
        'memory_type': memoryType.name,
        'session_id': sessionId,
        'created_at': createdAt.toIso8601String(),
        'last_accessed_at': lastAccessedAt?.toIso8601String(),
        'access_count': accessCount,
        'importance': importance,
        'metadata': metadata,
      };
}

/// 记忆类型
enum MemoryType {
  /// 工作记忆 — 当前对话上下文
  working,

  /// 情景记忆 — 历史对话片段
  episodic,

  /// 语义记忆 — 提取的知识和事实
  semantic,
}

// ———————————————————————————————— 检索结果 ————————————————————————————————

/// 向量检索结果
class VectorSearchResult {
  /// 匹配的记录
  final VectorRecord record;

  /// 相似度评分 (0.0 ~ 1.0)
  final double similarity;

  /// 混合检索的综合评分（RRF 融合后）
  final double? rrfScore;

  const VectorSearchResult({
    required this.record,
    required this.similarity,
    this.rrfScore,
  });

  @override
  String toString() =>
      'VectorSearchResult(id=${record.id}, sim=${similarity.toStringAsFixed(3)}, '
      'type=${record.memoryType.name})';
}

// ———————————————————————————————— 向量存储 ————————————————————————————————

/// 向量存储引擎
///
/// 基于 sqlite-vec 实现的向量存储，支持 KNN 检索、
/// 类型过滤、阈值过滤等。
///
/// sqlite-vec 是 SQLite 的轻量级向量搜索扩展，
/// 使用暴力搜索（flat index），适合中小规模数据（< 100K 条）。
///
/// 表结构：
/// ```sql
/// CREATE TABLE IF NOT EXISTS vectors (
///   id TEXT PRIMARY KEY,
///   content TEXT NOT NULL,
///   memory_type TEXT NOT NULL DEFAULT 'episodic',
///   session_id TEXT,
///   created_at TEXT NOT NULL,
///   last_accessed_at TEXT,
///   access_count INTEGER DEFAULT 0,
///   importance REAL DEFAULT 0.5,
///   metadata TEXT DEFAULT '{}'
/// );
///
/// -- sqlite-vec 虚拟表
/// CREATE VIRTUAL TABLE IF NOT EXISTS vec_items USING vec0(
///   id TEXT PRIMARY KEY,
///   embedding FLOAT[${dimension}]
/// );
/// ```
///
/// TODO: 实际项目中需要依赖 drift 和 sqlite-vec 包
class VectorStore {
  /// 向量维度
  final int dimension;

  /// 是否已初始化
  bool _initialized = false;

  /// 内存中的向量数据（实际项目中使用 sqlite-vec）
  /// 这里用内存模拟，实际应替换为数据库操作
  final Map<String, VectorRecord> _store = {};

  VectorStore({required this.dimension});

  // ———————————————————————————————— 初始化 ————————————————————————————————

  /// 初始化向量存储
  ///
  /// 创建必要的表和索引。
  /// TODO: 实际项目中使用 drift 迁移
  Future<void> initialize() async {
    if (_initialized) return;

    // TODO: 实际项目中的 drift 初始化
    // await database.customStatement('''
    //   CREATE TABLE IF NOT EXISTS vectors (
    //     id TEXT PRIMARY KEY,
    //     content TEXT NOT NULL,
    //     memory_type TEXT NOT NULL DEFAULT 'episodic',
    //     session_id TEXT,
    //     created_at TEXT NOT NULL,
    //     last_accessed_at TEXT,
    //     access_count INTEGER DEFAULT 0,
    //     importance REAL DEFAULT 0.5,
    //     metadata TEXT DEFAULT '{}'
    //   )
    // ''');
    //
    // await database.customStatement('''
    //   CREATE VIRTUAL TABLE IF NOT EXISTS vec_items USING vec0(
    //     id TEXT PRIMARY KEY,
    //     embedding FLOAT[$dimension]
    //   )
    // ''');

    _initialized = true;
  }

  // ———————————————————————————————— 写入操作 ————————————————————————————————

  /// 插入单条向量记录
  Future<void> insert(VectorRecord record) async {
    _checkInitialized();
    if (record.vector.length != dimension) {
      throw MemoryException(
        '向量维度不匹配: 期望 $dimension，实际 ${record.vector.length}',
      );
    }
    _store[record.id] = record;

    // TODO: 实际项目写入数据库
    // await database.customStatement(
    //   'INSERT OR REPLACE INTO vectors ...',
    //   variables: [...],
    // );
    // await database.customStatement(
    //   'INSERT OR REPLACE INTO vec_items ...',
    //   variables: [...],
    // );
  }

  /// 批量插入向量记录
  ///
  /// 使用事务保证原子性，提高写入效率。
  Future<void> insertBatch(List<VectorRecord> records) async {
    _checkInitialized();

    // 校验维度
    for (final record in records) {
      if (record.vector.length != dimension) {
        throw MemoryException(
          '向量维度不匹配: 记录 ${record.id} 维度 ${record.vector.length}，期望 $dimension',
        );
      }
    }

    // TODO: 实际项目中使用事务批量写入
    // await database.transaction(() async {
    //   for (final record in records) {
    //     await database.customStatement('INSERT OR REPLACE INTO vectors ...');
    //     await database.customStatement('INSERT OR REPLACE INTO vec_items ...');
    //   }
    // });

    for (final record in records) {
      _store[record.id] = record;
    }
  }

  /// 删除向量记录
  Future<void> delete(String id) async {
    _checkInitialized();
    _store.remove(id);

    // TODO: 实际项目写入数据库
    // await database.customStatement(
    //   'DELETE FROM vectors WHERE id = ?',
    //   variables: [id],
    // );
    // await database.customStatement(
    //   'DELETE FROM vec_items WHERE id = ?',
    //   variables: [id],
    // );
  }

  /// 批量删除
  Future<void> deleteBatch(List<String> ids) async {
    _checkInitialized();
    for (final id in ids) {
      _store.remove(id);
    }
  }

  // ———————————————————————————————— 检索操作 ————————————————————————————————

  /// KNN 向量检索
  ///
  /// 使用余弦相似度搜索最近的 K 个向量。
  ///
  /// [queryVector] 查询向量
  /// [k] 返回结果数量
  /// [threshold] 最低相似度阈值（低于此值的结果会被过滤）
  /// [memoryType] 记忆类型过滤（null 表示不过滤）
  /// [sessionId] 会话 ID 过滤（null 表示不过滤）
  Future<List<VectorSearchResult>> knnSearch({
    required List<double> queryVector,
    int k = 10,
    double threshold = 0.0,
    MemoryType? memoryType,
    String? sessionId,
  }) async {
    _checkInitialized();

    if (queryVector.length != dimension) {
      throw MemoryException(
        '查询向量维度不匹配: 期望 $dimension，实际 ${queryVector.length}',
      );
    }

    // TODO: 实际项目中使用 sqlite-vec KNN 查询
    // final results = await database.customSelect('''
    //   SELECT v.*, vec.distance
    //   FROM vec_items vec
    //   JOIN vectors v ON v.id = vec.id
    //   WHERE vec.embedding MATCH ?
    //     AND k = ?
    //   ORDER BY distance
    // ''', variables: [queryVector, k]).get();

    // 内存模拟：计算余弦相似度
    final results = <VectorSearchResult>[];

    for (final record in _store.values) {
      // 类型过滤
      if (memoryType != null && record.memoryType != memoryType) continue;

      // 会话过滤
      if (sessionId != null && record.sessionId != sessionId) continue;

      // 计算余弦相似度
      final similarity = _cosineSimilarity(queryVector, record.vector);

      // 阈值过滤
      if (similarity < threshold) continue;

      results.add(VectorSearchResult(
        record: record,
        similarity: similarity,
      ));
    }

    // 按相似度降序排序，取前 K 个
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(k).toList();
  }

  /// 多类型 KNN 检索（同时检索多种记忆类型）
  ///
  /// 返回每种类型各 topK 的结果。
  Future<List<VectorSearchResult>> multiTypeSearch({
    required List<double> queryVector,
    int topKPerType = 5,
    double threshold = 0.0,
  }) async {
    final allResults = <VectorSearchResult>[];

    for (final type in MemoryType.values) {
      final typeResults = await knnSearch(
        queryVector: queryVector,
        k: topKPerType,
        threshold: threshold,
        memoryType: type,
      );
      allResults.addAll(typeResults);
    }

    // 合并排序
    allResults.sort((a, b) => b.similarity.compareTo(a.similarity));
    return allResults;
  }

  // ———————————————————————————————— 统计操作 ————————————————————————————————

  /// 获取存储中的记录总数
  int get count => _store.length;

  /// 按类型统计数量
  Map<MemoryType, int> get countByType {
    final counts = <MemoryType, int>{};
    for (final record in _store.values) {
      counts[record.memoryType] = (counts[record.memoryType] ?? 0) + 1;
    }
    return counts;
  }

  /// 更新访问统计
  Future<void> updateAccessStats(String id) async {
    final record = _store[id];
    if (record == null) return;

    _store[id] = VectorRecord(
      id: record.id,
      content: record.content,
      vector: record.vector,
      memoryType: record.memoryType,
      sessionId: record.sessionId,
      createdAt: record.createdAt,
      lastAccessedAt: DateTime.now(),
      accessCount: record.accessCount + 1,
      importance: record.importance,
      metadata: record.metadata,
    );
  }

  // ———————————————————————————————— 索引管理 ————————————————————————————————

  /// 重建向量索引
  ///
  /// 在大量数据变更后调用，确保索引一致性。
  Future<void> rebuildIndex() async {
    _checkInitialized();
    // TODO: 实际项目中重建 sqlite-vec 索引
    // await database.customStatement('DELETE FROM vec_items');
    // for (final record in _store.values) {
    //   await database.customStatement(
    //     'INSERT INTO vec_items ...',
    //   );
    // }
  }

  /// 清理过期数据
  ///
  /// 删除超过指定天数的低重要度记录。
  Future<int> cleanup({
    int maxAgeDays = 90,
    double minImportance = 0.1,
  }) async {
    _checkInitialized();
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    final toRemove = <String>[];

    for (final record in _store.entries) {
      if (record.value.createdAt.isBefore(cutoff) &&
          record.value.importance < minImportance) {
        toRemove.add(record.key);
      }
    }

    for (final id in toRemove) {
      _store.remove(id);
    }

    return toRemove.length;
  }

  // ———————————————————————————————— 工具方法 ————————————————————————————————

  /// 计算两个向量的余弦相似度
  ///
  /// cosine_similarity = dot(A, B) / (||A|| * ||B||)
  double _cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, '向量维度不一致');

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = _sqrt(normA) * _sqrt(normB);
    if (denominator == 0) return 0;

    return dotProduct / denominator;
  }

  /// 简易平方根
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  /// 检查是否已初始化
  void _checkInitialized() {
    if (!_initialized) {
      throw MemoryException('VectorStore 未初始化，请先调用 initialize()');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _store.clear();
    _initialized = false;
  }
}

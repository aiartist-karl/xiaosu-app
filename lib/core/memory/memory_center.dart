/// ============================================================================
/// 小酥 AI 助手 — 记忆中心 (Memory Center)
/// ============================================================================
/// 三层记忆架构的统一管理中心，包括：
///   - Working Memory（工作记忆）— 当前对话上下文
///   - Episodic Memory（情景记忆）— 历史对话片段
///   - Semantic Memory（语义记忆）— 提取的知识和事实
///   - 混合检索 (向量 + FTS5) + RRF 融合排序
///   - 记忆写入（自动分块 + 向量化）
///   - 用户画像更新
/// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import '../common/models.dart';
import 'embedder.dart';
import 'vector_store.dart';

// ———————————————————————————————— 文本分块器 ————————————————————————————————

/// 文本分块结果
class TextChunk {
  /// 分块唯一 ID
  final String id;

  /// 分块文本内容
  final String content;

  /// 在原文中的起始位置（字符索引）
  final int startIndex;

  /// 在原文中的结束位置
  final int endIndex;

  /// 块序号（从 0 开始）
  final int chunkIndex;

  /// 所属文档/消息的 ID
  final String sourceId;

  const TextChunk({
    required this.id,
    required this.content,
    required this.startIndex,
    required this.endIndex,
    required this.chunkIndex,
    required this.sourceId,
  });
}

/// 文本分块工具
///
/// 将长文本按窗口大小和重叠度进行分块，
/// 用于 Embedding 和记忆存储。
///
/// 分块策略：
/// - 按 token 数（估算 1 token ≈ 1.5 个中文字符 / 4 个英文字符）
/// - 支持句子边界感知（尽量在句子结尾切割）
/// - 相邻块有重叠（overlap），避免上下文丢失
class TextChunker {
  /// 每块最大 token 数
  final int maxTokensPerChunk;

  /// 相邻块重叠 token 数
  final int overlapTokens;

  TextChunker({
    this.maxTokensPerChunk = 256,
    this.overlapTokens = 50,
  });

  /// 将文本分块
  ///
  /// [text] 原始文本
  /// [sourceId] 来源标识
  List<TextChunk> chunk(String text, String sourceId) {
    if (text.isEmpty) return [];

    // 估算 token 数（简化：中文 1.5 字符/token，英文 4 字符/token）
    final estimatedTokens = _estimateTokens(text);

    // 短文本不需要分块
    if (estimatedTokens <= maxTokensPerChunk) {
      return [
        TextChunk(
          id: '${sourceId}_chunk_0',
          content: text,
          startIndex: 0,
          endIndex: text.length,
          chunkIndex: 0,
          sourceId: sourceId,
        )
      ];
    }

    final chunks = <TextChunk>[];
    final sentences = _splitSentences(text);

    int currentStart = 0;
    int currentTokens = 0;
    int chunkIndex = 0;

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final sentenceTokens = _estimateTokens(sentence);

      if (currentTokens + sentenceTokens > maxTokensPerChunk &&
          currentTokens > 0) {
        // 当前块已满，创建分块
        final chunkEnd = currentStart + _getSentenceRange(sentences, chunks.isEmpty ? 0 : chunkIndex * _sentencesPerChunk(chunks, i), i - 1);

        chunks.add(TextChunk(
          id: '${sourceId}_chunk_$chunkIndex',
          content: text.substring(currentStart, currentStart + currentTokens * 2),
          startIndex: currentStart,
          endIndex: currentStart + currentTokens * 2 > text.length
              ? text.length
              : currentStart + currentTokens * 2,
          chunkIndex: chunkIndex,
          sourceId: sourceId,
        ));

        chunkIndex++;

        // 重叠：回退 overlapTokens
        final overlapChars = overlapTokens * 2;
        currentStart = (currentStart + currentTokens * 2 - overlapChars)
            .clamp(0, text.length);
        currentTokens = overlapTokens;
      }

      currentTokens += sentenceTokens;
    }

    // 处理最后一块
    if (currentTokens > 0 && currentStart < text.length) {
      chunks.add(TextChunk(
        id: '${sourceId}_chunk_$chunkIndex',
        content: text.substring(currentStart),
        startIndex: currentStart,
        endIndex: text.length,
        chunkIndex: chunkIndex,
        sourceId: sourceId,
      ));
    }

    return chunks;
  }

  /// 按句子边界分割文本
  List<String> _splitSentences(String text) {
    // 使用正则表达式按句子分割
    final sentencePattern = RegExp(r'(?<=[。！？.!?\n])\s*');
    final parts = text.split(sentencePattern).where((s) => s.trim().isNotEmpty).toList();

    if (parts.isEmpty) return [text];
    return parts;
  }

  /// 估算文本 token 数
  int _estimateTokens(String text) {
    int chineseChars = 0;
    int otherChars = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // CJK 统一汉字范围
      if (code >= 0x4E00 && code <= 0x9FFF) {
        chineseChars++;
      } else {
        otherChars++;
      }
    }
    return (chineseChars / 1.5).ceil() + (otherChars / 4).ceil();
  }

  /// 辅助方法
  int _getSentenceRange(List<String> sentences, int start, int end) {
    int len = 0;
    for (int i = start; i <= end && i < sentences.length; i++) {
      len += sentences[i].length;
    }
    return len;
  }

  int _sentencesPerChunk(List<TextChunk> chunks, int currentIndex) => 0;
}

// ———————————————————————————————— 检索结果 ————————————————————————————————

/// 混合检索结果
class MemorySearchResult {
  /// 来源记忆类型
  final MemoryType memoryType;

  /// 匹配的文本内容
  final String content;

  /// 向量检索评分
  final double vectorScore;

  /// 全文检索评分（BM25）
  final double ftsScore;

  /// RRF 融合评分
  final double rrfScore;

  /// 关联的记录 ID
  final String recordId;

  /// 元数据
  final Map<String, dynamic> metadata;

  const MemorySearchResult({
    required this.memoryType,
    required this.content,
    this.vectorScore = 0,
    this.ftsScore = 0,
    required this.rrfScore,
    required this.recordId,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'MemoryResult(type=$memoryType, rrf=${rrfScore.toStringAsFixed(3)}, '
      '"${content.length > 50 ? content.substring(0, 50) : content}...")';
}

// ———————————————————————————————— 用户画像 ————————————————————————————————

/// 用户画像模型
///
/// 记录用户的偏好、习惯、常用功能等信息，
/// 用于个性化回复和行为预测。
class UserProfile {
  /// 用户 ID
  final String userId;

  /// 用户称呼
  String? nickname;

  /// 职业/身份
  String? occupation;

  /// 偏好话题
  final List<String> preferredTopics;

  /// 沟通风格偏好
  String? communicationStyle;

  /// 常用功能
  final List<String> frequentFeatures;

  /// 对话历史摘要
  final List<String> conversationSummaries;

  /// 最后更新时间
  DateTime updatedAt;

  /// 创建时间
  final DateTime createdAt;

  UserProfile({
    required this.userId,
    this.nickname,
    this.occupation,
    this.preferredTopics = const [],
    this.communicationStyle,
    this.frequentFeatures = const [],
    this.conversationSummaries = const [],
    DateTime? updatedAt,
    DateTime? createdAt,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// 转为提示词片段
  String toPromptString() {
    final buffer = StringBuffer('## 用户画像\n');
    if (nickname != null) buffer.writeln('- 称呼: $nickname');
    if (occupation != null) buffer.writeln('- 职业: $occupation');
    if (communicationStyle != null) {
      buffer.writeln('- 沟通风格: $communicationStyle');
    }
    if (preferredTopics.isNotEmpty) {
      buffer.writeln('- 偏好话题: ${preferredTopics.join(", ")}');
    }
    if (frequentFeatures.isNotEmpty) {
      buffer.writeln('- 常用功能: ${frequentFeatures.join(", ")}');
    }
    return buffer.toString();
  }
}

// ———————————————————————————————— 记忆中心 ————————————————————————————————

/// 记忆中心
///
/// 统一管理三层记忆，提供：
/// - 记忆写入（自动分块 + 向量化 + 存储）
/// - 混合检索（向量相似度 + FTS5 全文检索 + RRF 融合）
/// - 工作记忆管理（当前对话上下文）
/// - 用户画像更新
///
/// 架构：
/// ```
/// MemoryCenter
///   ├── WorkingMemory   → 当前 Session 的消息列表
///   ├── EpisodicMemory  → VectorStore (type=episodic) + FTS5
///   ├── SemanticMemory  → VectorStore (type=semantic) + FTS5
///   ├── Embedder        → 文本向量化
///   └── UserProfile     → 用户画像
/// ```
///
/// TODO: 实际项目中使用 Riverpod 管理单例
class MemoryCenter {
  /// 向量存储引擎
  final VectorStore vectorStore;

  /// Embedder 实例
  final Embedder embedder;

  /// 文本分块器
  final TextChunker chunker;

  /// 用户画像
  UserProfile? _userProfile;

  /// 工作记忆：当前会话的消息列表
  final List<ChatMessage> _workingMemory = [];

  /// 工作记忆最大消息数
  final int maxWorkingMemorySize;

  /// RRF 融合参数 k（RRF 公式中的常数）
  static const int _rrfK = 60;

  /// 是否已初始化
  bool _initialized = false;

  MemoryCenter({
    required this.vectorStore,
    required this.embedder,
    this.chunker = const TextChunker(),
    this.maxWorkingMemorySize = 50,
    UserProfile? userProfile,
  }) : _userProfile = userProfile;

  // ———————————————————————————————— 初始化 ————————————————————————————————

  /// 初始化记忆中心
  Future<void> initialize() async {
    if (_initialized) return;
    await vectorStore.initialize();
    _initialized = true;
  }

  // ———————————————————————————————— 工作记忆 ————————————————————————————————

  /// 获取工作记忆（当前对话上下文）
  List<ChatMessage> get workingMemory => List.unmodifiable(_workingMemory);

  /// 添加消息到工作记忆
  void addToWorkingMemory(ChatMessage message) {
    _workingMemory.add(message);

    // 超出容量时移除最早的消息（保留 SystemMessage）
    while (_workingMemory.length > maxWorkingMemorySize) {
      final nonSystemIndex = _workingMemory.indexWhere(
        (m) => m.role != 'system',
      );
      if (nonSystemIndex >= 0 && nonSystemIndex < _workingMemory.length) {
        _workingMemory.removeAt(nonSystemIndex);
      } else {
        break;
      }
    }
  }

  /// 清空工作记忆（新会话时调用）
  void clearWorkingMemory() {
    _workingMemory.clear();
  }

  /// 获取工作记忆消息（转为 LLM 可消费的格式）
  List<Map<String, dynamic>> getWorkingMemoryForLlm() {
    return _workingMemory.map((m) => m.toMap()).toList();
  }

  // ———————————————————————————————— 情景记忆写入 ————————————————————————————————

  /// 存储对话记忆（情景记忆）
  ///
  /// 自动执行：分块 → 向量化 → 存入 VectorStore
  ///
  /// [messages] 对话消息列表
  /// [sessionId] 会话 ID
  /// [importance] 重要度 (0.0 ~ 1.0)
  Future<List<String>> storeEpisodicMemory({
    required List<ChatMessage> messages,
    required String sessionId,
    double importance = 0.5,
  }) async {
    _checkInitialized();

    // 拼接消息为文本
    final conversationText = messages
        .where((m) => m.role != 'system')
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    if (conversationText.isEmpty) return [];

    // 分块
    final chunks = chunker.chunk(conversationText, sessionId);

    // 向量化
    final vectors = await embedder.embedBatch(
      chunks.map((c) => c.content).toList(),
    );

    // 构建记录并存储
    final records = <VectorRecord>[];
    for (int i = 0; i < chunks.length; i++) {
      records.add(VectorRecord(
        id: chunks[i].id,
        content: chunks[i].content,
        vector: vectors[i],
        memoryType: MemoryType.episodic,
        sessionId: sessionId,
        createdAt: DateTime.now(),
        importance: importance,
      ));
    }

    await vectorStore.insertBatch(records);
    return records.map((r) => r.id).toList();
  }

  // ———————————————————————————————— 语义记忆写入 ————————————————————————————————

  /// 存储语义记忆（知识/事实）
  ///
  /// [content] 知识内容
  /// [tags] 标签列表
  /// [importance] 重要度
  Future<String> storeSemanticMemory({
    required String content,
    List<String> tags = const [],
    double importance = 0.7,
  }) async {
    _checkInitialized();

    // 分块（语义记忆通常是较短的知识片段）
    final chunks = chunker.chunk(content, 'semantic_${DateTime.now().millisecondsSinceEpoch}');

    // 向量化
    final vectors = await embedder.embedBatch(
      chunks.map((c) => c.content).toList(),
    );

    // 存储
    final records = <VectorRecord>[];
    for (int i = 0; i < chunks.length; i++) {
      records.add(VectorRecord(
        id: chunks[i].id,
        content: chunks[i].content,
        vector: vectors[i],
        memoryType: MemoryType.semantic,
        createdAt: DateTime.now(),
        importance: importance,
        metadata: {'tags': tags},
      ));
    }

    await vectorStore.insertBatch(records);
    return records.first.id;
  }

  // ———————————————————————————————— 混合检索 ————————————————————————————————

  /// 混合检索（向量 + FTS5 + RRF 融合排序）
  ///
  /// 核心检索流程：
  /// 1. 向量检索：将 query 向量化，在 VectorStore 中做 KNN 搜索
  /// 2. 全文检索：使用 SQLite FTS5 做 BM25 全文搜索
  /// 3. RRF 融合：使用 Reciprocal Rank Fusion 合并两路结果
  ///
  /// [query] 查询文本
  /// [k] 返回结果数量
  /// [memoryType] 限定记忆类型（null 表示所有类型）
  /// [threshold] 最低 RRF 评分阈值
  Future<List<MemorySearchResult>> search({
    required String query,
    int k = 10,
    MemoryType? memoryType,
    double threshold = 0.0,
  }) async {
    _checkInitialized();

    // Step 1: 向量检索
    final queryVector = await embedder.embed(query);
    final vectorResults = await vectorStore.knnSearch(
      queryVector: queryVector,
      k: k * 2, // 多取一些，后面融合后截取
      memoryType: memoryType,
    );

    // Step 2: 全文检索 (FTS5 BM25)
    // TODO: 实际项目中使用 SQLite FTS5
    // final ftsResults = await database.customSelect('''
    //   SELECT id, content, memory_type, bm25(fts_vectors, 1.0, 1.0) as score
    //   FROM fts_vectors
    //   WHERE fts_vectors MATCH ?
    //   ORDER BY score
    //   LIMIT ?
    // ''', variables: [query, k * 2]).get();
    final ftsResults = _mockFtsSearch(query, k * 2, memoryType);

    // Step 3: RRF 融合排序
    final fusedResults = _reciprocalRankFusion(
      vectorResults: vectorResults,
      ftsResults: ftsResults,
      k: k,
    );

    // 阈值过滤
    if (threshold > 0) {
      return fusedResults.where((r) => r.rrfScore >= threshold).toList();
    }

    return fusedResults;
  }

  /// Reciprocal Rank Fusion (RRF) 算法
  ///
  /// 公式：RRF_score(d) = Σ 1 / (k + rank_i(d))
  /// 其中 k 是常数（通常取 60），rank_i(d) 是文档 d 在第 i 路检索中的排名。
  ///
  /// RRF 的优点：
  /// - 不需要对分数进行归一化
  /// - 对不同检索方法的分数分布差异鲁棒
  /// - 简单有效
  List<MemorySearchResult> _reciprocalRankFusion({
    required List<VectorSearchResult> vectorResults,
    required List<VectorSearchResult> ftsResults,
    required int k,
  }) {
    // 计算每个记录的 RRF 分数
    final rrfScores = <String, double>{};
    final recordMap = <String, VectorSearchResult>{};

    // 向量检索排名贡献
    for (int i = 0; i < vectorResults.length; i++) {
      final id = vectorResults[i].record.id;
      final score = 1.0 / (_rrfK + i + 1); // rank 从 1 开始
      rrfScores[id] = (rrfScores[id] ?? 0) + score;
      recordMap[id] = vectorResults[i];
    }

    // 全文检索排名贡献
    for (int i = 0; i < ftsResults.length; i++) {
      final id = ftsResults[i].record.id;
      final score = 1.0 / (_rrfK + i + 1);
      rrfScores[id] = (rrfScores[id] ?? 0) + score;

      if (!recordMap.containsKey(id)) {
        recordMap[id] = ftsResults[i];
      }
    }

    // 构建结果并排序
    final results = rrfScores.entries.map((e) {
      final record = recordMap[e.key]!;
      return MemorySearchResult(
        memoryType: record.record.memoryType,
        content: record.record.content,
        vectorScore: record.similarity,
        rrfScore: e.value,
        recordId: e.key,
        metadata: record.record.metadata,
      );
    }).toList();

    results.sort((a, b) => b.rrfScore.compareTo(a.rrfScore));

    return results.take(k).toList();
  }

  /// FTS5 全文检索模拟
  ///
  /// TODO: 实际项目中使用 SQLite FTS5
  List<VectorSearchResult> _mockFtsSearch(
    String query,
    int limit,
    MemoryType? memoryType,
  ) {
    // 简单的关键词匹配模拟
    final queryLower = query.toLowerCase();
    final results = <VectorSearchResult>[];

    // 遍历 store 中的记录（实际项目中应使用 FTS5）
    // 这里简化处理，实际需要用 drift 查询 FTS5 虚拟表
    return results;
  }

  // ———————————————————————————————— 用户画像 ————————————————————————————————

  /// 获取用户画像
  UserProfile? get userProfile => _userProfile;

  /// 更新用户画像
  ///
  /// 基于最新对话信息更新用户画像。
  /// 通常由 LLM 分析对话后提取关键信息。
  Future<void> updateUserProfile({
    String? nickname,
    String? occupation,
    List<String>? preferredTopics,
    String? communicationStyle,
    List<String>? frequentFeatures,
  }) async {
    _userProfile ??= UserProfile(userId: 'default');

    if (nickname != null) _userProfile!.nickname = nickname;
    if (occupation != null) _userProfile!.occupation = occupation;
    if (preferredTopics != null) {
      _userProfile!.preferredTopics.addAll(
        preferredTopics.where((t) => !_userProfile!.preferredTopics.contains(t)),
      );
    }
    if (communicationStyle != null) {
      _userProfile!.communicationStyle = communicationStyle;
    }
    if (frequentFeatures != null) {
      _userProfile!.frequentFeatures.addAll(
        frequentFeatures.where((f) => !_userProfile!.frequentFeatures.contains(f)),
      );
    }

    _userProfile!.updatedAt = DateTime.now();
  }

  /// 使用 LLM 自动提取并更新用户画像
  ///
  /// 在对话过程中周期性调用，从对话中提取用户信息。
  Future<void> autoExtractUserProfile(List<ChatMessage> messages) async {
    // TODO: 调用 LLM 提取用户画像信息
    // final prompt = '''
    // 分析以下对话，提取用户信息：
    // - 用户称呼/昵称
    // - 职业/身份
    // - 兴趣话题
    // - 沟通风格偏好
    // 返回 JSON 格式...
    // ''';
  }

  // ———————————————————————————————— 记忆管理 ————————————————————————————————

  /// 获取记忆统计信息
  Map<String, dynamic> getStats() {
    final typeCounts = vectorStore.countByType;
    return {
      'working_memory_size': _workingMemory.length,
      'total_vectors': vectorStore.count,
      'episodic_count': typeCounts[MemoryType.episodic] ?? 0,
      'semantic_count': typeCounts[MemoryType.semantic] ?? 0,
      'working_count': typeCounts[MemoryType.working] ?? 0,
      'has_user_profile': _userProfile != null,
    };
  }

  /// 清理过期记忆
  Future<int> cleanupMemories({
    int maxAgeDays = 90,
    double minImportance = 0.1,
  }) async {
    return vectorStore.cleanup(
      maxAgeDays: maxAgeDays,
      minImportance: minImportance,
    );
  }

  /// 导出所有记忆（备份用）
  Future<Map<String, dynamic>> exportAll() async {
    return {
      'user_profile': _userProfile?.toPromptString() ?? '',
      'working_memory': _workingMemory.map((m) => m.toMap()).toList(),
      'stats': getStats(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  // ———————————————————————————————— 工具方法 ————————————————————————————————

  /// 检查是否已初始化
  void _checkInitialized() {
    if (!_initialized) {
      throw MemoryException('MemoryCenter 未初始化，请先调用 initialize()');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _workingMemory.clear();
    await vectorStore.dispose();
    await embedder.dispose();
    _initialized = false;
  }
}

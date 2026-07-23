// ============================================================================
// 小酥 (XiaoSu) - 记忆中心（MemoryCenter）
//
// 职责：
// 1. 管理用户长期记忆（类似 Mem0）
// 2. RAG 语义检索（从记忆中搜索与当前对话相关的片段）
// 3. 自动从对话中提取关键信息存入记忆
// 4. 记忆分类管理（用户偏好、重要事件、知识等）
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:xiaosu_core/main.dart' show appLogger;

/// ============================================================================
/// 记忆中心 —— 小酥的"长期记忆"
/// ============================================================================
class MemoryCenter {
  MemoryCenter._internal();
  static final MemoryCenter instance = MemoryCenter._internal();

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── Hive 存储（记忆持久化）────────────────────────────────
  late Box<Map<dynamic, dynamic>> _memoryBox;

  /// ─── 内存中的记忆索引 ───────────────────────────────────────
  final List<MemoryFragment> _memories = [];

  /// ─── UUID 生成器 ────────────────────────────────────────────
  static const _uuid = Uuid();

  /// ─── 是否已初始化 ───────────────────────────────────────────
  bool _initialized = false;

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化记忆中心
  Future<void> initialize() async {
    if (_initialized) return;

    // 打开 Hive 存储
    _memoryBox = await Hive.openBox<Map<dynamic, dynamic>>('memories');

    // 加载所有记忆到内存
    for (final key in _memoryBox.keys) {
      final data = _memoryBox.get(key);
      if (data != null) {
        try {
          _memories.add(MemoryFragment.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          _logger.w('⚠️ 加载记忆片段失败 [key=$key]: $e');
        }
      }
    }

    _initialized = true;
    _logger.i('💾 记忆中心初始化完成，加载 ${_memories.length} 条记忆');
  }

  // ==========================================================================
  // RAG 检索
  // ==========================================================================

  /// 语义检索相关记忆
  ///
  /// [query] 查询文本（通常是用户的最新消息）
  /// [topK] 返回最相关的 K 条记忆
  ///
  /// 当前实现：基于关键词匹配的简化版本
  /// TODO: 接入 Embedding 模型实现真正的向量语义检索
  Future<List<MemoryFragment>> searchRelevantMemories({
    required String query,
    int topK = 5,
  }) async {
    if (_memories.isEmpty) return [];

    // 简化实现：关键词匹配 + 最近优先
    final queryWords = _tokenize(query);
    final scored = <_ScoredMemory>[];

    for (final memory in _memories) {
      final memoryWords = _tokenize(memory.content);
      double score = 0;

      // 计算关键词重叠度
      for (final word in queryWords) {
        if (memoryWords.contains(word)) {
          score += 1.0;
        }
      }

      // 时效性加权（最近的记忆权重更高）
      final daysAgo = DateTime.now().difference(memory.timestamp).inDays;
      score += (1.0 / (daysAgo + 1)) * 0.5;

      // 重要性加权
      score += memory.importance * 0.3;

      if (score > 0) {
        scored.add(_ScoredMemory(memory, score));
      }
    }

    // 按得分排序，取 TopK
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((s) => s.memory).toList();
  }

  // ==========================================================================
  // 记忆写入
  // ==========================================================================

  /// 存储一条新记忆
  Future<void> storeMemory({
    required String content,
    required String category,
    String source = '',
    double importance = 0.5,
  }) async {
    final fragment = MemoryFragment(
      id: _uuid.v4(),
      content: content,
      category: category,
      source: source,
      importance: importance,
      timestamp: DateTime.now(),
    );

    _memories.add(fragment);
    await _persistMemory(fragment);
    _logger.d('💾 存储新记忆 [$category]: ${_truncate(content, 60)}');
  }

  /// 从对话中自动提取记忆
  ///
  /// 在每次对话完成后异步调用，让 LLM 从对话中提取值得记住的信息
  Future<void> extractAndStoreMemories({
    required String conversationId,
    required String userMessage,
    required String assistantResponse,
  }) async {
    // TODO: 调用 LLM 提取关键信息
    // 当前简化实现：提取用户消息中的关键信息

    final combined = '$userMessage\n$assistantResponse';

    // 检测用户偏好类信息
    if (combined.contains('喜欢') || combined.contains('偏好') || combined.contains('习惯')) {
      await storeMemory(
        content: userMessage,
        category: '用户偏好',
        source: conversationId,
        importance: 0.7,
      );
    }

    // 检测重要事件
    if (combined.contains('重要') || combined.contains('记住') || combined.contains('别忘了')) {
      await storeMemory(
        content: userMessage,
        category: '重要事件',
        source: conversationId,
        importance: 0.9,
      );
    }

    _logger.d('🔍 记忆提取完成');
  }

  /// 删除记忆
  Future<void> deleteMemory(String memoryId) async {
    _memories.removeWhere((m) => m.id == memoryId);
    await _memoryBox.delete(memoryId);
    _logger.d('🗑️ 删除记忆: $memoryId');
  }

  /// 获取所有记忆
  List<MemoryFragment> getAllMemories() {
    return List.unmodifiable(_memories)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ==========================================================================
  // 内部方法
  // ==========================================================================

  /// 持久化单条记忆到 Hive
  Future<void> _persistMemory(MemoryFragment fragment) async {
    await _memoryBox.put(fragment.id, fragment.toJson());
  }

  /// 简单分词（按空格和标点分割）
  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), ' ')
        .split(' ')
        .where((w) => w.length > 1)
        .toSet();
  }

  /// 截断文本
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

// ============================================================================
/// 记忆片段模型
/// ============================================================================
class MemoryFragment {
  final String id;
  final String content;
  final String category;
  final String source;
  final double importance;
  final DateTime timestamp;

  const MemoryFragment({
    required this.id,
    required this.content,
    required this.category,
    this.source = '',
    this.importance = 0.5,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category,
    'source': source,
    'importance': importance,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MemoryFragment.fromJson(Map<String, dynamic> json) {
    return MemoryFragment(
      id: json['id'] as String,
      content: json['content'] as String,
      category: json['category'] as String? ?? '',
      source: json['source'] as String? ?? '',
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// 带分数的记忆（用于排序）
class _ScoredMemory {
  final MemoryFragment memory;
  final double score;
  _ScoredMemory(this.memory, this.score);
}

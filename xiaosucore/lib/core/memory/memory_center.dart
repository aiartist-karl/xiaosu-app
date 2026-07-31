// ============================================================================
// 小酥 - 记忆管理中心
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'vector_store.dart';
import 'embedder.dart';

/// 记忆类型
enum MemoryType {
  shortTerm,  // 短期记忆（当前对话上下文）
  longTerm,   // 长期记忆（重要事实、偏好）
  episodic,   // 情景记忆（过去的对话摘要）
  semantic,   // 语义记忆（知识库）
}

/// 记忆条目
class MemoryItem {
  final String id;
  final String content;
  final MemoryType type;
  final double importance;  // 0.0 - 1.0
  final DateTime createdAt;
  final DateTime? lastAccessedAt;
  final int accessCount;
  final Map<String, dynamic> metadata;

  const MemoryItem({
    required this.id,
    required this.content,
    this.type = MemoryType.shortTerm,
    this.importance = 0.5,
    required this.createdAt,
    this.lastAccessedAt,
    this.accessCount = 0,
    this.metadata = const {},
  });

  MemoryItem copyWith({
    String? id, String? content, MemoryType? type, double? importance,
    DateTime? createdAt, DateTime? lastAccessedAt, int? accessCount,
    Map<String, dynamic>? metadata,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      importance: importance ?? this.importance,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'content': content, 'type': type.name,
    'importance': importance, 'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt?.toIso8601String(),
    'accessCount': accessCount, 'metadata': metadata,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      content: json['content'] as String,
      type: MemoryType.values.firstWhere((e) => e.name == json['type'],
          orElse: () => MemoryType.shortTerm),
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String) : null,
      accessCount: json['accessCount'] as int? ?? 0,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// 记忆管理中心
class MemoryCenterService {
  static final MemoryCenterService instance = MemoryCenterService._();
  MemoryCenterService._();

  final VectorStore _vectorStore = VectorStore.instance;
  final Embedder _embedder = Embedder.instance;
  final Map<String, MemoryItem> _memories = {};
  final List<MemoryItem> _shortTermBuffer = [];

  bool _initialized = false;
  static const int _maxShortTerm = 20;
  static const String _storageKey = 'xiaosu_memories';

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  /// 添加记忆
  Future<MemoryItem> addMemory({
    required String content,
    MemoryType type = MemoryType.shortTerm,
    double importance = 0.5,
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = MemoryItem(
      id: id,
      content: content,
      type: type,
      importance: importance,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    _memories[id] = item;

    // 添加到向量存储用于语义搜索
    if (type == MemoryType.longTerm || type == MemoryType.semantic) {
      await _vectorStore.addText(id: id, text: content, metadata: {
        'type': type.name,
        'importance': importance,
        ...metadata,
      });
    }

    // 短期记忆缓冲
    if (type == MemoryType.shortTerm) {
      _shortTermBuffer.add(item);
      if (_shortTermBuffer.length > _maxShortTerm) {
        _shortTermBuffer.removeAt(0);
      }
    }

    await _saveToStorage();
    return item;
  }

  /// 搜索相关记忆
  List<MemoryItem> searchMemories(String query, {int topK = 5, MemoryType? type}) {
    // 先做向量搜索
    final vectorResults = _vectorStore.search(query, topK: topK * 2);
    final results = <MemoryItem>[];

    for (final vr in vectorResults) {
      final memory = _memories[vr.id];
      if (memory != null) {
        if (type != null && memory.type != type) continue;
        results.add(MemoryItem(
          id: memory.id,
          content: memory.content,
          type: memory.type,
          importance: memory.importance,
          createdAt: memory.createdAt,
          lastAccessedAt: DateTime.now(),
          accessCount: memory.accessCount + 1,
          metadata: memory.metadata,
        ));
        _memories[memory.id] = results.last;
      }
    }

    // 补充短期记忆
    if (type == null || type == MemoryType.shortTerm) {
      for (final item in _shortTermBuffer.reversed) {
        if (results.length >= topK) break;
        if (!results.any((r) => r.id == item.id)) {
          results.add(item);
        }
      }
    }

    return results.take(topK).toList();
  }

  /// 获取对话上下文（最近N条消息的摘要）
  List<MemoryItem> getConversationContext({int limit = 10}) {
    return _shortTermBuffer.takeLast(limit);
  }

  /// 删除记忆
  Future<void> removeMemory(String id) async {
    _memories.remove(id);
    _vectorStore.remove(id);
    _shortTermBuffer.removeWhere((m) => m.id == id);
    await _saveToStorage();
  }

  /// 清空所有记忆
  Future<void> clearAll() async {
    _memories.clear();
    _vectorStore.clear();
    _shortTermBuffer.clear();
    await _saveToStorage();
  }

  /// 获取所有记忆
  List<MemoryItem> getAllMemories({MemoryType? type}) {
    final all = _memories.values.toList();
    if (type != null) {
      return all.where((m) => m.type == type).toList();
    }
    return all;
  }

  /// 持久化到SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _memories.values.map((m) => m.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  /// 从SharedPreferences加载
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final list = jsonDecode(data) as List;
        for (final item in list) {
          final memory = MemoryItem.fromJson(item as Map<String, dynamic>);
          _memories[memory.id] = memory;
          if (memory.type == MemoryType.longTerm || memory.type == MemoryType.semantic) {
            await _vectorStore.addText(id: memory.id, text: memory.content);
          }
        }
      }
    } catch (_) {}
  }
}

/// 扩展List取最后N个
extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}

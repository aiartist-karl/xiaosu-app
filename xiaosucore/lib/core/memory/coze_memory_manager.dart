// ============================================================================
// 小酥 - Coze Studio 记忆管理器
// Phase 6: 统一管理层，整合本地记忆 + 远程记忆
// ============================================================================

import 'memory_center.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/models/memory_model.dart';

/// Coze 记忆管理器 - 统一管理本地和远程记忆
///
/// 职责：
/// 1. 同步本地 MemoryCenter 与 Coze Studio 记忆系统
/// 2. 提供统一的记忆搜索/添加/删除接口
/// 3. 处理本地优先 vs 远程优先的搜索策略
class CozeMemoryManager {
  static final CozeMemoryManager instance = CozeMemoryManager._();
  CozeMemoryManager._();

  final MemoryCenterService _local = MemoryCenterService.instance;
  final MemoryRepository _repo = MemoryRepository.instance;

  bool _initialized = false;
  bool _syncEnabled = false;
  String? _currentBotId;

  /// 当前 Bot ID（用于远程记忆隔离）
  String? get currentBotId => _currentBotId;

  /// 是否启用远程同步
  bool get syncEnabled => _syncEnabled;

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化记忆管理器
  Future<void> initialize({
    bool enableSync = false,
    String? botId,
  }) async {
    if (_initialized) return;

    _syncEnabled = enableSync;
    _currentBotId = botId;

    // 初始化本地记忆服务
    await _local.initialize();

    _initialized = true;
  }

  /// 设置当前 Bot ID
  void setCurrentBot(String botId) {
    _currentBotId = botId;
  }

  /// 启用/禁用远程同步
  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  // ==========================================================================
  // 添加记忆（同时写入本地 + 远程）
  // ==========================================================================

  /// 添加记忆
  ///
  /// [content] 记忆内容
  /// [type] 记忆类型（本地使用）
  /// [tags] 标签列表（远程使用）
  /// [importance] 重要度 0.0-1.0
  /// 本地记忆始终写入；远程记忆仅在 syncEnabled 时写入
  Future<MemoryItem> addMemory({
    required String content,
    MemoryType type = MemoryType.shortTerm,
    List<String> tags = const [],
    double importance = 0.5,
  }) async {
    // 始终写入本地
    final localItem = await _local.addMemory(
      content: content,
      type: type,
      importance: importance,
    );

    // 远程同步
    if (_syncEnabled && _currentBotId != null) {
      try {
        final remoteType = _mapToCozeMemoryType(type);
        await _repo.createMemory(
          content,
          tags: tags,
          botId: _currentBotId,
          type: remoteType,
        );
      } catch (_) {
        // 远程写入失败不影响本地
      }
    }

    return localItem;
  }

  // ==========================================================================
  // 搜索记忆（本地 + 远程合并）
  // ==========================================================================

  /// 搜索记忆
  ///
  /// [query] 搜索关键词
  /// [topK] 返回数量
  /// [localOnly] 仅搜索本地
  /// [remoteOnly] 仅搜索远程
  Future<List<CozeMemorySearchResult>> searchMemories(
    String query, {
    int topK = 5,
    bool localOnly = false,
    bool remoteOnly = false,
  }) async {
    final results = <CozeMemorySearchResult>[];

    // 本地搜索
    if (!remoteOnly) {
      final localResults = _local.searchMemories(query, topK: topK);
      for (final item in localResults) {
        results.add(CozeMemorySearchResult(
          id: item.id,
          content: item.content,
          importance: item.importance,
          source: CozeMemorySource.local,
          createdAt: item.createdAt,
        ));
      }
    }

    // 远程搜索
    if (!localOnly && _syncEnabled && _currentBotId != null) {
      try {
        final remoteResult = await _repo.searchMemory(
          query,
          topK: topK,
        );
        if (remoteResult.success && remoteResult.data != null) {
          for (final mem in remoteResult.data!) {
            // 去重：如果本地已有相同内容的结果则跳过
            final isDuplicate = results.any((r) => r.content == mem.content);
            if (!isDuplicate) {
              results.add(CozeMemorySearchResult(
                id: mem.id,
                content: mem.content,
                importance: mem.importance,
                source: CozeMemorySource.remote,
                createdAt: mem.createdAt,
                tags: mem.tags,
              ));
            }
          }
        }
      } catch (_) {
        // 远程搜索失败不影响本地结果
      }
    }

    // 按重要度排序并截取
    results.sort((a, b) => b.importance.compareTo(a.importance));
    return results.take(topK).toList();
  }

  /// 快速搜索本地记忆（同步方法）
  List<MemoryItem> searchLocalSync(String query, {int topK = 5}) {
    return _local.searchMemories(query, topK: topK);
  }

  // ==========================================================================
  // 删除记忆
  // ==========================================================================

  /// 删除记忆
  ///
  /// 本地记忆始终删除；远程记忆在 syncEnabled 时删除
  Future<void> removeMemory(String id, {bool isRemote = false}) async {
    // 删除本地
    if (!isRemote) {
      await _local.removeMemory(id);
    }

    // 删除远程
    if (_syncEnabled && isRemote) {
      try {
        await _repo.deleteMemory(id);
      } catch (_) {
        // 远程删除失败不影响本地
      }
    }
  }

  // ==========================================================================
  // 远程记忆管理（仅远程）
  // ==========================================================================

  /// 获取远程记忆列表
  Future<List<CozeMemory>> fetchRemoteMemories() async {
    if (!_syncEnabled) return [];

    try {
      final result = await _repo.fetchMemoryList(
        botId: _currentBotId,
      );
      return result.data ?? [];
    } catch (_) {
      return [];
    }
  }

  /// 清空所有记忆（本地 + 远程）
  Future<void> clearAll() async {
    await _local.clearAll();

    if (_syncEnabled && _currentBotId != null) {
      try {
        // 获取所有远程记忆并逐一删除
        final allRemote = await fetchRemoteMemories();
        for (final mem in allRemote) {
          await _repo.deleteMemory(mem.id);
        }
      } catch (_) {
        // 远程清空失败不影响本地
      }
    }
  }

  // ==========================================================================
  // 获取对话上下文（本地短期记忆）
  // ==========================================================================

  /// 获取最近对话上下文
  List<MemoryItem> getConversationContext({int limit = 10}) {
    return _local.getConversationContext(limit: limit);
  }

  /// 获取所有本地记忆
  List<MemoryItem> getAllLocal({MemoryType? type}) {
    return _local.getAllMemories(type: type);
  }

  // ==========================================================================
  // 辅助方法
  // ==========================================================================

  /// 将本地记忆类型映射为远程记忆类型
  CozeMemoryType _mapToCozeMemoryType(MemoryType type) {
    switch (type) {
      case MemoryType.shortTerm:
        return CozeMemoryType.shortTerm;
      case MemoryType.longTerm:
        return CozeMemoryType.longTerm;
      case MemoryType.episodic:
        return CozeMemoryType.episodic;
      case MemoryType.semantic:
        return CozeMemoryType.semantic;
    }
  }
}

/// 记忆搜索来源
enum CozeMemorySource {
  local,   // 本地记忆
  remote,  // 远程记忆
}

/// 记忆搜索结果
class CozeMemorySearchResult {
  final String id;
  final String content;
  final double importance;
  final CozeMemorySource source;
  final DateTime createdAt;
  final List<String> tags;

  const CozeMemorySearchResult({
    required this.id,
    required this.content,
    this.importance = 0.5,
    this.source = CozeMemorySource.local,
    required this.createdAt,
    this.tags = const [],
  });
}

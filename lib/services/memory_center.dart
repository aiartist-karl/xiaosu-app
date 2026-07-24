// ============================================================================
// 小酥 - 记忆中心服务层封装
// ============================================================================

import '../core/memory/memory_center.dart';

/// 记忆服务层 - 为UI层提供简化接口
class MemoryService {
  static final MemoryService instance = MemoryService._();
  MemoryService._();

  final MemoryCenterService _memory = MemoryCenterService.instance;

  /// 记住某件事
  Future<void> remember(String content, {double importance = 0.5}) async {
    await _memory.addMemory(
      content: content,
      type: importance > 0.7 ? MemoryType.longTerm : MemoryType.shortTerm,
      importance: importance,
    );
  }

  /// 回忆相关信息
  List<MemoryItem> recall(String query, {int limit = 5}) {
    return _memory.searchMemories(query, topK: limit);
  }

  /// 获取所有记忆
  List<MemoryItem> getAll({MemoryType? type}) {
    return _memory.getAllMemories(type: type);
  }

  /// 清除记忆
  Future<void> clear() async {
    await _memory.clearAll();
  }

  /// 删除特定记忆
  Future<void> forget(String id) async {
    await _memory.removeMemory(id);
  }
}

// ============================================================================
// 小酥 - 记忆仓库层
// ============================================================================

import '../../core/memory/memory_center.dart';

/// 记忆仓库
class MemoryRepository {
  static final MemoryRepository instance = MemoryRepository._();
  MemoryRepository._();

  final MemoryCenterService _memory = MemoryCenterService.instance;

  /// 添加记忆
  Future<MemoryItem> add(String content, {MemoryType type = MemoryType.shortTerm, double importance = 0.5}) async {
    return await _memory.addMemory(content: content, type: type, importance: importance);
  }

  /// 搜索记忆
  List<MemoryItem> search(String query, {int topK = 5}) {
    return _memory.searchMemories(query, topK: topK);
  }

  /// 删除记忆
  Future<void> remove(String id) async {
    await _memory.removeMemory(id);
  }

  /// 获取所有记忆
  List<MemoryItem> getAll({MemoryType? type}) {
    return _memory.getAllMemories(type: type);
  }

  /// 清空
  Future<void> clearAll() async {
    await _memory.clearAll();
  }
}

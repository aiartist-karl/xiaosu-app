// ============================================================================
// 小酥 - 对话仓库层
// ============================================================================

import '../models/conversation_model.dart';
import '../../services/database_service.dart';

/// 对话仓库
class ConversationRepository {
  static final ConversationRepository instance = ConversationRepository._();
  ConversationRepository._();

  final DatabaseService _db = DatabaseService.instance;

  /// 获取所有对话
  Future<List<ConversationModel>> getAll({String status = 'active'}) async {
    return await _db.getConversations(status: status);
  }

  /// 获取单个对话
  Future<ConversationModel?> getById(String id) async {
    return await _db.getConversation(id);
  }

  /// 创建对话
  Future<void> create(ConversationModel conversation) async {
    await _db.insertConversation(conversation);
  }

  /// 更新对话
  Future<void> update(ConversationModel conversation) async {
    await _db.updateConversation(conversation);
  }

  /// 删除对话
  Future<void> delete(String id) async {
    await _db.deleteConversation(id);
  }
}

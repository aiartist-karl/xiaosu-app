// ============================================================================
// 小酥 - 数据库服务（使用Hive + JSON序列化）
// ============================================================================

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/conversation_model.dart';
import '../data/models/user_profile_model.dart';

/// 数据库服务
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  late Box _conversationsBox;
  late Box _messagesBox;
  late Box _profileBox;
  late Box _memoriesBox;
  bool _initialized = false;

  /// 初始化数据库
  Future<void> initialize() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    _conversationsBox = Hive.box('conversations');
    _messagesBox = Hive.box('messages');
    _profileBox = Hive.box('user_profile');
    _memoriesBox = Hive.box('memories');
    _initialized = true;
  }

  // ==================== 对话操作 ====================

  Future<List<ConversationModel>> getConversations({String status = 'active'}) async {
    final results = <ConversationModel>[];
    for (final key in _conversationsBox.keys) {
      final data = _conversationsBox.get(key);
      if (data != null) {
        try {
          final map = jsonDecode(data) as Map<String, dynamic>;
          if (map['status'] == status) {
            results.add(ConversationModel.fromMap(map));
          }
        } catch (_) {}
      }
    }
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<ConversationModel?> getConversation(String id) async {
    final data = _conversationsBox.get(id);
    if (data == null) return null;
    try {
      return ConversationModel.fromMap(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertConversation(ConversationModel conversation) async {
    await _conversationsBox.put(conversation.id, jsonEncode(conversation.toMap()));
  }

  Future<void> updateConversation(ConversationModel conversation) async {
    await _conversationsBox.put(conversation.id, jsonEncode(conversation.toMap()));
  }

  Future<void> deleteConversation(String id) async {
    await _conversationsBox.delete(id);
    // 删除关联消息
    final keysToDelete = <dynamic>[];
    for (final key in _messagesBox.keys) {
      final data = _messagesBox.get(key);
      if (data != null) {
        try {
          final map = jsonDecode(data) as Map<String, dynamic>;
          if (map['conversationId'] == id) {
            keysToDelete.add(key);
          }
        } catch (_) {}
      }
    }
    await _messagesBox.deleteAll(keysToDelete);
  }

  // ==================== 消息操作 ====================

  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int limit = 100}) async {
    final results = <Map<String, dynamic>>[];
    for (final key in _messagesBox.keys) {
      final data = _messagesBox.get(key);
      if (data != null) {
        try {
          final map = jsonDecode(data) as Map<String, dynamic>;
          if (map['conversationId'] == conversationId) {
            results.add(map);
          }
        } catch (_) {}
      }
    }
    results.sort((a, b) {
      final aTime = a['timestamp'] as String? ?? '';
      final bTime = b['timestamp'] as String? ?? '';
      return aTime.compareTo(bTime);
    });
    return results.take(limit).toList();
  }

  Future<void> insertMessage(Map<String, dynamic> message) async {
    final id = message['id'] as String;
    await _messagesBox.put(id, jsonEncode(message));

    // 更新对话的消息计数
    final convId = message['conversationId'] as String;
    final convData = _conversationsBox.get(convId);
    if (convData != null) {
      try {
        final map = jsonDecode(convData) as Map<String, dynamic>;
        map['messageCount'] = (map['messageCount'] as int? ?? 0) + 1;
        final content = message['content'] as String? ?? '';
        map['lastMessage'] = content.length > 100 ? content.substring(0, 100) : content;
        map['updatedAt'] = DateTime.now().toIso8601String();
        await _conversationsBox.put(convId, jsonEncode(map));
      } catch (_) {}
    }
  }

  Future<void> deleteMessage(String id) async {
    await _messagesBox.delete(id);
  }

  // ==================== 用户资料操作 ====================

  Future<UserProfileModel?> getUserProfile() async {
    final data = _profileBox.get('default');
    if (data == null) return null;
    try {
      return UserProfileModel.fromMap(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfileModel profile) async {
    await _profileBox.put('default', jsonEncode(profile.toMap()));
  }

  Future<void> close() async {
    await _conversationsBox.close();
    await _messagesBox.close();
    await _profileBox.close();
    await _memoriesBox.close();
    _initialized = false;
  }
}

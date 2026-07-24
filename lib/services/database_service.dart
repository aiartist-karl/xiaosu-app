// ============================================================================
// 小酥 (XiaoSu) - 数据库服务
//
// 职责：
// 1. 管理本地 SQLite 数据库（通过 Drift ORM）
// 2. 存储对话、消息、任务等核心数据
// 3. 提供 CRUD 接口
// 4. 管理数据库迁移
//
// 注意：完整的 Drift 实现需要 build_runner 生成代码
// 这里提供接口定义和简化实现，完整实现在 .g.dart 生成后生效
// ============================================================================

import 'dart:async';

import 'package:logger/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:xiaosu_core/main.dart' show appLogger;
import 'package:xiaosu_core/models/chat_message.dart';
import 'package:xiaosu_core/models/conversation.dart';
import 'package:xiaosu_core/models/task_model.dart';

/// ============================================================================
/// 数据库服务 —— 本地数据存储
///
/// 使用 Hive 作为简化实现（正式版本应使用 Drift + SQLite）
/// ============================================================================
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── Hive 存储 ──────────────────────────────────────────────
  late Box<Map<dynamic, dynamic>> _conversationsBox;
  late Box<Map<dynamic, dynamic>> _messagesBox;
  late Box<Map<dynamic, dynamic>> _tasksBox;

  /// ─── 是否已初始化 ───────────────────────────────────────────
  bool _initialized = false;

  // ==========================================================================
  // 初始化
  // ==========================================================================

  /// 初始化数据库
  Future<void> initialize({required String databasePath}) async {
    if (_initialized) return;

    // 打开 Hive 存储（正式版本应替换为 Drift 数据库）
    _conversationsBox = await Hive.openBox<Map<dynamic, dynamic>>('conversations');
    _messagesBox = await Hive.openBox<Map<dynamic, dynamic>>('messages');
    _tasksBox = await Hive.openBox<Map<dynamic, dynamic>>('tasks');

    _initialized = true;
    _logger.i('🗄️ 数据库服务初始化完成 (path=$databasePath)');
  }

  // ==========================================================================
  // 对话 CRUD
  // ==========================================================================

  /// 保存对话
  Future<void> saveConversation(Conversation conversation) async {
    await _conversationsBox.put(conversation.id, conversation.toJson());
  }

  /// 获取单个对话
  Future<Conversation?> getConversation(String id) async {
    final data = _conversationsBox.get(id);
    if (data == null) return null;
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  /// 获取所有对话列表（按更新时间倒序）
  Future<List<Conversation>> getAllConversations() async {
    final list = <Conversation>[];
    for (final key in _conversationsBox.keys) {
      final data = _conversationsBox.get(key);
      if (data != null) {
        try {
          list.add(Conversation.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          _logger.w('⚠️ 解析对话失败: $e');
        }
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    await _conversationsBox.delete(id);

    // 同时删除该对话下的所有消息
    final messageKeys = _messagesBox.keys.where((k) {
      final data = _messagesBox.get(k);
      return data?['conversationId'] == id;
    }).toList();

    for (final key in messageKeys) {
      await _messagesBox.delete(key);
    }

    _logger.d('🗑️ 删除对话及消息: $id');
  }

  // ==========================================================================
  // 消息 CRUD
  // ==========================================================================

  /// 保存消息
  Future<void> saveMessage(ChatMessage message) async {
    await _messagesBox.put(message.id, message.toJson());
  }

  /// 获取对话的所有消息（按时间正序）
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final list = <ChatMessage>[];
    for (final key in _messagesBox.keys) {
      final data = _messagesBox.get(key);
      if (data != null && data['conversationId'] == conversationId) {
        try {
          list.add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          _logger.w('⚠️ 解析消息失败: $e');
        }
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// 获取最新消息（限制条数）
  Future<List<ChatMessage>> getRecentMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final all = await getMessages(conversationId);
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    await _messagesBox.delete(messageId);
  }

  // ==========================================================================
  // 任务 CRUD
  // ==========================================================================

  /// 保存任务
  Future<void> saveTask(ScheduledTask task) async {
    await _tasksBox.put(task.id, task.toJson());
  }

  /// 获取所有任务
  Future<List<ScheduledTask>> getAllTasks() async {
    final list = <ScheduledTask>[];
    for (final key in _tasksBox.keys) {
      final data = _tasksBox.get(key);
      if (data != null) {
        try {
          list.add(ScheduledTask.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          _logger.w('⚠️ 解析任务失败: $e');
        }
      }
    }
    return list;
  }

  /// 获取单个任务
  Future<ScheduledTask?> getTask(String id) async {
    final data = _tasksBox.get(id);
    if (data == null) return null;
    return ScheduledTask.fromJson(Map<String, dynamic>.from(data));
  }

  /// 删除任务
  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
  }

  // ==========================================================================
  // 数据库维护
  // ==========================================================================

  /// 获取数据库统计信息
  Future<DatabaseStats> getStats() async {
    return DatabaseStats(
      conversationsCount: _conversationsBox.length,
      messagesCount: _messagesBox.length,
      tasksCount: _tasksBox.length,
    );
  }

  /// 清空所有数据（危险操作）
  Future<void> clearAll() async {
    await _conversationsBox.clear();
    await _messagesBox.clear();
    await _tasksBox.clear();
    _logger.w('🗑️ 已清空所有数据');
  }
}

// ============================================================================
/// 数据库统计信息
/// ============================================================================
class DatabaseStats {
  final int conversationsCount;
  final int messagesCount;
  final int tasksCount;

  const DatabaseStats({
    required this.conversationsCount,
    required this.messagesCount,
    required this.tasksCount,
  });

  @override
  String toString() =>
      'DatabaseStats(conversations=$conversationsCount, messages=$messagesCount, tasks=$tasksCount)';
}

// ============================================================================
// 小酥 AI 助手 - 对话仓库
// ============================================================================
// 封装对话数据的 CRUD 操作，提供统一的对话管理接口
// 包含：消息管理、会话管理、全文检索、历史导出等功能
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/conversation_model.dart';

/// 对话仓库
/// 负责对话数据的存取，屏蔽底层数据库细节
class ConversationRepository {
  /// 数据库实例
  final AppDatabase _db;

  /// 构造函数
  ConversationRepository(this._db);

  // ============================================================================
  // 消息管理
  // ============================================================================

  /// 发送一条新消息
  ///
  /// [sessionId] 会话 ID
  /// [role] 消息角色
  /// [content] 消息内容
  /// [tokens] token 数量
  /// [metadata] 元数据
  /// 返回新消息的 ID
  Future<int> sendMessage({
    required int sessionId,
    required MessageRole role,
    required String content,
    int tokens = 0,
    MessageMetadata metadata = const MessageMetadata(),
  }) async {
    final now = DateTime.now();

    // 插入消息
    final id = await _db.insertMessage(
      ConversationsCompanion(
        sessionId: Value(sessionId),
        role: Value(role.value),
        content: Value(content),
        tokens: Value(tokens),
        createdAt: Value(now),
        metadata: Value(metadata.toJsonString()),
      ),
    );

    // 更新会话的最后更新时间
    await _db.updateSessionTimestamp(sessionId, now);

    return id;
  }

  /// 获取指定会话的所有消息
  ///
  /// [sessionId] 会话 ID
  /// 返回消息列表，按时间升序排列
  Future<List<Message>> getMessagesBySession(int sessionId) async {
    final conversations = await _db.getMessagesBySessionId(sessionId);
    return conversations.map(_toMessage).toList();
  }

  /// 获取指定会话的最近 N 条消息
  ///
  /// [sessionId] 会话 ID
  /// [limit] 返回的消息数量
  Future<List<Message>> getRecentMessages({
    required int sessionId,
    int limit = 50,
  }) async {
    // 先获取所有消息，再截取（drift 暂不支持带条件的 limit）
    final messages = await getMessagesBySession(sessionId);
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  /// 获取消息上下文（用于发送给 LLM）
  ///
  /// [sessionId] 会话 ID
  /// [maxTokens] 最大 token 数量限制
  /// [maxMessages] 最大消息数量限制
  /// 返回适合发送给 LLM 的消息列表
  Future<List<Map<String, dynamic>>> getMessagesForLLM({
    required int sessionId,
    int maxTokens = 4096,
    int maxMessages = 20,
  }) async {
    final messages = await getMessagesBySession(sessionId);

    // 从最新消息开始，向前截取，直到超出 token 或消息数量限制
    final result = <Map<String, dynamic>>[];
    int totalTokens = 0;
    int count = 0;

    for (final msg in messages.reversed) {
      if (count >= maxMessages) break;
      if (totalTokens + msg.tokens > maxTokens && result.isNotEmpty) break;

      result.insert(0, {
        'role': msg.role.value,
        'content': msg.content,
      });
      totalTokens += msg.tokens;
      count++;
    }

    return result;
  }

  /// 更新消息内容（编辑已发送的消息）
  ///
  /// [messageId] 消息 ID
  /// [newContent] 新的消息内容
  Future<bool> updateMessage(int messageId, String newContent) async {
    final existing = await _db.getMessageById(messageId);
    if (existing == null) return false;

    // 更新元数据中的编辑标记
    final metadata = MessageMetadata.fromJsonString(
      existing.metadata ?? '{}',
    ).copyWith(
      isEdited: true,
      editedAt: DateTime.now(),
    );

    // 注意：drift 直接更新
    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(messageId)))
        .write(
      ConversationsCompanion(
        content: Value(newContent),
        metadata: Value(metadata.toJsonString()),
      ),
    );

    return true;
  }

  /// 删除指定消息
  Future<bool> deleteMessage(int messageId) async {
    return await _db.deleteMessage(messageId);
  }

  /// 删除会话的所有消息
  Future<int> deleteAllMessagesInSession(int sessionId) async {
    return await _db.deleteMessagesBySessionId(sessionId);
  }

  /// 获取消息统计信息
  Future<MessageStats> getMessageStats(int sessionId) async {
    final messages = await getMessagesBySession(sessionId);
    final totalTokens = await _db.getTotalTokensBySessionId(sessionId);

    final userCount = messages.where((m) => m.isUser).length;
    final assistantCount = messages.where((m) => m.isAssistant).length;

    return MessageStats(
      totalMessages: messages.length,
      userMessages: userCount,
      assistantMessages: assistantCount,
      totalTokens: totalTokens,
    );
  }

  // ============================================================================
  // 会话管理
  // ============================================================================

  /// 创建新会话
  ///
  /// [title] 会话标题
  /// [personaId] 关联的人设 ID
  /// 返回新会话的 ID
  Future<int> createSession({
    String title = '新对话',
    int? personaId,
  }) async {
    final now = DateTime.now();
    return await _db.createSession(
      SessionsCompanion(
        title: Value(title),
        createdAt: Value(now),
        updatedAt: Value(now),
        personaId: Value(personaId),
      ),
    );
  }

  /// 获取所有会话列表
  Future<List<ChatSession>> getAllSessions() async {
    final sessions = await _db.getAllSessions();
    final result = <ChatSession>[];

    for (final s in sessions) {
      // 获取每个会话的消息数量
      final messageCount =
          (await getMessagesBySession(s.id)).length;
      result.add(ChatSession(
        id: s.id,
        title: s.title,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
        personaId: s.personaId,
        messageCount: messageCount,
      ));
    }

    return result;
  }

  /// 获取指定会话详情
  Future<ChatSession?> getSession(int sessionId) async {
    final s = await _db.getSessionById(sessionId);
    if (s == null) return null;

    final messageCount =
        (await getMessagesBySession(sessionId)).length;
    return ChatSession(
      id: s.id,
      title: s.title,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      personaId: s.personaId,
      messageCount: messageCount,
    );
  }

  /// 更新会话标题
  Future<void> updateSessionTitle(int sessionId, String title) async {
    await _db.updateSessionTitle(sessionId, title);
    await _db.updateSessionTimestamp(sessionId, DateTime.now());
  }

  /// 删除会话（同时删除关联的消息）
  Future<bool> deleteSession(int sessionId) async {
    return await _db.deleteSession(sessionId);
  }

  /// 获取会话数量
  Future<int> getSessionCount() async {
    return await _db.getSessionCount();
  }

  // ============================================================================
  // 搜索功能
  // ============================================================================

  /// 全文搜索消息
  ///
  /// [keyword] 搜索关键词
  /// 返回匹配的消息列表
  Future<List<SearchResult>> searchMessages(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final conversations = await _db.searchMessages(keyword);
    final results = <SearchResult>[];

    for (final conv in conversations) {
      final message = _toMessage(conv);
      final session = await _db.getSessionById(conv.sessionId);

      results.add(SearchResult(
        message: message,
        sessionTitle: session?.title ?? '未知会话',
        sessionId: conv.sessionId,
        matchContext: _extractContext(conv.content, keyword),
      ));
    }

    return results;
  }

  /// 搜索会话（按标题）
  Future<List<ChatSession>> searchSessions(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final sessions = await _db.searchSessions(keyword);
    return sessions
        .map((s) => ChatSession(
              id: s.id,
              title: s.title,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
              personaId: s.personaId,
            ))
        .toList();
  }

  // ============================================================================
  // 导出功能
  // ============================================================================

  /// 导出会话为 JSON 格式
  ///
  /// [sessionId] 会话 ID
  /// 返回 JSON 字符串
  Future<String> exportSessionAsJson(int sessionId) async {
    final session = await getSession(sessionId);
    if (session == null) throw Exception('会话不存在: $sessionId');

    final messages = await getMessagesBySession(sessionId);

    final export = ConversationExport(
      session: session,
      messages: messages,
      exportedAt: DateTime.now(),
    );

    return export.toFormattedJsonString();
  }

  /// 导出会话为 Markdown 格式
  ///
  /// [sessionId] 会话 ID
  /// 返回 Markdown 字符串
  Future<String> exportSessionAsMarkdown(int sessionId) async {
    final session = await getSession(sessionId);
    if (session == null) throw Exception('会话不存在: $sessionId');

    final messages = await getMessagesBySession(sessionId);

    final export = ConversationExport(
      session: session,
      messages: messages,
      exportedAt: DateTime.now(),
    );

    return export.toMarkdown();
  }

  /// 批量导出所有会话
  /// 返回会话 ID -> JSON 字符串的映射
  Future<Map<int, String>> exportAllSessions() async {
    final sessions = await getAllSessions();
    final result = <int, String>{};

    for (final session in sessions) {
      try {
        result[session.id!] = await exportSessionAsJson(session.id!);
      } catch (e) {
        // 单个会话导出失败不影响其他
        result[session.id!] = '{"error": "${e.toString()}"}';
      }
    }

    return result;
  }

  // ============================================================================
  // 工具方法
  // ============================================================================

  /// 将数据库记录转换为 Message 模型
  Message _toMessage(Conversation conv) {
    return Message(
      id: conv.id,
      sessionId: conv.sessionId,
      role: MessageRole.fromString(conv.role),
      content: conv.content,
      createdAt: conv.createdAt,
      tokens: conv.tokens,
      metadata: conv.metadata != null
          ? MessageMetadata.fromJsonString(conv.metadata!)
          : const MessageMetadata(),
    );
  }

  /// 从消息内容中提取搜索关键词的上下文
  ///
  /// [content] 消息内容
  /// [keyword] 搜索关键词
  /// [contextLength] 关键词前后保留的字符数
  String _extractContext(String content, String keyword, {int contextLength = 50}) {
    final index = content.toLowerCase().indexOf(keyword.toLowerCase());
    if (index == -1) return content.length > 100 ? '${content.substring(0, 100)}...' : content;

    final start = (index - contextLength).clamp(0, content.length);
    final end = (index + keyword.length + contextLength).clamp(0, content.length);

    String context = content.substring(start, end);
    if (start > 0) context = '...$context';
    if (end < content.length) context = '$context...';

    return context;
  }
}

// ============================================================================
// 辅助模型
// ============================================================================

/// 消息统计信息
class MessageStats {
  /// 总消息数
  final int totalMessages;

  /// 用户消息数
  final int userMessages;

  /// AI 消息数
  final int assistantMessages;

  /// 总 token 消耗
  final int totalTokens;

  const MessageStats({
    required this.totalMessages,
    required this.userMessages,
    required this.assistantMessages,
    required this.totalTokens,
  });

  /// 平均每条消息的 token 数
  double get avgTokensPerMessage {
    if (totalMessages == 0) return 0;
    return totalTokens / totalMessages;
  }

  Map<String, dynamic> toJson() => {
        'total_messages': totalMessages,
        'user_messages': userMessages,
        'assistant_messages': assistantMessages,
        'total_tokens': totalTokens,
        'avg_tokens_per_message': avgTokensPerMessage,
      };
}

/// 搜索结果
class SearchResult {
  /// 匹配的消息
  final Message message;

  /// 所属会话标题
  final String sessionTitle;

  /// 所属会话 ID
  final int sessionId;

  /// 匹配的上下文片段
  final String matchContext;

  const SearchResult({
    required this.message,
    required this.sessionTitle,
    required this.sessionId,
    required this.matchContext,
  });
}

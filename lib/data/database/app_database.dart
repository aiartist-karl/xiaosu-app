// ============================================================================
// 小酥 AI 助手 - SQLite 数据库定义
// ============================================================================
// 使用 drift 包实现数据库 ORM，支持类型安全的 SQL 查询
// 包含：对话、用户画像、话题订阅、技能安装、会话等核心表
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';

// ============================================================================
// 表定义部分
// ============================================================================

/// 对话消息表
/// 存储每条对话消息的完整信息，包括角色、内容、token 数量等
class Conversations extends Table {
  /// 主键，自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 会话 ID，关联 sessions 表
  /// 用于标识消息属于哪个对话会话
  IntColumn get sessionId => integer()
      .references(Sessions, #id, onDelete: KeyAction.cascade)
      .withDefault(const Constant(1))();

  /// 消息角色：user / assistant / system
  /// 标识消息的发送者身份
  TextColumn get role => text()
      .withDefault(const Constant('user'))
      .withConstraints(check('role IN ("user", "assistant", "system")'))();

  /// 消息内容
  /// 存储实际的对话文本
  TextColumn get content => text()();

  /// Token 数量
  /// 用于统计和计费，默认 0
  IntColumn get tokens => integer().withDefault(const Constant(0))();

  /// 创建时间戳（毫秒）
  /// 消息发送的精确时间
  IntColumn get createdAt => integer()
      .withDefault(currentTimestampInMs)
      .map(const DateTimeConverter())();

  /// 元数据 JSON 字符串
  /// 存储额外信息，如文件路径、图片 URL、工具调用结果等
  TextColumn get metadata =>
      text().nullable().withDefault(const Constant('{}'))();
}

/// 用户画像表
/// 存储从对话中提取的用户偏好、特征等信息
/// 采用键值对形式，支持置信度评分
class UserProfiles extends Table {
  /// 主键，自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 画像键名
  /// 如：preferred_language, work_schedule, interests 等
  TextColumn get key => text().withUniqueIndex()();

  /// 画像值
  /// 具体的偏好内容或特征描述
  TextColumn get value => text()();

  /// 置信度评分（0.0 - 1.0）
  /// 表示该画像信息的可靠程度，用于合并策略
  RealColumn get confidence =>
      real().withDefault(const Constant(0.8))();

  /// 最后更新时间戳
  IntColumn get updatedAt => integer()
      .withDefault(currentTimestampInMs)
      .map(const DateTimeConverter())();

  /// 来源会话 ID 列表（JSON 格式）
  /// 记录该画像信息是从哪些对话中提取的
  TextColumn get sourceSessions =>
      text().withDefault(const Constant('[]'))();
}

/// 话题订阅表
/// 存储用户订阅的持续追踪话题
class TopicSubscriptions extends Table {
  /// 主键，自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 订阅话题/查询关键词
  TextColumn get query => text()();

  /// 检查间隔（毫秒）
  /// 每隔多久检查一次该话题的更新
  IntColumn get checkIntervalMs => integer()
      .withDefault(const Constant(3600000))(); // 默认 1 小时

  /// 最后检查时间戳
  IntColumn get lastCheckAt => integer().nullable()();

  /// 最后结果的哈希值
  /// 用于判断内容是否有更新，避免重复通知
  TextColumn get lastResultsHash => text().nullable()();

  /// 通知渠道
  /// 如：app_notification, email, wechat 等
  TextColumn get notificationChannel => text()
      .withDefault(const Constant('app_notification'))();

  /// 是否激活
  /// 控制是否继续追踪该话题
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// 已安装技能表
/// 记录用户安装的技能及其配置
class SkillsInstalled extends Table {
  /// 主键，自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 技能名称（唯一索引）
  TextColumn get name => text().withUniqueIndex()();

  /// 技能版本
  TextColumn get version => text().withDefault(const Constant('1.0.0'))();

  /// 是否启用
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 安装时间戳
  IntColumn get installedAt => integer()
      .withDefault(currentTimestampInMs)
      .map(const DateTimeConverter())();

  /// 技能配置 JSON
  /// 存储技能的个性化配置参数
  TextColumn get configJson =>
      text().withDefault(const Constant('{}'))();
}

/// 会话表
/// 管理对话会话的元信息
class Sessions extends Table {
  /// 主键，自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 会话标题
  /// 可以是自动生成的摘要或用户自定义的标题
  TextColumn get title => text()();

  /// 创建时间戳
  IntColumn get createdAt => integer()
      .withDefault(currentTimestampInMs)
      .map(const DateTimeConverter())();

  /// 最后更新时间戳
  IntColumn get updatedAt => integer()
      .withDefault(currentTimestampInMs)
      .map(const DateTimeConverter())();

  /// 关联的人设 ID
  /// 标识该会话使用的 AI 人设
  IntColumn get personaId => integer().nullable()();
}

// ============================================================================
// 类型转换器
// ============================================================================

/// DateTime 与毫秒时间戳的转换器
/// 数据库存储毫秒时间戳，应用层使用 DateTime 对象
class DateTimeConverter extends TypeConverter<DateTime, int> {
  const DateTimeConverter();

  @override
  DateTime fromSql(int fromDb) {
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int toSql(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}

// ============================================================================
// 数据库定义
// ============================================================================

/// 小酥核心数据库
/// 使用 drift ORM 框架，提供类型安全的数据库操作
@DriftDatabase(
  tables: [
    Conversations,
    UserProfiles,
    TopicSubscriptions,
    SkillsInstalled,
    Sessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 构造函数
  /// [executor] 可选的查询执行器，用于测试或自定义数据库实现
  AppDatabase([QueryExecutor? executor])
      : super(executor ??= _openConnection());

  @override
  int get schemaVersion => 1;

  /// 打开数据库连接
  /// 使用 lazy 数据库，在首次使用时才真正打开
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      // TODO: 根据平台选择数据库文件路径
      // iOS: NSDocumentDirectory
      // Android: context.getDatabasePath()
      // 这里使用简单的文件路径，实际项目中需要处理平台差异
      final dbFile = 'app_database.sqlite';
      return NativeDatabase.createInBackground(dbFile);
    });
  }

  // ============================================================================
  // 对话消息 DAO
  // ============================================================================

  /// 插入一条新消息
  /// 返回新插入消息的 ID
  Future<int> insertMessage(ConversationsCompanion message) async {
    return await into(conversations).insert(message);
  }

  /// 批量插入消息
  /// 用于导入历史记录或批量同步
  Future<void> insertMessages(List<ConversationsCompanion> messages) async {
    await batch((batch) {
      batch.insertAll(conversations, messages);
    });
  }

  /// 根据 ID 获取消息
  Future<Conversation?> getMessageById(int id) async {
    return await (select(conversations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取指定会话的所有消息
  /// 按时间升序排列
  Future<List<Conversation>> getMessagesBySessionId(int sessionId) async {
    return await (select(conversations)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// 获取最近 N 条消息
  /// 用于快速加载对话历史
  Future<List<Conversation>> getRecentMessages({int limit = 50}) async {
    return await (select(conversations)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get()
        .then((messages) => messages.reversed.toList());
  }

  /// 全文搜索消息内容
  /// 支持在消息内容中搜索关键词
  Future<List<Conversation>> searchMessages(String keyword) async {
    return await (select(conversations)
          ..where((t) => t.content.like('%$keyword%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 删除指定消息
  Future<bool> deleteMessage(int id) async {
    return await (delete(conversations)..where((t) => t.id.equals(id)))
            .go() >
        0;
  }

  /// 删除会话的所有消息
  Future<int> deleteMessagesBySessionId(int sessionId) async {
    return await (delete(conversations)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }

  /// 获取会话总数
  Future<int> getMessageCount() async {
    final query = selectOnly(conversations)
      ..addColumns([conversations.id.count()]);
    final result = await query.getSingle();
    return result.read(conversations.id.count()) ?? 0;
  }

  /// 统计会话的 token 总数
  Future<int> getTotalTokensBySessionId(int sessionId) async {
    final query = selectOnly(conversations)
      ..addColumns([conversations.tokens.sum()])
      ..where(conversations.sessionId.equals(sessionId));
    final result = await query.getSingle();
    return result.read(conversations.tokens.sum()) ?? 0;
  }

  // ============================================================================
  // 用户画像 DAO
  // ============================================================================

  /// 插入或更新用户画像
  /// 如果 key 已存在则更新，否则插入
  Future<void> upsertUserProfile(UserProfilesCompanion profile) async {
    await into(userProfiles).insertOnConflictUpdate(profile);
  }

  /// 根据 key 获取画像
  Future<UserProfile?> getUserProfileByKey(String key) async {
    return await (select(userProfiles)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  /// 获取所有画像
  Future<List<UserProfile>> getAllUserProfiles() async {
    return await (select(userProfiles)
          ..orderBy([(t) => OrderingTerm.desc(t.confidence)]))
        .get();
  }

  /// 根据置信度过滤画像
  /// 只返回置信度大于等于阈值的画像
  Future<List<UserProfile>> getUserProfilesByConfidence(
      double minConfidence) async {
    return await (select(userProfiles)
          ..where((t) => t.confidence.isBiggerOrEqualValue(minConfidence))
          ..orderBy([(t) => OrderingTerm.desc(t.confidence)]))
        .get();
  }

  /// 删除画像
  Future<bool> deleteUserProfile(String key) async {
    return await (delete(userProfiles)..where((t) => t.key.equals(key)))
            .go() >
        0;
  }

  /// 清理低置信度画像
  /// 用于定期维护，移除不准确的画像信息
  Future<int> cleanUpLowConfidenceProfiles(double threshold) async {
    return await (delete(userProfiles)
          ..where((t) => t.confidence.isSmallerThanValue(threshold)))
        .go();
  }

  // ============================================================================
  // 话题订阅 DAO
  // ============================================================================

  /// 添加话题订阅
  Future<int> addTopicSubscription(
      TopicSubscriptionsCompanion subscription) async {
    return await into(topicSubscriptions).insert(subscription);
  }

  /// 获取所有活跃订阅
  Future<List<TopicSubscription>> getActiveSubscriptions() async {
    return await (select(topicSubscriptions)
          ..where((t) => t.isActive.equals(true)))
        .get();
  }

  /// 获取需要检查的订阅
  /// 返回检查间隔已到期的订阅
  Future<List<TopicSubscription>> getSubscriptionsToCheck() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return await (select(topicSubscriptions)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.lastCheckAt.isNull() |
              t.lastCheckAt.isSmallerThanValue(
                  now - t.checkIntervalMs.$column as int)))
        .get();
  }

  /// 更新订阅的最后检查时间
  Future<void> updateLastCheckAt(int id, DateTime checkTime) async {
    await (update(topicSubscriptions)..where((t) => t.id.equals(id))).write(
      TopicSubscriptionsCompanion(lastCheckAt: Value(checkTime)),
    );
  }

  /// 更新订阅的最后结果哈希
  Future<void> updateLastResultsHash(int id, String hash) async {
    await (update(topicSubscriptions)..where((t) => t.id.equals(id))).write(
      TopicSubscriptionsCompanion(lastResultsHash: Value(hash)),
    );
  }

  /// 切换订阅激活状态
  Future<void> toggleSubscriptionActive(int id, bool isActive) async {
    await (update(topicSubscriptions)..where((t) => t.id.equals(id))).write(
      TopicSubscriptionsCompanion(isActive: Value(isActive)),
    );
  }

  /// 删除订阅
  Future<bool> deleteTopicSubscription(int id) async {
    return await (delete(topicSubscriptions)..where((t) => t.id.equals(id)))
            .go() >
        0;
  }

  // ============================================================================
  // 技能安装 DAO
  // ============================================================================

  /// 安装技能
  Future<int> installSkill(SkillsInstalledCompanion skill) async {
    return await into(skillsInstalled).insert(skill);
  }

  /// 获取所有已安装技能
  Future<List<SkillsInstalledModel>> getAllInstalledSkills() async {
    return await (select(skillsInstalled)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// 获取已启用的技能
  Future<List<SkillsInstalledModel>> getEnabledSkills() async {
    return await (select(skillsInstalled)
          ..where((t) => t.enabled.equals(true)))
        .get();
  }

  /// 根据名称获取技能
  Future<SkillsInstalledModel?> getSkillByName(String name) async {
    return await (select(skillsInstalled)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  /// 更新技能配置
  Future<void> updateSkillConfig(int id, Map<String, dynamic> config) async {
    final configJson = jsonEncode(config);
    await (update(skillsInstalled)..where((t) => t.id.equals(id))).write(
      SkillsInstalledCompanion(configJson: Value(configJson)),
    );
  }

  /// 切换技能启用状态
  Future<void> toggleSkillEnabled(int id, bool enabled) async {
    await (update(skillsInstalled)..where((t) => t.id.equals(id))).write(
      SkillsInstalledCompanion(enabled: Value(enabled)),
    );
  }

  /// 卸载技能
  Future<bool> uninstallSkill(int id) async {
    return await (delete(skillsInstalled)..where((t) => t.id.equals(id)))
            .go() >
        0;
  }

  // ============================================================================
  // 会话 DAO
  // ============================================================================

  /// 创建新会话
  Future<int> createSession(SessionsCompanion session) async {
    return await into(sessions).insert(session);
  }

  /// 获取所有会话
  /// 按更新时间降序排列（最新的在前）
  Future<List<Session>> getAllSessions() async {
    return await (select(sessions)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 根据 ID 获取会话
  Future<Session?> getSessionById(int id) async {
    return await (select(sessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 更新会话标题
  Future<void> updateSessionTitle(int id, String title) async {
    await (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(title: Value(title)),
    );
  }

  /// 更新会话的最后更新时间
  Future<void> updateSessionTimestamp(int id, DateTime updateTime) async {
    await (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(updatedAt: Value(updateTime)),
    );
  }

  /// 删除会话及其所有消息
  /// 由于使用了 cascade 删除，会话删除时会自动删除关联的消息
  Future<bool> deleteSession(int id) async {
    return await (delete(sessions)..where((t) => t.id.equals(id))).go() > 0;
  }

  /// 获取会话数量
  Future<int> getSessionCount() async {
    final query = selectOnly(sessions)..addColumns([sessions.id.count()]);
    final result = await query.getSingle();
    return result.read(sessions.id.count()) ?? 0;
  }

  /// 搜索会话（按标题）
  Future<List<Session>> searchSessions(String keyword) async {
    return await (select(sessions)
          ..where((t) => t.title.like('%$keyword%'))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 数据库事务执行
  /// 用于需要原子性操作的场景
  Future<T> transaction<T>(Future<T> Function() action) async {
    return await transaction(action);
  }

  /// 清空所有数据（危险操作）
  /// 通常用于测试或重置应用
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(conversations).go();
      await delete(userProfiles).go();
      await delete(topicSubscriptions).go();
      await delete(skillsInstalled).go();
      await delete(sessions).go();
    });
  }
}

// ============================================================================
// 小酥 - 数据库表定义（使用Hive，无需native编译）
// ============================================================================

/// 数据库表定义文件
/// 实际存储由 DatabaseService 使用 Hive 实现
/// 此文件保留表结构定义供参考

/// 对话表结构
/// - id: String (主键)
/// - title: String
/// - systemPrompt: String
/// - modelId: String
/// - status: String
/// - messageCount: int
/// - lastMessage: String
/// - createdAt: String (ISO 8601)
/// - updatedAt: String (ISO 8601)

/// 消息表结构
/// - id: String (主键)
/// - conversationId: String (外键)
/// - content: String
/// - role: String
/// - status: String
/// - model: String
/// - tokenCount: int
/// - latency: double
/// - timestamp: String (ISO 8601)
/// - metadata: String (JSON)

/// 用户资料表结构
/// - id: String (主键)
/// - nickname: String
/// - avatar: String
/// - email: String
/// - bio: String
/// - preferredModel: String
/// - themeMode: String
/// - language: String
/// - enableMemory: int (0/1)
/// - enableVoice: int (0/1)
/// - createdAt: String
/// - updatedAt: String

/// 记忆表结构
/// - id: String (主键)
/// - content: String
/// - type: String
/// - importance: double
/// - createdAt: String
/// - lastAccessedAt: String
/// - accessCount: int
/// - metadata: String

/// 应用数据库管理器
class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
}

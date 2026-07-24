/// 小酥APP API配置
/// 后端Agent服务 + 兼容直连模式
class AppConfig {
  // ==================== 后端Agent服务 ====================
  static const String agentApiBase = 'http://47.116.29.140:8080';
  static const String agentChatEndpoint = '\$agentApiBase/api/chat';
  static const String agentWsUrl = 'ws://47.116.29.140:8080/ws/chat';

  // ==================== DeepSeek API 直连（保留兼容） ====================
  static const String apiBase = 'https://api.deepseek.com';
  static const String llmEndpoint = '\$apiBase/v1/chat/completions';
  static const String llmModel = 'deepseek-chat';
  static const String llmApiKey = 'sk-c8ab23705bf7457e888a2abafc9ec3ae';

  // 向后兼容别名
  static const String deepseekEndpoint = llmEndpoint;
  static const String deepseekApiKey = llmApiKey;
  static const String deepseekModel = llmModel;
  static const String serverHost = agentApiBase;

  // 用户认证 / 云同步
  static const String authEndpoint = '\$agentApiBase/auth';
  static const String syncEndpoint = '\$agentApiBase/sync';

  // ==================== 连接配置 ====================
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);

  // ==================== 是否使用Agent模式 ====================
  static bool useAgentMode = true;
}

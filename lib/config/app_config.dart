/// 小酥APP API配置
/// 直连 DeepSeek API
class AppConfig {
  // DeepSeek API 直连
  static const String apiBase = 'https://api.deepseek.com';
  static const String llmEndpoint = '$apiBase/v1/chat/completions';
  static const String llmModel = 'deepseek-chat';
  static const String llmApiKey = 'sk-c8ab23705bf7457e888a2abafc9ec3ae';

  // 向后兼容别名（供 llm_provider.dart 等旧代码使用）
  static const String deepseekEndpoint = llmEndpoint;
  static const String deepseekApiKey = llmApiKey;
  static const String deepseekModel = llmModel;

  // ApiGateway 默认 base
  static const String serverHost = apiBase;

  // 用户认证 / 云同步（直连模式下暂不可用，保留字段）
  static const String authEndpoint = '$apiBase/auth';
  static const String syncEndpoint = '$apiBase/sync';
}

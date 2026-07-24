/// 小酥APP API配置
/// 默认连接阿里云服务器
class AppConfig {
  // 阿里云后端服务器
  static const String serverHost = 'http://47.116.29.140:5001';
  
  // LLM API配置
  static const String llmEndpoint = '$serverHost/v1/chat/completions';
  static const String llmModel = 'deepseek-v4-flash';
  static const String llmApiKey = ''; // 服务端已配置，客户端无需key
  
  // 用户认证
  static const String authEndpoint = '$serverHost/auth';
  
  // 云同步
  static const String syncEndpoint = '$serverHost/sync';
  
  // 备用：直连DeepSeek（如果阿里云不可用）
  static const String deepseekEndpoint = 'https://api.deepseek.com/v1/chat/completions';
  static const String deepseekApiKey = 'YOUR_DEEPSEEK_API_KEY';
  static const String deepseekModel = 'deepseek-v4-flash';
}

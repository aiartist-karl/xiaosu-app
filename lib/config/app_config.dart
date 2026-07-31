// ============================================================================
// 小酥APP - API配置
// Phase 1: 对接 Coze Studio 后端，保留 DeepSeek 直连作为回退
// ============================================================================

/// 小酥APP全局配置
class AppConfig {
  // ==========================================================================
  // Coze Studio 后端配置（主通道）
  // 注意：Web 版使用空字符串（相对路径），移动端使用绝对地址
  // ==========================================================================
  static const String cozeStudioHost = ''; // Web 版使用相对路径，通过 nginx 代理
  static const String cozeStudioHostMobile = 'http://36.134.216.154:8888';

  /// Coze Studio 认证信息
  static const String cozeStudioUserId = '7666848996043784192';
  static const String cozeStudioSpaceId = '7666848996052172800';
  static const String cozeStudioBotId = '7668000000000000001'; // 全能助手 Bot
  static const String deepseekModelIdInCoze = '100001'; // DeepSeek 模型在 Coze Studio 中的 model_id

  /// PAT Token（用于 v3/v1 OpenAPI 认证）
  static const String patToken = 'xiaosu-app-pat-4ac006ffaa1b04cf432b23acb611095e';

  /// 默认 Session Key（用于 /api/ 内部接口，过期后需重新登录）
  static const String defaultSessionKey = 'eyJpZCI6NzY2ODY2NTUyNzc2OTc1OTc0NCwiY3JlYXRlZF9hdCI6IjIwMjYtMDctMzFUMTI6MTg6NTAuODE4MzQyMTYyWiIsImV4cGlyZXNfYXQiOiIyMDI2LTA4LTMwVDEyOjE4OjUwLjgxODM0MjI0NVoifWQvkGj16bIMHywd7Rws_jT4buDkTDfPN8Hn3CUAgkNc';

  /// 登录凭证（用于自动获取新 session）
  static const String loginEmail = '1643143@qq.com';
  static const String loginPassword = '1111qqqq';

  // ==========================================================================
  // DeepSeek API 直连（保留作为本地 LLM 回退）
  // ==========================================================================
  static const String apiBase = 'https://api.deepseek.com';
  static const String llmEndpoint = '$apiBase/v1/chat/completions';
  static const String llmModel = 'deepseek-chat';
  static const String llmApiKey = 'sk-c8ab23705bf7457e888a2abafc9ec3ae';

  // 向后兼容别名（供 llm_provider.dart 等旧代码使用）
  static const String deepseekEndpoint = llmEndpoint;
  static const String deepseekApiKey = llmApiKey;
  static const String deepseekModel = llmModel;

  // ==========================================================================
  // ApiGateway 默认 base → 指向 Coze Studio
  // ==========================================================================
  static const String serverHost = cozeStudioHost;

  // ==========================================================================
  // 用户认证 / 云同步（对接 Coze Studio 认证体系）
  // ==========================================================================
  static const String authEndpoint = '$cozeStudioHost/api/passport/web/email/login';
  static const String syncEndpoint = '$cozeStudioHost/api/sync';

  // ==========================================================================
  // Coze Studio API 路径常量
  // ==========================================================================
  // OpenAPI v3（PAT 认证，对话核心）— 无尾斜杠，Hertz 路由严格匹配
  static const String v3Chat = '/v3/chat';
  static const String v3ChatCancel = '/v3/chat/cancel';
  static const String v3ChatRetrieve = '/v3/chat/retrieve';
  static const String v3ChatMessageList = '/v3/chat/message/list';

  // OpenAPI v1（PAT 认证，Bot/会话管理）— 无尾斜杠
  static const String v1BotList = '/v1/bot/list';
  static const String v1ConversationCreate = '/v1/conversation/create';
  static const String v1ConversationRetrieve = '/v1/conversation/retrieve';
  static const String v1ConversationMessageList = '/v1/conversation/message/list';
  static const String v1Conversations = '/v1/conversations';

  // 内部 API（Session 认证）- 注意：后端 Django 要求 URL 有尾部斜杠
  static const String apiLogin = '/api/passport/web/email/login/';
  static const String apiAccountInfo = '/api/passport/account/info/v2/';
  static const String apiConversationChat = '/api/conversation/chat/';
  static const String apiConversationBreak = '/api/conversation/break_message/';
  static const String apiConversationMessages = '/api/conversation/get_message_list/';
  static const String apiConversationClear = '/api/conversation/clear_message/';

  // 认证方式枚举
  static const String authTypePAT = 'pat';
  static const String authTypeSession = 'session';
}

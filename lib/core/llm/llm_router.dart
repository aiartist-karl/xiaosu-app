// ============================================================================
// 小酥 - LLM 路由器（多模型智能路由）
// Phase 1: Coze Studio 作为默认模型，DeepSeek 直连作为回退
// ============================================================================

import 'llm_provider.dart';
import 'coze_studio_provider.dart';
import 'openai_provider.dart';
import 'qwen_provider.dart';

/// 任务类型（用于路由决策）
enum TaskComplexity {
  simple,    // 简单任务：闲聊、问答
  moderate,  // 中等任务：写作、分析
  complex,   // 复杂任务：推理、编程
}

/// 模型配置
class ModelConfig {
  final String id;
  final String name;
  final BaseLlmProvider provider;
  final TaskComplexity maxComplexity;
  final double costPerToken;
  final int contextWindow;
  final bool supportsStreaming;

  const ModelConfig({
    required this.id,
    required this.name,
    required this.provider,
    this.maxComplexity = TaskComplexity.complex,
    this.costPerToken = 0.0,
    this.contextWindow = 8192,
    this.supportsStreaming = true,
  });
}

/// LLM路由器 - 根据任务类型选择最佳模型
class LlmRouter {
  static final LlmRouter instance = LlmRouter._();
  LlmRouter._();

  final Map<String, ModelConfig> _models = {};
  String? _defaultModelId;
  String? _preferredProvider;

  /// 初始化路由器
  void initialize({String? defaultModel}) {
    // 注册 Coze Studio 为默认模型（通过后端代理对话）
    registerModel(ModelConfig(
      id: 'coze-studio',
      name: 'Coze Studio（全能助手）',
      provider: CozeStudioProvider.instance,
      maxComplexity: TaskComplexity.complex,
      costPerToken: 0.0, // 由后端统一管理 Token 计费
      contextWindow: 65536,
      supportsStreaming: true,
    ));

    // 注册 DeepSeek 直连作为回退
    registerModel(ModelConfig(
      id: 'deepseek-chat',
      name: 'DeepSeek V3（直连回退）',
      provider: AliyunDeepSeekProvider.instance,
      maxComplexity: TaskComplexity.complex,
      contextWindow: 65536,
    ));

    // 默认使用 Coze Studio
    _defaultModelId = defaultModel ?? 'coze-studio';
  }

  /// 注册模型
  void registerModel(ModelConfig config) {
    _models[config.id] = config;
  }

  /// 注册OpenAI模型
  void registerOpenAI({required String apiKey, String model = 'gpt-3.5-turbo'}) {
    registerModel(ModelConfig(
      id: model,
      name: 'OpenAI $model',
      provider: OpenAIProvider(apiKey: apiKey, model: model),
      maxComplexity: TaskComplexity.complex,
    ));
  }

  /// 注册Qwen模型
  void registerQwen({required String apiKey, String model = 'qwen-turbo'}) {
    registerModel(ModelConfig(
      id: model,
      name: '通义千问 $model',
      provider: QwenProvider(apiKey: apiKey, model: model),
      maxComplexity: TaskComplexity.complex,
    ));
  }

  /// 设置默认模型
  void setDefaultModel(String modelId) {
    if (_models.containsKey(modelId)) {
      _defaultModelId = modelId;
    }
  }

  /// 获取所有可用模型
  List<ModelConfig> get availableModels => _models.values.toList();

  /// 获取默认Provider
  BaseLlmProvider get defaultProvider {
    final config = _models[_defaultModelId];
    if (config != null) return config.provider;
    // 回退链：Coze Studio -> DeepSeek 直连
    if (_models.containsKey('coze-studio')) {
      return _models['coze-studio']!.provider;
    }
    return AliyunDeepSeekProvider.instance;
  }

  /// 获取 Coze Studio Provider（快捷访问）
  CozeStudioProvider get cozeStudioProvider => CozeStudioProvider.instance;

  /// 根据任务复杂度选择模型
  BaseLlmProvider route({
    TaskComplexity complexity = TaskComplexity.simple,
    String? preferredModelId,
    bool preferStreaming = false,
  }) {
    // 优先使用指定模型
    if (preferredModelId != null && _models.containsKey(preferredModelId)) {
      return _models[preferredModelId]!.provider;
    }

    // 按复杂度选择：找最便宜的能胜任的模型
    ModelConfig? best;
    for (final config in _models.values) {
      if (config.maxComplexity.index >= complexity.index) {
        if (preferStreaming && !config.supportsStreaming) continue;
        if (best == null || config.costPerToken < best.costPerToken) {
          best = config;
        }
      }
    }

    return best?.provider ?? defaultProvider;
  }

  /// 切换到回退模型（当 Coze Studio 不可用时）
  void fallbackToDirect() {
    if (_models.containsKey('deepseek-chat')) {
      _defaultModelId = 'deepseek-chat';
    }
  }

  /// 切换回 Coze Studio
  void switchBackToCozeStudio() {
    if (_models.containsKey('coze-studio')) {
      _defaultModelId = 'coze-studio';
    }
  }

  /// 当前是否使用 Coze Studio
  bool get isUsingCozeStudio => _defaultModelId == 'coze-studio';

  /// 分析消息复杂度
  TaskComplexity analyzeComplexity(String userMessage) {
    final msg = userMessage.toLowerCase();

    // 复杂任务关键词
    const complexKeywords = ['写代码', '编程', '分析', '推理', '证明', 'debug', '重构', '架构'];
    if (complexKeywords.any((k) => msg.contains(k))) {
      return TaskComplexity.complex;
    }

    // 中等任务关键词
    const moderateKeywords = ['写', '文章', '总结', '翻译', '解释', '帮我', '生成', '设计'];
    if (moderateKeywords.any((k) => msg.contains(k))) {
      return TaskComplexity.moderate;
    }

    return TaskComplexity.simple;
  }

  /// 关闭所有provider
  Future<void> dispose() async {
    for (final config in _models.values) {
      await config.provider.dispose();
    }
    _models.clear();
  }
}

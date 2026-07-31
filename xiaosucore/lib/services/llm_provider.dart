// ============================================================================
// 小酥 - LLM Provider 服务层封装
// ============================================================================

import '../core/llm/llm_provider.dart';
import '../core/llm/llm_router.dart';
import '../config/app_config.dart';

/// LLM Provider 服务层 - 为UI层提供简化的调用接口
class LlmProviderService {
  static final LlmProviderService instance = LlmProviderService._();
  LlmProviderService._();

  final LlmRouter _router = LlmRouter.instance;

  /// 快速发送消息
  Future<String> chat(String message, {String? modelId}) async {
    final provider = _router.route(
      complexity: _router.analyzeComplexity(message),
      preferredModelId: modelId,
    );
    final result = await provider.complete(
      messages: [
        {'role': 'user', 'content': message},
      ],
    );
    return result.content;
  }

  /// 流式发送消息
  Stream<String> chatStream(String message, {String? modelId}) async* {
    final provider = _router.route(
      complexity: _router.analyzeComplexity(message),
      preferredModelId: modelId,
    );
    await for (final chunk in provider.completeStream(
      messages: [
        {'role': 'user', 'content': message},
      ],
    )) {
      if (chunk.isDone) break;
      yield chunk.content;
    }
  }

  /// 获取当前模型信息
  String get currentModel => AppConfig.llmModel;

  /// 切换模型
  void switchModel(String modelId) {
    _router.setDefaultModel(modelId);
  }
}

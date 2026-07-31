// ============================================================================
// 小酥 - 依赖注入 / 服务定位器
// ============================================================================

import '../core/chat_engine.dart';
import '../core/llm/llm_router.dart';
import '../core/memory/memory_center.dart';
import '../core/memory/vector_store.dart';
import '../core/memory/embedder.dart';
import 'database_service.dart';

/// 服务定位器 - 全局依赖注入
class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._();
  ServiceLocator._();

  bool _initialized = false;

  // 核心服务
  late final DatabaseService databaseService;
  late final ChatEngine chatEngine;
  late final LlmRouter llmRouter;
  late final MemoryCenterService memoryCenter;
  late final VectorStore vectorStore;
  late final Embedder embedder;

  /// 初始化所有服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化数据库
    databaseService = DatabaseService.instance;
    await databaseService.initialize();

    // 初始化LLM路由
    llmRouter = LlmRouter.instance;
    llmRouter.initialize();

    // 初始化记忆中心
    memoryCenter = MemoryCenterService.instance;
    await memoryCenter.initialize();

    // 初始化向量存储
    vectorStore = VectorStore.instance;
    embedder = Embedder.instance;

    // 初始化对话引擎
    chatEngine = ChatEngine.instance;
    chatEngine.initialize();

    _initialized = true;
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized;

  /// 获取服务（泛型）
  T get<T>() {
    switch (T) {
      case DatabaseService:
        return databaseService as T;
      case ChatEngine:
        return chatEngine as T;
      case LlmRouter:
        return llmRouter as T;
      case MemoryCenterService:
        return memoryCenter as T;
      case VectorStore:
        return vectorStore as T;
      case Embedder:
        return embedder as T;
      default:
        throw Exception('未注册的服务类型: $T');
    }
  }

  /// 释放所有服务
  Future<void> dispose() async {
    await chatEngine.dispose();
    await llmRouter.dispose();
    await databaseService.close();
    _initialized = false;
  }
}

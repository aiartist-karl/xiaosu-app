// ============================================================================
// 小酥 AI 助手 - 统一服务定位器 (ServiceLocator)
// ============================================================================
// 全局依赖注入容器，统一管理核心服务和技能系统的生命周期
// 连接 core 层（ChatEngine / MemoryCenter / LLMRouter 等）与 skills 层
// 提供单例访问、懒加载、健康检查和优雅启停
// ============================================================================

import 'dart:async';

import '../core/skill/skill.dart';
import '../core/skill/skill_registry.dart';
import '../core/gateway/api_gateway.dart';
import '../core/gateway/credential_manager.dart' show CredentialManager, SecureStorage, Credential;
import '../core/agent/agent.dart' show AgentRegistry;
import '../core/agent/agent_bus.dart';
import '../core/agent/supervisor_agent.dart';
import '../core/llm/llm_router.dart' show LlmRouter, RoutingStrategy;
import '../core/llm/llm_provider.dart' show LlmProvider;
import '../core/memory/memory_center.dart';
import '../core/memory/embedder.dart' show Embedder;
import '../core/memory/vector_store.dart' show VectorStore;
import '../core/chat_engine.dart';
import '../core/task/task_scheduler.dart';
import '../skills/p1_skill_registry.dart';
import '../skills/all_skills_bootstrap.dart';

// ============================================================================
// 服务包装器
// ============================================================================

/// 服务包装器 — 封装单个服务的注册信息
class _ServiceEntry<T> {
  /// 工厂函数（懒加载时使用）
  final T Function()? factory;

  /// 已创建的实例
  T? instance;

  /// 是否为单例
  final bool isSingleton;

  /// 是否已初始化
  bool initialized = false;

  /// 初始化时间
  DateTime? initTime;

  /// 初始化耗时
  Duration? initDuration;

  /// 依赖的服务名称列表
  final List<String> dependsOn;

  _ServiceEntry({
    this.factory,
    this.instance,
    this.isSingleton = true,
    this.dependsOn = const [],
  });
}

// ============================================================================
// 服务健康检查
// ============================================================================

/// 单个服务的健康状态
class ServiceHealthStatus {
  final String serviceName;
  final bool isHealthy;
  final bool isInitialized;
  final String? errorMessage;
  final Duration? initDuration;
  final DateTime? lastChecked;

  const ServiceHealthStatus({
    required this.serviceName,
    this.isHealthy = true,
    this.isInitialized = false,
    this.errorMessage,
    this.initDuration,
    this.lastChecked,
  });

  Map<String, dynamic> toJson() => {
        'service_name': serviceName,
        'is_healthy': isHealthy,
        'is_initialized': isInitialized,
        if (errorMessage != null) 'error_message': errorMessage,
        if (initDuration != null) 'init_duration_ms': initDuration!.inMilliseconds,
        if (lastChecked != null) 'last_checked': lastChecked!.toIso8601String(),
      };
}

/// 全局健康报告
class SystemHealthReport {
  final bool allHealthy;
  final int totalServices;
  final int healthyServices;
  final int unhealthyServices;
  final List<ServiceHealthStatus> services;
  final DateTime checkedAt;
  final Duration totalInitTime;

  const SystemHealthReport({
    required this.allHealthy,
    required this.totalServices,
    required this.healthyServices,
    required this.unhealthyServices,
    required this.services,
    required this.checkedAt,
    required this.totalInitTime,
  });

  Map<String, dynamic> toJson() => {
        'all_healthy': allHealthy,
        'total_services': totalServices,
        'healthy_services': healthyServices,
        'unhealthy_services': unhealthyServices,
        'services': services.map((s) => s.toJson()).toList(),
        'checked_at': checkedAt.toIso8601String(),
        'total_init_time_ms': totalInitTime.inMilliseconds,
      };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== 系统健康报告 ===');
    buffer.writeln('状态: ${allHealthy ? "✓ 全部健康" : "✗ 存在异常"}');
    buffer.writeln('服务总数: $totalServices');
    buffer.writeln('健康: $healthyServices | 异常: $unhealthyServices');
    buffer.writeln('总初始化耗时: ${totalInitTime.inMilliseconds}ms');
    buffer.writeln();
    for (final s in services) {
      final icon = s.isHealthy ? '✓' : '✗';
      final initStr = s.initDuration != null ? ' (${s.initDuration!.inMilliseconds}ms)' : '';
      final errStr = s.errorMessage != null ? ' [${s.errorMessage}]' : '';
      buffer.writeln('  $icon ${s.serviceName}$initStr$errStr');
    }
    return buffer.toString();
  }
}

// ============================================================================
// ServiceLocator 主类
// ============================================================================

/// 全局服务定位器
/// 应用级依赖注入容器，管理所有核心服务和技能系统的注册、获取和生命周期
class ServiceLocator {
  // ============================================================================
  // 单例
  // ============================================================================

  ServiceLocator._internal();
  static final ServiceLocator instance = ServiceLocator._internal();

  // ============================================================================
  // 服务容器
  // ============================================================================

  /// 服务注册表
  final Map<String, _ServiceEntry> _services = {};

  /// 系统是否已初始化
  bool _initialized = false;

  /// 系统是否已销毁
  bool _disposed = false;

  /// 日志
  final SkillLogger _logger = const SkillLogger('ServiceLocator');

  /// 总初始化耗时
  Duration _totalInitTime = Duration.zero;

  // ============================================================================
  // 核心服务快捷访问 (Lazy getters)
  // ============================================================================

  /// ChatEngine — 对话引擎
  ChatEngine get chatEngine => _get<ChatEngine>('chat_engine');

  /// MemoryCenter — 记忆中心
  MemoryCenter get memoryCenter => _get<MemoryCenter>('memory_center');

  /// SkillRegistry — 技能注册表
  SkillRegistry get skillRegistry => _get<SkillRegistry>('skill_registry');

  /// P1SkillRegistry — P1 技能注册中心
  P1SkillRegistry get p1SkillRegistry => _get<P1SkillRegistry>('p1_skill_registry');

  /// ApiGateway — API 网关
  ApiGateway get apiGateway => _get<ApiGateway>('api_gateway');

  /// CredentialManager — 凭证管理器
  CredentialManager get credentialManager => _get<CredentialManager>('credential_manager');

  /// TaskScheduler — 任务调度器
  TaskScheduler get taskScheduler => _get<TaskScheduler>('task_scheduler');

  /// SupervisorAgent — 任务编排 Agent
  SupervisorAgent get supervisorAgent => _get<SupervisorAgent>('supervisor_agent');

  /// AgentBus — Agent 事件总线
  AgentBus get agentBus => _get<AgentBus>('agent_bus');

  /// AgentRegistry — Agent 注册表
  AgentRegistry get agentRegistry => _get<AgentRegistry>('agent_registry');

  /// LlmRouter — LLM 智能路由
  LlmRouter get llmRouter => _get<LlmRouter>('llm_router');

  /// 系统是否已初始化
  bool get isInitialized => _initialized;

  // ============================================================================
  // 泛型获取方法
  // ============================================================================

  /// 获取已注册的服务实例
  T _get<T>(String name) {
    final entry = _services[name];
    if (entry == null) {
      throw ServiceNotFoundException('服务未注册: $name');
    }

    // 懒加载：首次获取时执行工厂
    if (entry.instance == null && entry.factory != null) {
      _logger.info('懒加载服务: $name');
      entry.instance = entry.factory!();
      entry.initialized = true;
      entry.initTime = DateTime.now();
    }

    final instance = entry.instance;
    if (instance == null) {
      throw ServiceNotFoundException('服务实例为空: $name');
    }

    return instance as T;
  }

  /// 安全获取服务（不存在返回 null）
  T? tryGet<T>(String name) {
    try {
      return _get<T>(name);
    } catch (_) {
      return null;
    }
  }

  /// 检查服务是否已注册
  bool isRegistered(String name) => _services.containsKey(name);

  /// 检查服务是否已初始化
  bool isServiceInitialized(String name) {
    final entry = _services[name];
    return entry?.initialized ?? false;
  }

  // ============================================================================
  // 服务注册
  // ============================================================================

  /// 注册服务实例（立即生效）
  void registerInstance<T>(String name, T instance, {List<String> dependsOn = const []}) {
    if (_services.containsKey(name)) {
      _logger.warning('覆盖已注册的服务: $name');
    }
    _services[name] = _ServiceEntry<T>(
      instance: instance,
      isSingleton: true,
      initialized: true,
      initTime: DateTime.now(),
      dependsOn: dependsOn,
    );
    _logger.debug('注册服务实例: $name');
  }

  /// 注册服务工厂（懒加载）
  void registerFactory<T>(String name, T Function() factory, {List<String> dependsOn = const []}) {
    if (_services.containsKey(name)) {
      _logger.warning('覆盖已注册的服务: $name');
    }
    _services[name] = _ServiceEntry<T>(
      factory: factory,
      isSingleton: true,
      dependsOn: dependsOn,
    );
    _logger.debug('注册服务工厂（懒加载）: $name');
  }

  // ============================================================================
  // 系统初始化
  // ============================================================================

  /// 初始化全部系统服务
  ///
  /// 初始化顺序：
  /// 1. 基础设施层（ApiGateway / CredentialManager / AgentBus）
  /// 2. 核心能力层（LLMRouter / MemoryCenter）
  /// 3. 业务编排层（ChatEngine / TaskScheduler / SupervisorAgent）
  /// 4. 技能系统层（SkillRegistry + P0 + P1 技能）
  Future<void> initialize({
    required ApiGatewayConfig apiGatewayConfig,
    required SecureStorage secureStorage,
    String? userId,
  }) async {
    if (_initialized) {
      _logger.warning('系统已初始化，跳过');
      return;
    }
    if (_disposed) {
      throw StateError('系统已销毁，无法重新初始化');
    }

    final totalStopwatch = Stopwatch()..start();
    _logger.info('========== 系统服务初始化开始 ==========');

    // ─── Phase 1: 基础设施层 ────────────────────────────────────
    _logger.info('[Phase 1/4] 初始化基础设施层...');

    // API 网关
    final apiGateway = ApiGateway(config: apiGatewayConfig);
    registerInstance('api_gateway', apiGateway);

    // 凭证管理器
    final credentialManager = CredentialManager(storage: secureStorage);
    registerInstance('credential_manager', credentialManager);

    // Agent 事件总线
    final agentBus = AgentBus();
    registerInstance('agent_bus', agentBus);

    _logger.info('  ✓ ApiGateway, CredentialManager, AgentBus');

    // ─── Phase 2: 核心能力层 ────────────────────────────────────
    _logger.info('[Phase 2/4] 初始化核心能力层...');

    // LLM 路由
    final llmRouter = LlmRouter(strategy: RoutingStrategy.balanced);
    registerInstance('llm_router', llmRouter);

    // 记忆中心
    final embedder = _createDefaultEmbedder();
    final vectorStore = VectorStore();
    final memoryCenter = MemoryCenter(vectorStore: vectorStore, embedder: embedder);
    registerInstance('memory_center', memoryCenter);

    _logger.info('  ✓ LLMRouter, MemoryCenter');

    // ─── Phase 3: 业务编排层 ────────────────────────────────────
    _logger.info('[Phase 3/4] 初始化业务编排层...');

    // 对话引擎
    final chatEngine = ChatEngine.instance;
    registerInstance('chat_engine', chatEngine);

    // 任务调度器
    final taskScheduler = TaskScheduler.instance;
    registerInstance('task_scheduler', taskScheduler);

    // Agent 注册表
    final agentRegistry = AgentRegistry(bus: agentBus);
    registerInstance('agent_registry', agentRegistry);

    // 任务编排 Agent（懒加载，需要 AgentRegistry）
    registerFactory('supervisor_agent', () => SupervisorAgent(
      registry: agentRegistry,
      bus: agentBus,
      llmProvider: llmRouter,
    ));

    _logger.info('  ✓ ChatEngine, TaskScheduler, SupervisorAgent');

    // ─── Phase 4: 技能系统层 ────────────────────────────────────
    _logger.info('[Phase 4/4] 初始化技能系统层...');

    // 核心 SkillRegistry
    final skillRegistry = SkillRegistry(
      contextFactory: (sessionId) => _buildSkillContext(sessionId, userId),
    );
    registerInstance('skill_registry', skillRegistry);

    // P1 技能注册中心
    final p1Registry = P1SkillRegistry(registry: skillRegistry);
    registerInstance('p1_skill_registry', p1Registry);

    // 通过 AllSkillsBootstrap 统一初始化所有技能
    await AllSkillsBootstrap.initialize(
      skillRegistry: skillRegistry,
      contextFactory: (sessionId) => _buildSkillContext(sessionId, userId),
    );

    _logger.info('  ✓ SkillRegistry + P0/P1 技能');

    totalStopwatch.stop();
    _totalInitTime = totalStopwatch.elapsed;
    _initialized = true;

    _logger.info('========== 系统服务初始化完成 (耗时 ${totalStopwatch.elapsedMilliseconds}ms) ==========');
    _logger.info('已注册服务: ${_services.keys.join(", ")}');
  }

  // ============================================================================
  // SkillContext 工厂
  // ============================================================================

  /// 构建技能上下文
  SkillContext _buildSkillContext(int? sessionId, String? userId) {
    return SkillContext(
      storage: _SkillStorageImpl(),
      http: _SkillHttpClientImpl(apiGateway: apiGateway),
      logger: SkillLogger('Skill'),
      sessionId: sessionId,
      userId: userId,
    );
  }

  // ============================================================================
  // 健康检查
  // ============================================================================

  /// 执行全局健康检查
  SystemHealthReport healthCheck() {
    final services = <ServiceHealthStatus>[];
    int healthy = 0;
    int unhealthy = 0;

    for (final entry in _services.entries) {
      final name = entry.key;
      final svc = entry.value;
      bool isHealthy = true;
      String? error;

      // 检查具体服务的健康状态
      if (name == 'skill_registry' && svc.instance is SkillRegistry) {
        final stats = (svc.instance as SkillRegistry).getStats();
        if (stats.errorSkills > 0) {
          isHealthy = false;
          error = '${stats.errorSkills} 个技能异常';
        }
      }

      if (isHealthy) {
        healthy++;
      } else {
        unhealthy++;
      }

      services.add(ServiceHealthStatus(
        serviceName: name,
        isHealthy: isHealthy,
        isInitialized: svc.initialized,
        errorMessage: error,
        initDuration: svc.initDuration,
        lastChecked: DateTime.now(),
      ));
    }

    return SystemHealthReport(
      allHealthy: unhealthy == 0,
      totalServices: _services.length,
      healthyServices: healthy,
      unhealthyServices: unhealthy,
      services: services,
      checkedAt: DateTime.now(),
      totalInitTime: _totalInitTime,
    );
  }

  /// 检查单个服务健康
  ServiceHealthStatus checkService(String name) {
    final svc = _services[name];
    if (svc == null) {
      return ServiceHealthStatus(
        serviceName: name,
        isHealthy: false,
        errorMessage: '服务未注册',
      );
    }

    return ServiceHealthStatus(
      serviceName: name,
      isHealthy: svc.instance != null,
      isInitialized: svc.initialized,
      initDuration: svc.initDuration,
      lastChecked: DateTime.now(),
    );
  }

  // ============================================================================
  // 生命周期
  // ============================================================================

  /// 获取系统概览
  Map<String, dynamic> getSystemOverview() {
    final report = healthCheck();
    return {
      'initialized': _initialized,
      'disposed': _disposed,
      'total_services': _services.length,
      'service_names': _services.keys.toList(),
      'health': report.toJson(),
      'total_init_time_ms': _totalInitTime.inMilliseconds,
    };
  }

  /// 获取所有已注册的服务名
  List<String> getRegisteredServiceNames() => _services.keys.toList();

  /// 优雅关闭所有服务
  Future<void> dispose() async {
    if (_disposed) return;

    _logger.info('========== 系统服务开始关闭 ==========');

    // 按逆序销毁服务
    final names = _services.keys.toList().reversed;

    // 先销毁技能系统
    final skillRegistry = tryGet<SkillRegistry>('skill_registry');
    if (skillRegistry != null) {
      try {
        await skillRegistry.disposeAll();
        _logger.info('  ✓ 技能系统已销毁');
      } catch (e) {
        _logger.error('技能系统销毁失败', e);
      }
    }

    // 关闭其他服务
    for (final name in names) {
      if (name == 'skill_registry') continue;
      try {
        final svc = _services[name];
        if (svc?.instance is ApiGateway) {
          await (svc!.instance as ApiGateway).dispose();
        }
        _logger.debug('  ✓ $name 已销毁');
      } catch (e) {
        _logger.error('$name 销毁失败', e);
      }
    }

    _services.clear();
    _initialized = false;
    _disposed = true;

    _logger.info('========== 系统服务已全部关闭 ==========');
  }

  /// 重置系统（用于测试）
  Future<void> reset() async {
    await dispose();
    _disposed = false;
  }
}

// ============================================================================
// SkillContext 实现（ServiceLocator 内部使用）
// ============================================================================

/// 简易 SkillStorage 实现
class _SkillStorageImpl implements SkillStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> get(String key) async => _store[key];

  @override
  Future<void> set(String key, String value) async => _store[key] = value;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<List<String>> keys() async => _store.keys.toList();

  @override
  Future<void> clear() async => _store.clear();
}

/// 简易 SkillHttpClient 实现（桥接 ApiGateway）
class _SkillHttpClientImpl implements SkillHttpClient {
  final ApiGateway _apiGateway;

  _SkillHttpClientImpl({required ApiGateway apiGateway}) : _apiGateway = apiGateway;

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    final response = await _apiGateway.get(url, headers: headers);
    if (response is ApiSuccess) {
      return response.data.toString();
    }
    throw Exception('HTTP GET 失败: $response');
  }

  @override
  Future<String> post(String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final response = await _apiGateway.post(url, headers: headers, body: body);
    if (response is ApiSuccess) {
      return response.data.toString();
    }
    throw Exception('HTTP POST 失败: $response');
  }

  @override
  Future<String> download(String url, String savePath, {
    Map<String, String>? headers,
  }) async {
    // 通过 GET 请求获取文件内容（实际项目中需实现流式下载）
    final response = await _apiGateway.get(url, headers: headers);
    if (response is ApiSuccess) {
      return response.data.toString();
    }
    throw Exception('下载失败: $response');
  }
}

// ============================================================================
// 辅助方法
// ============================================================================

/// 创建默认 Embedder 实例
/// 实际项目中根据配置选择具体的 Embedder 实现
Embedder _createDefaultEmbedder() {
  // 实际项目中需根据配置选择合适的 Embedder 实现
  // 例如：本地 Embedder、OpenAI Embedder 等
  throw UnimplementedError('需要通过具体的 Embedder 实现来创建实例');
}

// ============================================================================
// 异常
// ============================================================================

/// 服务未找到异常
class ServiceNotFoundException implements Exception {
  final String message;
  const ServiceNotFoundException(this.message);

  @override
  String toString() => 'ServiceNotFoundException: $message';
}

/// 服务初始化异常
class ServiceInitException implements Exception {
  final String serviceName;
  final String message;
  final Object? originalError;

  const ServiceInitException(this.serviceName, this.message, [this.originalError]);

  @override
  String toString() => 'ServiceInitException($serviceName): $message';
}

// ============================================================================
// 小酥 (XiaoSu) - P2 模块总注册入口
//
// 职责：
// 负责 Phase 2 所有新模块的统一初始化、健康检查和依赖注入。
// 在 ServiceLocator 完成 P0/P1 初始化之后调用，
// 将本地 LLM、工作流引擎、插件市场、离线服务、安全服务、
// 性能监控、平台调度器等模块接入系统。
// ============================================================================

import 'dart:async';

import 'package:logger/logger.dart';

import 'main.dart' show appLogger;
import 'services/service_locator.dart';
import 'platform/platform_scheduler.dart';

// ============================================================================
// 模块接口定义（P2 层）
// ============================================================================

/// 本地 LLM 引擎
abstract class LocalLlmEngine {
  Future<void> initialize();
  Future<bool> detectBackend();
  Future<String> generate(String prompt, {Map<String, dynamic>? params});
  bool get isAvailable;
  String get backendName;
  Future<void> dispose();
}

/// 工作流引擎
abstract class WorkflowEngine {
  Future<void> initialize();
  Future<List<Map<String, dynamic>>> loadSavedWorkflows();
  Future<Map<String, dynamic>> executeWorkflow(String workflowId);
  Future<void> saveWorkflow(String workflowId, Map<String, dynamic> data);
  Future<void> dispose();
}

/// 插件市场
abstract class PluginMarket {
  Future<void> initialize();
  Future<List<Map<String, dynamic>>> fetchPluginList();
  Future<void> installPlugin(String pluginId);
  Future<void> uninstallPlugin(String pluginId);
  List<Map<String, dynamic>> get installedPlugins;
  Future<void> dispose();
}

/// 离线服务
abstract class OfflineService {
  Future<void> initialize();
  bool get isOnline;
  Stream<bool> get connectivityStream;
  Future<void> cacheForOffline(String key, String data);
  Future<String?> getCachedData(String key);
  Future<void> dispose();
}

/// 安全服务
abstract class SecurityService {
  Future<void> initialize();
  Future<void> loadSecurityConfig();
  Future<bool> validateApiKey(String key);
  Future<void> encryptSensitiveData(String key, String data);
  Future<String?> decryptSensitiveData(String key);
  List<Map<String, dynamic>> get recentEvents;
  Future<void> dispose();
}

/// 性能监控
abstract class PerformanceMonitor {
  Future<void> initialize();
  void startMonitoring();
  void stopMonitoring();
  Map<String, dynamic> get currentMetrics;
  Stream<Map<String, dynamic>> get metricsStream;
  Future<void> dispose();
}

// ============================================================================
// P2 模块健康检查
// ============================================================================

/// P2 模块健康报告
class P2ModuleHealthReport {
  final String moduleName;
  final bool isHealthy;
  final String? errorMessage;
  final Duration initDuration;
  final Map<String, dynamic> extra;

  const P2ModuleHealthReport({
    required this.moduleName,
    this.isHealthy = true,
    this.errorMessage,
    this.initDuration = Duration.zero,
    this.extra = const {},
  });

  @override
  String toString() {
    final icon = isHealthy ? '✓' : '✗';
    final err = errorMessage != null ? ' [$errorMessage]' : '';
    return '  $icon $moduleName (${initDuration.inMilliseconds}ms)$err';
  }
}

/// P2 全局健康报告
class P2HealthReport {
  final bool allHealthy;
  final List<P2ModuleHealthReport> modules;
  final Duration totalInitTime;
  final DateTime checkedAt;

  const P2HealthReport({
    required this.allHealthy,
    required this.modules,
    required this.totalInitTime,
    required this.checkedAt,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== P2 模块健康报告 ===');
    buffer.writeln('状态: ${allHealthy ? "✓ 全部健康" : "✗ 存在异常"}');
    buffer.writeln('模块数: ${modules.length}');
    buffer.writeln('总初始化耗时: ${totalInitTime.inMilliseconds}ms');
    buffer.writeln();
    for (final m in modules) {
      buffer.writeln(m.toString());
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'all_healthy': allHealthy,
        'module_count': modules.length,
        'total_init_time_ms': totalInitTime.inMilliseconds,
        'checked_at': checkedAt.toIso8601String(),
        'modules': modules.map((m) => {
              'name': m.moduleName,
              'healthy': m.isHealthy,
              'init_ms': m.initDuration.inMilliseconds,
              if (m.errorMessage != null) 'error': m.errorMessage,
            }).toList(),
      };
}

// ============================================================================
// P2Bootstrap 主类
// ============================================================================

/// P2 阶段总注册入口
///
/// 初始化顺序：
/// 1. LocalLlmEngine — 本地模型后端检测
/// 2. WorkflowEngine — 工作流引擎加载
/// 3. PluginMarket — 插件市场加载
/// 4. OfflineService — 网络状态检测
/// 5. SecurityService — 安全配置加载
/// 6. PerformanceMonitor — 性能监控启动
/// 7. PlatformScheduler — 平台适配初始化
class P2Bootstrap {
  P2Bootstrap._();
  static final P2Bootstrap instance = P2Bootstrap._();

  final Logger _logger = appLogger;
  final ServiceLocator _locator = ServiceLocator.instance;

  bool _initialized = false;
  bool _disposed = false;
  Duration _totalInitTime = Duration.zero;

  // ─── 模块实例缓存 ───
  LocalLlmEngine? _llmEngine;
  WorkflowEngine? _workflowEngine;
  PluginMarket? _pluginMarket;
  OfflineService? _offlineService;
  SecurityService? _securityService;
  PerformanceMonitor? _perfMonitor;
  PlatformScheduler? _platformScheduler;

  // ─── 快捷访问 ───
  LocalLlmEngine get llmEngine => _getModule(_llmEngine, 'LocalLlmEngine');
  WorkflowEngine get workflowEngine => _getModule(_workflowEngine, 'WorkflowEngine');
  PluginMarket get pluginMarket => _getModule(_pluginMarket, 'PluginMarket');
  OfflineService get offlineService => _getModule(_offlineService, 'OfflineService');
  SecurityService get securityService => _getModule(_securityService, 'SecurityService');
  PerformanceMonitor get perfMonitor => _getModule(_perfMonitor, 'PerformanceMonitor');
  PlatformScheduler get platformScheduler => _getModule(_platformScheduler, 'PlatformScheduler');

  T _getModule<T>(T? module, String name) {
    if (module == null) throw StateError('$name 未初始化，请先调用 P2Bootstrap.initialize()');
    return module;
  }

  bool get isInitialized => _initialized;

  // =========================================================================
  // 主初始化
  // =========================================================================

  /// 初始化所有 P2 模块
  static Future<void> initialize() async {
    await instance._initializeAll();
  }

  Future<void> _initializeAll() async {
    if (_initialized) {
      _logger.w('P2 模块已初始化，跳过');
      return;
    }
    if (_disposed) {
      throw StateError('P2 系统已销毁，无法重新初始化');
    }

    final totalStopwatch = Stopwatch()..start();
    _logger.i('');
    _logger.i('╔══════════════════════════════════════════╗');
    _logger.i('║  P2 模块初始化开始                       ║');
    _logger.i('╚══════════════════════════════════════════╝');
    _logger.i('');

    final healthReports = <P2ModuleHealthReport>[];

    // ─── 1. LocalLlmEngine ───
    _logger.i('[P2 1/7] 初始化 LocalLlmEngine...');
    try {
      final sw = Stopwatch()..start();
      _llmEngine = _DefaultLocalLlmEngine();
      await _llmEngine!.initialize();
      sw.stop();
      final backend = await _llmEngine!.detectBackend();
      _locator.registerInstance('local_llm_engine', _llmEngine!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'LocalLlmEngine',
        isHealthy: backend,
        initDuration: sw.elapsed,
        errorMessage: backend ? null : '未检测到本地模型后端',
      ));
      _logger.i('  ✓ LocalLlmEngine 已初始化 (${sw.elapsedMilliseconds}ms)');
      if (backend) {
        _logger.i('    后端: ${_llmEngine!.backendName}');
      } else {
        _logger.w('    ⚠ 未检测到本地模型后端，将使用云端 API');
      }
    } catch (e) {
      _logger.e('  ✗ LocalLlmEngine 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'LocalLlmEngine',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 2. WorkflowEngine ───
    _logger.i('[P2 2/7] 初始化 WorkflowEngine...');
    try {
      final sw = Stopwatch()..start();
      _workflowEngine = _DefaultWorkflowEngine();
      await _workflowEngine!.initialize();
      final saved = await _workflowEngine!.loadSavedWorkflows();
      sw.stop();
      _locator.registerInstance('workflow_engine', _workflowEngine!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'WorkflowEngine',
        initDuration: sw.elapsed,
        extra: {'saved_workflows': saved.length},
      ));
      _logger.i('  ✓ WorkflowEngine 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    已加载 ${saved.length} 个工作流');
    } catch (e) {
      _logger.e('  ✗ WorkflowEngine 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'WorkflowEngine',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 3. PluginMarket ───
    _logger.i('[P2 3/7] 初始化 PluginMarket...');
    try {
      final sw = Stopwatch()..start();
      _pluginMarket = _DefaultPluginMarket();
      await _pluginMarket!.initialize();
      final plugins = await _pluginMarket!.fetchPluginList();
      sw.stop();
      _locator.registerInstance('plugin_market', _pluginMarket!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PluginMarket',
        initDuration: sw.elapsed,
        extra: {'available_plugins': plugins.length},
      ));
      _logger.i('  ✓ PluginMarket 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    可用插件: ${plugins.length}');
    } catch (e) {
      _logger.e('  ✗ PluginMarket 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PluginMarket',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 4. OfflineService ───
    _logger.i('[P2 4/7] 初始化 OfflineService...');
    try {
      final sw = Stopwatch()..start();
      _offlineService = _DefaultOfflineService();
      await _offlineService!.initialize();
      sw.stop();
      _locator.registerInstance('offline_service', _offlineService!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'OfflineService',
        isHealthy: _offlineService!.isOnline,
        initDuration: sw.elapsed,
        extra: {'online': _offlineService!.isOnline},
      ));
      _logger.i('  ✓ OfflineService 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    网络状态: ${_offlineService!.isOnline ? "在线" : "离线"}');
    } catch (e) {
      _logger.e('  ✗ OfflineService 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'OfflineService',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 5. SecurityService ───
    _logger.i('[P2 5/7] 初始化 SecurityService...');
    try {
      final sw = Stopwatch()..start();
      _securityService = _DefaultSecurityService();
      await _securityService!.initialize();
      await _securityService!.loadSecurityConfig();
      sw.stop();
      _locator.registerInstance('security_service', _securityService!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'SecurityService',
        initDuration: sw.elapsed,
      ));
      _logger.i('  ✓ SecurityService 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    安全配置已加载');
    } catch (e) {
      _logger.e('  ✗ SecurityService 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'SecurityService',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 6. PerformanceMonitor ───
    _logger.i('[P2 6/7] 初始化 PerformanceMonitor...');
    try {
      final sw = Stopwatch()..start();
      _perfMonitor = _DefaultPerformanceMonitor();
      await _perfMonitor!.initialize();
      _perfMonitor!.startMonitoring();
      sw.stop();
      _locator.registerInstance('performance_monitor', _perfMonitor!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PerformanceMonitor',
        initDuration: sw.elapsed,
      ));
      _logger.i('  ✓ PerformanceMonitor 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    监控已启动');
    } catch (e) {
      _logger.e('  ✗ PerformanceMonitor 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PerformanceMonitor',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 7. PlatformScheduler ───
    _logger.i('[P2 7/7] 初始化 PlatformScheduler...');
    try {
      final sw = Stopwatch()..start();
      _platformScheduler = PlatformScheduler();
      await _platformScheduler!.initPlatform();
      await _platformScheduler!.registerPlatformServices();
      sw.stop();
      _locator.registerInstance('platform_scheduler', _platformScheduler!);
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PlatformScheduler',
        initDuration: sw.elapsed,
        extra: {'platform': _platformScheduler!.currentPlatform.name},
      ));
      _logger.i('  ✓ PlatformScheduler 已初始化 (${sw.elapsedMilliseconds}ms)');
      _logger.i('    平台: ${_platformScheduler!.currentPlatform.name}');
    } catch (e) {
      _logger.e('  ✗ PlatformScheduler 初始化失败: $e');
      healthReports.add(P2ModuleHealthReport(
        moduleName: 'PlatformScheduler',
        isHealthy: false,
        errorMessage: e.toString(),
      ));
    }

    // ─── 完成 ───
    totalStopwatch.stop();
    _totalInitTime = totalStopwatch.elapsed;
    _initialized = true;

    final healthyCount = healthReports.where((r) => r.isHealthy).length;
    final unhealthyCount = healthReports.where((r) => !r.isHealthy).length;

    _logger.i('');
    _logger.i('╔══════════════════════════════════════════╗');
    _logger.i('║  P2 模块初始化完成                       ║');
    _logger.i('╚══════════════════════════════════════════╝');
    _logger.i('');
    _logger.i('  总耗时: ${_totalInitTime.inMilliseconds}ms');
    _logger.i('  健康: $healthyCount | 异常: $unhealthyCount | 总计: ${healthReports.length}');
    _logger.i('');
    for (final r in healthReports) {
      _logger.i(r.toString());
    }
    _logger.i('');
  }

  // =========================================================================
  // 健康检查
  // =========================================================================

  /// 执行 P2 模块健康检查
  P2HealthReport healthCheck() {
    final modules = <P2ModuleHealthReport>[];

    modules.add(P2ModuleHealthReport(
      moduleName: 'LocalLlmEngine',
      isHealthy: _llmEngine?.isAvailable ?? false,
      errorMessage: _llmEngine == null ? '未初始化' : (_llmEngine!.isAvailable ? null : '后端不可用'),
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'WorkflowEngine',
      isHealthy: _workflowEngine != null,
      errorMessage: _workflowEngine == null ? '未初始化' : null,
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'PluginMarket',
      isHealthy: _pluginMarket != null,
      errorMessage: _pluginMarket == null ? '未初始化' : null,
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'OfflineService',
      isHealthy: _offlineService != null,
      errorMessage: _offlineService == null ? '未初始化' : null,
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'SecurityService',
      isHealthy: _securityService != null,
      errorMessage: _securityService == null ? '未初始化' : null,
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'PerformanceMonitor',
      isHealthy: _perfMonitor != null,
      errorMessage: _perfMonitor == null ? '未初始化' : null,
    ));
    modules.add(P2ModuleHealthReport(
      moduleName: 'PlatformScheduler',
      isHealthy: _platformScheduler?.isInitialized ?? false,
      errorMessage: _platformScheduler == null ? '未初始化'
        : (!_platformScheduler!.isInitialized ? '未就绪' : null),
    ));

    return P2HealthReport(
      allHealthy: modules.every((m) => m.isHealthy),
      modules: modules,
      totalInitTime: _totalInitTime,
      checkedAt: DateTime.now(),
    );
  }

  // =========================================================================
  // 模块间依赖注入
  // =========================================================================

  /// 获取 P2 系统概览
  Map<String, dynamic> getSystemOverview() {
    final report = healthCheck();
    return {
      'initialized': _initialized,
      'total_init_time_ms': _totalInitTime.inMilliseconds,
      'health': report.toJson(),
      'llm_available': _llmEngine?.isAvailable ?? false,
      'llm_backend': _llmEngine?.backendName,
      'online': _offlineService?.isOnline,
      'platform': _platformScheduler?.currentPlatform.name,
    };
  }

  // =========================================================================
  // 生命周期
  // =========================================================================

  /// 释放所有 P2 模块
  Future<void> dispose() async {
    if (_disposed) return;
    _logger.i('P2 模块开始释放...');

    if (_perfMonitor != null) {
      _perfMonitor!.stopMonitoring();
      await _perfMonitor!.dispose();
    }
    if (_platformScheduler != null) {
      await _platformScheduler!.dispose();
    }
    if (_offlineService != null) {
      await _offlineService!.dispose();
    }
    if (_securityService != null) {
      await _securityService!.dispose();
    }
    if (_pluginMarket != null) {
      await _pluginMarket!.dispose();
    }
    if (_workflowEngine != null) {
      await _workflowEngine!.dispose();
    }
    if (_llmEngine != null) {
      await _llmEngine!.dispose();
    }

    _llmEngine = null;
    _workflowEngine = null;
    _pluginMarket = null;
    _offlineService = null;
    _securityService = null;
    _perfMonitor = null;
    _platformScheduler = null;

    _initialized = false;
    _disposed = true;
    _logger.i('P2 模块已全部释放');
  }
}

// ============================================================================
// 默认实现（桩实现，真实项目中替换为具体实现）
// ============================================================================

class _DefaultLocalLlmEngine implements LocalLlmEngine {
  bool _available = false;
  String _backend = 'none';

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<bool> detectBackend() async {
    // 模拟检测：检查本地是否有 llama.cpp / Ollama / MLX 等
    await Future.delayed(const Duration(milliseconds: 100));
    _available = false;
    _backend = 'none';
    return _available;
  }

  @override
  Future<String> generate(String prompt, {Map<String, dynamic>? params}) async {
    if (!_available) throw StateError('本地 LLM 引擎不可用');
    return '本地生成结果: $prompt';
  }

  @override
  bool get isAvailable => _available;

  @override
  String get backendName => _backend;

  @override
  Future<void> dispose() async {}
}

class _DefaultWorkflowEngine implements WorkflowEngine {
  final Map<String, Map<String, dynamic>> _workflows = {};

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 30));
  }

  @override
  Future<List<Map<String, dynamic>>> loadSavedWorkflows() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _workflows.values.toList();
  }

  @override
  Future<Map<String, dynamic>> executeWorkflow(String workflowId) async {
    final wf = _workflows[workflowId];
    if (wf == null) throw ArgumentError('工作流不存在: $workflowId');
    await Future.delayed(const Duration(milliseconds: 100));
    return {'status': 'completed', 'workflowId': workflowId};
  }

  @override
  Future<void> saveWorkflow(String workflowId, Map<String, dynamic> data) async {
    _workflows[workflowId] = data;
  }

  @override
  Future<void> dispose() async {
    _workflows.clear();
  }
}

class _DefaultPluginMarket implements PluginMarket {
  final List<Map<String, dynamic>> _installed = [];

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 40));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPluginList() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      {'id': 'web_search', 'name': '网络搜索', 'version': '2.3.1'},
      {'id': 'image_gen', 'name': '图片生成', 'version': '1.6.0'},
      {'id': 'code_exec', 'name': '代码执行', 'version': '3.0.2'},
      {'id': 'pdf_tools', 'name': 'PDF 工具箱', 'version': '1.2.0'},
      {'id': 'data_analysis', 'name': '数据分析', 'version': '2.1.0'},
    ];
  }

  @override
  Future<void> installPlugin(String pluginId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _installed.add({'id': pluginId, 'installedAt': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> uninstallPlugin(String pluginId) async {
    _installed.removeWhere((p) => p['id'] == pluginId);
  }

  @override
  List<Map<String, dynamic>> get installedPlugins => List.unmodifiable(_installed);

  @override
  Future<void> dispose() async {
    _installed.clear();
  }
}

class _DefaultOfflineService implements OfflineService {
  bool _online = true;
  final Map<String, String> _cache = {};
  final StreamController<bool> _connectivityController = StreamController.broadcast();

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 30));
    _online = true;
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get connectivityStream => _connectivityController.stream;

  @override
  Future<void> cacheForOffline(String key, String data) async {
    _cache[key] = data;
  }

  @override
  Future<String?> getCachedData(String key) async {
    return _cache[key];
  }

  @override
  Future<void> dispose() async {
    await _connectivityController.close();
    _cache.clear();
  }
}

class _DefaultSecurityService implements SecurityService {
  final List<Map<String, dynamic>> _events = [];
  final Map<String, String> _encrypted = {};

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> loadSecurityConfig() async {
    await Future.delayed(const Duration(milliseconds: 30));
  }

  @override
  Future<bool> validateApiKey(String key) async {
    return key.isNotEmpty && key.length >= 16;
  }

  @override
  Future<void> encryptSensitiveData(String key, String data) async {
    // 实际项目中使用 AES 或平台安全存储
    _encrypted[key] = 'encrypted:$data';
  }

  @override
  Future<String?> decryptSensitiveData(String key) async {
    final raw = _encrypted[key];
    if (raw == null) return null;
    return raw.replaceFirst('encrypted:', '');
  }

  @override
  List<Map<String, dynamic>> get recentEvents => List.unmodifiable(_events);

  @override
  Future<void> dispose() async {
    _events.clear();
    _encrypted.clear();
  }
}

class _DefaultPerformanceMonitor implements PerformanceMonitor {
  bool _monitoring = false;
  Timer? _timer;
  final StreamController<Map<String, dynamic>> _metricsController =
      StreamController.broadcast();

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 20));
  }

  @override
  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _metricsController.add(currentMetrics);
    });
  }

  @override
  void stopMonitoring() {
    _monitoring = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Map<String, dynamic> get currentMetrics => {
        'cpu': 25.0 + DateTime.now().millisecondsSinceEpoch % 50,
        'memory_mb': 128 + DateTime.now().millisecondsSinceEpoch % 64,
        'uptime_seconds': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'timestamp': DateTime.now().toIso8601String(),
      };

  @override
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;

  @override
  Future<void> dispose() async {
    stopMonitoring();
    await _metricsController.close();
  }
}

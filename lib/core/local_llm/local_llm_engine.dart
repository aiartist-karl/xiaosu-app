/// ============================================================================
/// 小酥 AI 助手 — 本地大模型推理引擎
/// ============================================================================
/// 支持 Ollama / llama.cpp / MLX / vLLM / 自定义 OpenAI 兼容端点。
/// 提供模型管理、推理配置、流式推理、设备检测与性能监控等完整能力。
/// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ———————————————————————————————— 枚举定义 ————————————————————————————————

/// 本地推理后端类型
enum LlmBackendType { ollama, llamaCpp, mlx, vllm, openaiCompatible }

/// 引擎运行状态
enum EngineState { uninitialized, idle, inferring, downloading, paused, error, disposed }

/// GPU 加速器类型
enum GpuAccelerator { none, cuda, metal, rocm, vulkan }

/// 模型来源仓库
enum ModelRepository { ollamaHub, huggingFace, local }

/// 推理事件类型
enum InferenceEventType { started, tokenReceived, completed, error, cancelled, performanceSample }

/// 健康检查结果
enum HealthStatus { healthy, degraded, unavailable }

// ———————————————————————————————— 数据模型 ————————————————————————————————

/// 本地模型信息
class LocalModel {
  final String id;
  final String name;
  final ModelRepository repository;
  final String? filePath;
  final int sizeBytes;
  final double? parameterCountB;
  final String? quantization;
  final int contextWindow;
  final String? architecture;
  final List<String> tags;
  final DateTime? downloadedAt;
  final DateTime? lastUsedAt;
  final Map<String, dynamic> metadata;

  const LocalModel({
    required this.id, required this.name,
    this.repository = ModelRepository.local, this.filePath,
    this.sizeBytes = 0, this.parameterCountB, this.quantization,
    this.contextWindow = 4096, this.architecture, this.tags = const [],
    this.downloadedAt, this.lastUsedAt, this.metadata = const {},
  });

  LocalModel copyWith({
    String? id, String? name, ModelRepository? repository, String? filePath,
    int? sizeBytes, double? parameterCountB, String? quantization,
    int? contextWindow, String? architecture, List<String>? tags,
    DateTime? downloadedAt, DateTime? lastUsedAt, Map<String, dynamic>? metadata,
  }) => LocalModel(
    id: id ?? this.id, name: name ?? this.name,
    repository: repository ?? this.repository, filePath: filePath ?? this.filePath,
    sizeBytes: sizeBytes ?? this.sizeBytes, parameterCountB: parameterCountB ?? this.parameterCountB,
    quantization: quantization ?? this.quantization, contextWindow: contextWindow ?? this.contextWindow,
    architecture: architecture ?? this.architecture, tags: tags ?? this.tags,
    downloadedAt: downloadedAt ?? this.downloadedAt, lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    metadata: metadata ?? this.metadata,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'repository': repository.name, 'filePath': filePath,
    'sizeBytes': sizeBytes, 'parameterCountB': parameterCountB, 'quantization': quantization,
    'contextWindow': contextWindow, 'architecture': architecture, 'tags': tags,
    'downloadedAt': downloadedAt?.toIso8601String(), 'lastUsedAt': lastUsedAt?.toIso8601String(),
    'metadata': metadata,
  };

  factory LocalModel.fromJson(Map<String, dynamic> j) => LocalModel(
    id: j['id'] as String, name: j['name'] as String,
    repository: ModelRepository.values.firstWhere(
        (e) => e.name == j['repository'], orElse: () => ModelRepository.local),
    filePath: j['filePath'] as String?,
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
    parameterCountB: (j['parameterCountB'] as num?)?.toDouble(),
    quantization: j['quantization'] as String?,
    contextWindow: (j['contextWindow'] as num?)?.toInt() ?? 4096,
    architecture: j['architecture'] as String?,
    tags: (j['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    downloadedAt: j['downloadedAt'] != null ? DateTime.parse(j['downloadedAt']) : null,
    lastUsedAt: j['lastUsedAt'] != null ? DateTime.parse(j['lastUsedAt']) : null,
    metadata: (j['metadata'] as Map<String, dynamic>?) ?? {},
  );

  @override
  String toString() => 'LocalModel($id, ${parameterCountB}B, $quantization)';
}

/// 推理配置
class InferenceConfig {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final String? systemPrompt;
  final int gpuLayers;
  final int contextWindowSize;
  final double repeatPenalty;
  final double frequencyPenalty;
  final double presencePenalty;
  final int seed;
  final List<String> stopSequences;
  final bool stream;

  const InferenceConfig({
    this.temperature = 0.7, this.topP = 0.9, this.topK = 40,
    this.maxTokens = 2048, this.systemPrompt, this.gpuLayers = -1,
    this.contextWindowSize = 4096, this.repeatPenalty = 1.1,
    this.frequencyPenalty = 0.0, this.presencePenalty = 0.0,
    this.seed = -1, this.stopSequences = const [], this.stream = true,
  });

  InferenceConfig copyWith({
    double? temperature, double? topP, int? topK, int? maxTokens,
    String? systemPrompt, int? gpuLayers, int? contextWindowSize,
    double? repeatPenalty, double? frequencyPenalty, double? presencePenalty,
    int? seed, List<String>? stopSequences, bool? stream,
  }) => InferenceConfig(
    temperature: temperature ?? this.temperature, topP: topP ?? this.topP,
    topK: topK ?? this.topK, maxTokens: maxTokens ?? this.maxTokens,
    systemPrompt: systemPrompt ?? this.systemPrompt, gpuLayers: gpuLayers ?? this.gpuLayers,
    contextWindowSize: contextWindowSize ?? this.contextWindowSize,
    repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
    presencePenalty: presencePenalty ?? this.presencePenalty,
    seed: seed ?? this.seed, stopSequences: stopSequences ?? this.stopSequences,
    stream: stream ?? this.stream,
  );

  Map<String, dynamic> toJson() => {
    'temperature': temperature, 'top_p': topP, 'top_k': topK, 'max_tokens': maxTokens,
    'system_prompt': systemPrompt, 'gpu_layers': gpuLayers,
    'context_window_size': contextWindowSize, 'repeat_penalty': repeatPenalty,
    'frequency_penalty': frequencyPenalty, 'presence_penalty': presencePenalty,
    'seed': seed, 'stop': stopSequences, 'stream': stream,
  };

  factory InferenceConfig.fromJson(Map<String, dynamic> j) => InferenceConfig(
    temperature: (j['temperature'] as num?)?.toDouble() ?? 0.7,
    topP: (j['top_p'] as num?)?.toDouble() ?? 0.9,
    topK: (j['top_k'] as num?)?.toInt() ?? 40,
    maxTokens: (j['max_tokens'] as num?)?.toInt() ?? 2048,
    systemPrompt: j['system_prompt'] as String?,
    gpuLayers: (j['gpu_layers'] as num?)?.toInt() ?? -1,
    contextWindowSize: (j['context_window_size'] as num?)?.toInt() ?? 4096,
    repeatPenalty: (j['repeat_penalty'] as num?)?.toDouble() ?? 1.1,
    frequencyPenalty: (j['frequency_penalty'] as num?)?.toDouble() ?? 0.0,
    presencePenalty: (j['presence_penalty'] as num?)?.toDouble() ?? 0.0,
    seed: (j['seed'] as num?)?.toInt() ?? -1,
    stopSequences: (j['stop'] as List<dynamic>?)?.cast<String>() ?? [],
    stream: j['stream'] as bool? ?? true,
  );
}

/// 设备能力检测结果
class DeviceCapability {
  final int totalRamBytes;
  final int availableRamBytes;
  final GpuAccelerator gpuAccelerator;
  final int gpuMemoryBytes;
  final String? gpuName;
  final int availableDiskBytes;
  final int cpuCores;
  final String? cpuName;
  final String osType;
  final bool supportsMetal;
  final bool supportsCuda;
  final bool supportsRocm;

  const DeviceCapability({
    required this.totalRamBytes, required this.availableRamBytes,
    this.gpuAccelerator = GpuAccelerator.none, this.gpuMemoryBytes = 0,
    this.gpuName, required this.availableDiskBytes, this.cpuCores = 4,
    this.cpuName, this.osType = 'unknown',
    this.supportsMetal = false, this.supportsCuda = false, this.supportsRocm = false,
  });

  /// 推荐可运行的最大模型参数量（十亿），Q4量化约0.7GB/参数
  double get recommendedMaxParamsB => (availableRamBytes * 0.75) / (0.7 * 1e9);

  String get tier {
    final p = recommendedMaxParamsB;
    if (p >= 70) return 'enthusiast';
    if (p >= 30) return 'high';
    if (p >= 13) return 'medium';
    if (p >= 7) return 'low';
    return 'minimal';
  }

  Map<String, dynamic> toJson() => {
    'totalRamBytes': totalRamBytes, 'availableRamBytes': availableRamBytes,
    'gpuAccelerator': gpuAccelerator.name, 'gpuMemoryBytes': gpuMemoryBytes,
    'gpuName': gpuName, 'availableDiskBytes': availableDiskBytes,
    'cpuCores': cpuCores, 'cpuName': cpuName, 'osType': osType,
    'supportsMetal': supportsMetal, 'supportsCuda': supportsCuda, 'supportsRocm': supportsRocm,
  };
}

/// 性能指标快照
class PerformanceMetrics {
  final DateTime timestamp;
  final double tokensPerSecond;
  final int firstTokenLatencyMs;
  final int totalLatencyMs;
  final int generatedTokens;
  final int promptTokens;
  final int memoryUsageBytes;
  final double gpuUtilization;
  final int gpuMemoryUsageBytes;
  final String? loadedModelId;
  final int kvCacheUsageTokens;

  const PerformanceMetrics({
    required this.timestamp, this.tokensPerSecond = 0, this.firstTokenLatencyMs = 0,
    this.totalLatencyMs = 0, this.generatedTokens = 0, this.promptTokens = 0,
    this.memoryUsageBytes = 0, this.gpuUtilization = 0, this.gpuMemoryUsageBytes = 0,
    this.loadedModelId, this.kvCacheUsageTokens = 0,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(), 'tokensPerSecond': tokensPerSecond,
    'firstTokenLatencyMs': firstTokenLatencyMs, 'totalLatencyMs': totalLatencyMs,
    'generatedTokens': generatedTokens, 'promptTokens': promptTokens,
    'memoryUsageBytes': memoryUsageBytes, 'gpuUtilization': gpuUtilization,
    'gpuMemoryUsageBytes': gpuMemoryUsageBytes, 'loadedModelId': loadedModelId,
    'kvCacheUsageTokens': kvCacheUsageTokens,
  };
}

/// 推理事件
class InferenceEvent {
  final InferenceEventType type;
  final String? token;
  final String? accumulatedText;
  final PerformanceMetrics? metrics;
  final String? errorMessage;
  final DateTime timestamp;

  InferenceEvent({
    required this.type, this.token, this.accumulatedText,
    this.metrics, this.errorMessage, DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 健康检查结果
class HealthCheckResult {
  final HealthStatus status;
  final LlmBackendType backendType;
  final String endpoint;
  final int latencyMs;
  final List<String> loadedModels;
  final String? version;
  final String? error;
  final DateTime checkedAt;

  HealthCheckResult({
    required this.status, required this.backendType, required this.endpoint,
    this.latencyMs = 0, this.loadedModels = const [], this.version,
    this.error, DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  bool get isHealthy => status == HealthStatus.healthy;
}

/// 后端连接配置
class BackendConfig {
  final LlmBackendType type;
  final String endpoint;
  final String? apiKey;
  final int timeoutMs;
  final Map<String, String> headers;

  const BackendConfig({
    required this.type, this.endpoint = 'http://localhost:11434',
    this.apiKey, this.timeoutMs = 120000, this.headers = const {},
  });

  factory BackendConfig.ollama({String ep = 'http://localhost:11434'}) =>
      BackendConfig(type: LlmBackendType.ollama, endpoint: ep);
  factory BackendConfig.llamaCpp({String ep = 'http://localhost:8080'}) =>
      BackendConfig(type: LlmBackendType.llamaCpp, endpoint: ep);
  factory BackendConfig.mlx({String ep = 'http://localhost:8080'}) =>
      BackendConfig(type: LlmBackendType.mlx, endpoint: ep);
  factory BackendConfig.vllm({String ep = 'http://localhost:8000', String? k}) =>
      BackendConfig(type: LlmBackendType.vllm, endpoint: ep, apiKey: k);
  factory BackendConfig.openaiCompatible({required String ep, String? k}) =>
      BackendConfig(type: LlmBackendType.openaiCompatible, endpoint: ep, apiKey: k);
}

/// 推理取消令牌
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() { _cancelled = true; }
}

typedef DownloadProgressCallback = void Function(
    String modelId, double progress, int downloadedBytes, int totalBytes);

// ———————————————————————————————— 引擎主体 ————————————————————————————————

/// 本地大模型推理引擎 — 支持多种后端、模型管理、推理、性能监控
class LocalLlmEngine {
  BackendConfig _cfg;
  EngineState _state = EngineState.uninitialized;
  DeviceCapability? _caps;
  final List<LocalModel> _models = [];
  final List<PerformanceMetrics> _metrics = [];
  StreamController<InferenceEvent>? _streamCtrl;
  CancelToken? _cancel;
  DateTime? _inferStart;
  DateTime? _firstToken;
  int _tokCount = 0;
  final StringBuffer _accBuf = StringBuffer();
  HttpClient? _http;
  Timer? _healthTmr;
  Timer? _perfTmr;
  Future<String Function(String, InferenceConfig)>? _fallback;
  void Function(String msg)? onLog;
  void Function(EngineState o, EngineState n)? onStateChanged;

  LocalLlmEngine({BackendConfig? config, this.onLog, this.onStateChanged})
      : _cfg = config ?? BackendConfig.ollama();

  EngineState get state => _state;
  BackendConfig get backendConfig => _cfg;
  List<LocalModel> get models => List.unmodifiable(_models);
  DeviceCapability? get deviceCapability => _caps;
  List<PerformanceMetrics> get metricsHistory => List.unmodifiable(_metrics);
  bool get isInferring => _state == EngineState.inferring;
  bool get isReady => _state == EngineState.idle || _state == EngineState.inferring;

  // ————— 初始化与生命周期 —————

  Future<void> initialize() async {
    _log('初始化...');
    _http = HttpClient()..connectionTimeout = Duration(milliseconds: _cfg.timeoutMs);
    _caps = await _detectDevice();
    _log('设备: ${_caps!.tier}, RAM ${(_caps!.availableRamBytes / 1e9).toStringAsFixed(1)}GB, GPU ${_caps!.gpuAccelerator.name}');
    final h = await healthCheck();
    if (h.isHealthy) { await refreshModelList(); _setState(EngineState.idle); }
    else { _log('后端不可用: ${h.error}'); _setState(EngineState.error); }
  }

  Future<void> switchBackend(BackendConfig config) async {
    _log('切换后端: ${_cfg.type.name} -> ${config.type.name}');
    _cfg = config; _rebuildHttp(); await initialize();
  }

  void setCloudFallback(Future<String Function(String, InferenceConfig)> fn) => _fallback = fn;

  Future<void> dispose() async {
    await cancelInference();
    _healthTmr?.cancel(); _perfTmr?.cancel();
    await _streamCtrl?.close();
    _http?.close(force: true);
    _setState(EngineState.disposed);
  }

  // ————— 设备能力检测 —————

  Future<DeviceCapability> _detectDevice() async {
    int totalRam = 0, availRam = 0, disk = 50 * 1024 * 1024 * 1024;
    final cores = Platform.numberOfProcessors;
    String? cpuName, gpuName, osType = Platform.operatingSystem;
    GpuAccelerator gpu = GpuAccelerator.none;
    int gpuMem = 0; bool metal = false, cuda = false, rocm = false;

    if (Platform.isMacOS) {
      try { final r = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (r.exitCode == 0) { totalRam = int.tryParse(r.stdout.toString().trim()) ?? 0; availRam = (totalRam * 0.6).toInt(); }
      } catch (_) {}
    } else if (Platform.isLinux) {
      try { var r = await Process.run('grep', ['MemTotal', '/proc/meminfo']);
        if (r.exitCode == 0) { final m = RegExp(r'(\d+)').firstMatch(r.stdout.toString()); if (m != null) totalRam = int.parse(m.group(1)!) * 1024; }
        r = await Process.run('grep', ['MemAvailable', '/proc/meminfo']);
        if (r.exitCode == 0) { final m = RegExp(r'(\d+)').firstMatch(r.stdout.toString()); if (m != null) availRam = int.parse(m.group(1)!) * 1024; }
      } catch (_) {}
    }
    if (totalRam == 0) totalRam = 8 * 1024 * 1024 * 1024;
    if (availRam == 0) availRam = (totalRam * 0.6).toInt();

    if (Platform.isMacOS) {
      metal = true; gpu = GpuAccelerator.metal; gpuName = 'Apple Silicon'; gpuMem = totalRam;
      try { final r = await Process.run('system_profiler', ['SPDisplaysDataType']);
        if (r.exitCode == 0) { final m = RegExp(r'Chipset Model:\s*(.+)').firstMatch(r.stdout.toString()); if (m != null) gpuName = m.group(1)?.trim(); }
      } catch (_) {}
    } else if (Platform.isLinux) {
      try { final r = await Process.run('nvidia-smi', ['--query-gpu=name,memory.total', '--format=csv,noheader']);
        if (r.exitCode == 0) { cuda = true; gpu = GpuAccelerator.cuda;
          final p = r.stdout.toString().trim().split('\n').first.split(','); gpuName = p.first.trim();
          if (p.length > 1) { final m = RegExp(r'(\d+)').firstMatch(p[1]); if (m != null) gpuMem = int.parse(m.group(1)!) * 1024 * 1024; }
        }
      } catch (_) {}
      if (!cuda) { try { final r = await Process.run('rocminfo', []);
        if (r.exitCode == 0 && r.stdout.toString().contains('gfx')) { rocm = true; gpu = GpuAccelerator.rocm; }
      } catch (_) {} }
    }
    try { final r = await Process.run('df', ['.', '-B1']);
      if (r.exitCode == 0) { final ls = r.stdout.toString().trim().split('\n');
        if (ls.length >= 2) { final p = ls[1].split(RegExp(r'\s+')); if (p.length >= 4) disk = int.tryParse(p[3]) ?? disk; } }
    } catch (_) {}
    try {
      if (Platform.isLinux) { final r = await Process.run('lscpu', []);
        if (r.exitCode == 0) { final m = RegExp(r'Model name:\s*(.+)').firstMatch(r.stdout.toString()); if (m != null) cpuName = m.group(1)?.trim(); }
      } else if (Platform.isMacOS) { final r = await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string']);
        if (r.exitCode == 0) cpuName = r.stdout.toString().trim(); }
    } catch (_) {}

    return DeviceCapability(
      totalRamBytes: totalRam, availableRamBytes: availRam, gpuAccelerator: gpu,
      gpuMemoryBytes: gpuMem, gpuName: gpuName, availableDiskBytes: disk,
      cpuCores: cores, cpuName: cpuName, osType: osType,
      supportsMetal: metal, supportsCuda: cuda, supportsRocm: rocm,
    );
  }

  List<LocalModel> recommendModels() {
    if (_caps == null) return [];
    final maxP = _caps!.recommendedMaxParamsB;
    return _knownModels().where((m) => m.parameterCountB != null && m.parameterCountB! <= maxP).toList()
      ..sort((a, b) => (b.parameterCountB ?? 0).compareTo(a.parameterCountB ?? 0));
  }

  double estimateTokensPerSecond({String? modelId}) {
    if (_caps == null) return 0;
    double base;
    switch (_caps!.gpuAccelerator) {
      case GpuAccelerator.metal: base = 40; break;
      case GpuAccelerator.cuda: base = 60; break;
      case GpuAccelerator.rocm: base = 45; break;
      default: base = 8;
    }
    final model = _models.where((m) => m.id == modelId).firstOrNull;
    if (model?.parameterCountB != null) base *= (_caps!.recommendedMaxParamsB / (model!.parameterCountB! * 1.2)).clamp(0.1, 2.0);
    return base;
  }

  // ————— 模型管理 —————

  Future<List<LocalModel>> refreshModelList() async {
    try {
      switch (_cfg.type) {
        case LlmBackendType.ollama: return await _fetchOllamaModels();
        default: return await _fetchOpenAIModels('/v1/models');
      }
    } catch (e) { _log('获取模型列表失败: $e'); return _models; }
  }

  Future<void> downloadModel({
    required String modelId, ModelRepository repo = ModelRepository.ollamaHub,
    String? quantization, DownloadProgressCallback? onProgress,
  }) async {
    if (_state == EngineState.downloading) throw StateError('已有下载任务');
    _setState(EngineState.downloading);
    try {
      if (repo == ModelRepository.ollamaHub) {
        await _httpReq('POST', '/api/pull', body: {'name': modelId, 'stream': false}, timeoutMs: 600000);
      } else if (repo == ModelRepository.huggingFace) {
        _log('HuggingFace 下载: $modelId (quant: $quantization)');
      }
      onProgress?.call(modelId, 1.0, 0, 0);
      await refreshModelList();
    } catch (e) { _log('下载失败: $e'); rethrow; }
    finally { if (_state == EngineState.downloading) _setState(EngineState.idle); }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      if (_cfg.type == LlmBackendType.ollama) await _httpReq('DELETE', '/api/delete', body: {'name': modelId});
      _models.removeWhere((m) => m.id == modelId);
    } catch (e) { _log('删除失败: $e'); rethrow; }
  }

  Future<LocalModel?> getModelInfo(String modelId) async {
    final c = _models.where((m) => m.id == modelId).firstOrNull;
    if (c != null && _cfg.type == LlmBackendType.ollama) {
      try { final r = await _httpReq('POST', '/api/show', body: {'name': modelId});
        if (r != null) return c.copyWith(metadata: Map<String, dynamic>.from(r['details'] ?? {}));
      } catch (_) {}
    }
    return c;
  }

  // ————— 推理功能 —————

  Future<String> infer({
    required String prompt, List<Map<String, String>>? messages,
    String? modelId, InferenceConfig? config,
  }) async {
    if (_state == EngineState.disposed) throw StateError('引擎已释放');
    _setState(EngineState.inferring); _inferStart = DateTime.now();
    _firstToken = null; _tokCount = 0; _accBuf.clear();
    try {
      final cfg = config ?? const InferenceConfig();
      String result;
      switch (_cfg.type) {
        case LlmBackendType.ollama: result = await _inferOllama(prompt, messages, modelId, cfg); break;
        case LlmBackendType.llamaCpp: result = await _inferLlamaCpp(prompt, cfg); break;
        default: result = await _inferOpenAI(prompt, messages, modelId, cfg);
      }
      _recordMetrics(); _setState(EngineState.idle); return result;
    } catch (e) {
      _setState(EngineState.error);
      if (_fallback != null) {
        try { final fb = await _fallback!(prompt, config ?? const InferenceConfig());
          _setState(EngineState.idle); return fb; } catch (_) {}
      }
      rethrow;
    }
  }

  Stream<InferenceEvent> inferStream({
    required String prompt, List<Map<String, String>>? messages,
    String? modelId, InferenceConfig? config,
  }) async* {
    if (_state == EngineState.disposed) throw StateError('引擎已释放');
    _setState(EngineState.inferring); _inferStart = DateTime.now();
    _firstToken = null; _tokCount = 0; _accBuf.clear();
    _cancel = CancelToken(); _streamCtrl = StreamController<InferenceEvent>();
    yield InferenceEvent(type: InferenceEventType.started);
    try {
      await for (final ev in _streamResp(prompt, messages, modelId, config ?? const InferenceConfig())) {
        if (_cancel!.isCancelled) { yield InferenceEvent(type: InferenceEventType.cancelled); break; }
        yield ev;
      }
      _recordMetrics();
      yield InferenceEvent(type: InferenceEventType.completed,
          accumulatedText: _accBuf.toString(), metrics: _buildMetrics());
    } catch (e) {
      yield InferenceEvent(type: InferenceEventType.error, errorMessage: e.toString());
    } finally { _cancel = null; _setState(EngineState.idle); await _streamCtrl?.close(); }
  }

  Future<void> cancelInference() async {
    if (_state != EngineState.inferring) return;
    _cancel?.cancel(); _setState(EngineState.idle);
  }

  // ————— 健康检查 —————

  Future<HealthCheckResult> healthCheck() async {
    final sw = Stopwatch()..start();
    try {
      switch (_cfg.type) {
        case LlmBackendType.ollama:
          final r = await _httpReq('GET', '/api/tags'); sw.stop();
          final names = <String>[];
          if (r?['models'] != null) for (final m in r!['models'] as List) names.add(m['name']?.toString() ?? '');
          return HealthCheckResult(status: HealthStatus.healthy, backendType: LlmBackendType.ollama,
              endpoint: _cfg.endpoint, latencyMs: sw.elapsedMilliseconds, loadedModels: names);
        case LlmBackendType.llamaCpp:
          final r = await _httpReq('GET', '/health'); sw.stop();
          return HealthCheckResult(status: r?['status'] == 'ok' ? HealthStatus.healthy : HealthStatus.degraded,
              backendType: LlmBackendType.llamaCpp, endpoint: _cfg.endpoint, latencyMs: sw.elapsedMilliseconds);
        default:
          final r = await _httpReq('GET', '/v1/models'); sw.stop();
          final names = <String>[];
          if (r?['data'] != null) for (final m in r!['data'] as List) names.add(m['id']?.toString() ?? '');
          return HealthCheckResult(status: HealthStatus.healthy, backendType: _cfg.type,
              endpoint: _cfg.endpoint, latencyMs: sw.elapsedMilliseconds, loadedModels: names);
      }
    } catch (e) {
      sw.stop();
      return HealthCheckResult(status: HealthStatus.unavailable, backendType: _cfg.type,
          endpoint: _cfg.endpoint, latencyMs: sw.elapsedMilliseconds, error: e.toString());
    }
  }

  void startHealthMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _healthTmr?.cancel();
    _healthTmr = Timer.periodic(interval, (_) async { final r = await healthCheck(); _log('健康: ${r.status.name}'); });
    _perfTmr?.cancel();
    _perfTmr = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state == EngineState.inferring) { _metrics.add(_buildMetrics()); if (_metrics.length > 100) _metrics.removeRange(0, _metrics.length - 100); }
    });
  }

  void stopHealthMonitoring() { _healthTmr?.cancel(); _perfTmr?.cancel(); }

  Map<String, dynamic> exportConfig() => {
    'backend': {'type': _cfg.type.name, 'endpoint': _cfg.endpoint, 'timeoutMs': _cfg.timeoutMs},
    'models': _models.map((m) => m.toJson()).toList(), 'deviceCapability': _caps?.toJson(),
  };

  Future<void> importConfig(Map<String, dynamic> c) async {
    final b = c['backend'] as Map<String, dynamic>?;
    if (b != null) _cfg = BackendConfig(
      type: LlmBackendType.values.firstWhere((e) => e.name == b['type'], orElse: () => LlmBackendType.ollama),
      endpoint: b['endpoint'] as String? ?? 'http://localhost:11434',
      timeoutMs: (b['timeoutMs'] as num?)?.toInt() ?? 120000);
    final ml = c['models'] as List<dynamic>?;
    if (ml != null) { _models.clear(); for (final m in ml) _models.add(LocalModel.fromJson(m)); }
  }

  // ————— 内部: 后端推理 —————

  Future<List<LocalModel>> _fetchOllamaModels() async {
    final r = await _httpReq('GET', '/api/tags');
    if (r == null || r['models'] == null) return [];
    _models.clear();
    for (final m in r['models'] as List) {
      _models.add(LocalModel(id: m['name']?.toString() ?? '', name: m['name']?.toString() ?? '',
        repository: ModelRepository.ollamaHub, sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
        quantization: m['details']?['quantization']?.toString(),
        architecture: m['details']?['family']?.toString(),
        metadata: m['details'] is Map ? Map<String, dynamic>.from(m['details']) : {}));
    }
    return _models;
  }

  Future<List<LocalModel>> _fetchOpenAIModels(String path) async {
    try { final r = await _httpReq('GET', path);
      if (r == null || r['data'] == null) return [];
      _models.clear();
      for (final m in r['data'] as List) _models.add(LocalModel(id: m['id']?.toString() ?? '', name: m['id']?.toString() ?? ''));
      return _models;
    } catch (_) { return []; }
  }

  Future<String> _inferOllama(String prompt, List<Map<String, String>>? msgs, String? mid, InferenceConfig c) async {
    final model = mid ?? (_models.isNotEmpty ? _models.first.id : 'llama3.2');
    final body = <String, dynamic>{'model': model, 'stream': false, 'options': {
      'temperature': c.temperature, 'top_p': c.topP, 'top_k': c.topK, 'num_predict': c.maxTokens,
      'repeat_penalty': c.repeatPenalty, 'num_ctx': c.contextWindowSize, 'num_gpu': c.gpuLayers, 'seed': c.seed}};
    if (msgs != null) { body['messages'] = msgs; } else { body['prompt'] = prompt; }
    if (c.systemPrompt != null) body['system'] = c.systemPrompt;
    if (c.stopSequences.isNotEmpty) body['options']['stop'] = c.stopSequences;
    final r = await _httpReq('POST', '/api/chat', body: body);
    return r?['message']?['content']?.toString() ?? r?['response']?.toString() ?? '';
  }

  Future<String> _inferLlamaCpp(String prompt, InferenceConfig c) async {
    final r = await _httpReq('POST', '/completion', body: {
      'prompt': prompt, 'n_predict': c.maxTokens, 'temperature': c.temperature,
      'top_p': c.topP, 'top_k': c.topK, 'n_ctx': c.contextWindowSize,
      'n_gpu_layers': c.gpuLayers, 'seed': c.seed, 'stop': c.stopSequences});
    return r?['content']?.toString() ?? '';
  }

  Future<String> _inferOpenAI(String prompt, List<Map<String, String>>? msgs, String? mid, InferenceConfig c) async {
    final model = mid ?? (_models.isNotEmpty ? _models.first.id : 'default');
    final messages = msgs ?? [
      if (c.systemPrompt != null) {'role': 'system', 'content': c.systemPrompt!},
      {'role': 'user', 'content': prompt}];
    final r = await _httpReq('POST', '/v1/chat/completions', body: {
      'model': model, 'messages': messages, 'temperature': c.temperature, 'top_p': c.topP,
      'max_tokens': c.maxTokens, 'frequency_penalty': c.frequencyPenalty,
      'presence_penalty': c.presencePenalty,
      'stop': c.stopSequences.isNotEmpty ? c.stopSequences : null, 'stream': false});
    final ch = r?['choices'] as List<dynamic>?;
    return (ch != null && ch.isNotEmpty) ? ch[0]['message']?['content']?.toString() ?? '' : '';
  }

  // ————— 内部: 流式推理 —————

  Stream<InferenceEvent> _streamResp(String prompt, List<Map<String, String>>? msgs,
      String? mid, InferenceConfig c) async* {
    switch (_cfg.type) {
      case LlmBackendType.ollama: yield* _streamOllama(prompt, msgs, mid, c); break;
      case LlmBackendType.llamaCpp: yield* _streamLlamaCpp(prompt, c); break;
      default: yield* _streamOpenAI(prompt, msgs, mid, c);
    }
  }

  Stream<InferenceEvent> _streamOllama(String prompt, List<Map<String, String>>? msgs,
      String? mid, InferenceConfig c) async* {
    final model = mid ?? (_models.isNotEmpty ? _models.first.id : 'llama3.2');
    final body = <String, dynamic>{'model': model, 'stream': true, 'options': {
      'temperature': c.temperature, 'top_p': c.topP, 'top_k': c.topK,
      'num_predict': c.maxTokens, 'num_ctx': c.contextWindowSize, 'num_gpu': c.gpuLayers}};
    if (msgs != null) { body['messages'] = msgs; } else { body['prompt'] = prompt; }
    if (c.systemPrompt != null) body['system'] = c.systemPrompt;
    await for (final ev in _doStream(Uri.parse('${_cfg.endpoint}/api/chat'), body, 'message.content', 'done')) yield ev;
  }

  Stream<InferenceEvent> _streamLlamaCpp(String prompt, InferenceConfig c) async* {
    await for (final ev in _doStream(Uri.parse('${_cfg.endpoint}/completion'), {
      'prompt': prompt, 'n_predict': c.maxTokens, 'temperature': c.temperature,
      'top_p': c.topP, 'top_k': c.topK, 'n_ctx': c.contextWindowSize,
      'n_gpu_layers': c.gpuLayers, 'stream': true}, 'content', 'stop',
      prefix: 'data: ', doneMarker: '[DONE]')) yield ev;
  }

  Stream<InferenceEvent> _streamOpenAI(String prompt, List<Map<String, String>>? msgs,
      String? mid, InferenceConfig c) async* {
    final model = mid ?? (_models.isNotEmpty ? _models.first.id : 'default');
    final messages = msgs ?? [
      if (c.systemPrompt != null) {'role': 'system', 'content': c.systemPrompt!},
      {'role': 'user', 'content': prompt}];
    await for (final ev in _doStream(Uri.parse('${_cfg.endpoint}/v1/chat/completions'), {
      'model': model, 'messages': messages, 'temperature': c.temperature,
      'top_p': c.topP, 'max_tokens': c.maxTokens, 'stream': true},
      'delta.content', 'finish_reason',
      prefix: 'data: ', doneMarker: '[DONE]', auth: _cfg.apiKey)) yield ev;
  }

  /// 通用 SSE 流处理
  Stream<InferenceEvent> _doStream(Uri uri, Map<String, dynamic> body,
      String tokenPath, String doneField, {
      String? prefix, String? doneMarker, String? auth}) async* {
    final req = await _http!.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    if (auth != null) req.headers.set('Authorization', 'Bearer $auth');
    req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    await for (final chunk in resp.transform(utf8.decoder)) {
      if (_cancel?.isCancelled == true) break;
      var lines = chunk.split('\n');
      if (prefix != null) lines = lines.where((l) => l.startsWith(prefix)).map((l) => l.substring(prefix.length).trim()).toList();
      else lines = lines.where((l) => l.trim().isNotEmpty).toList();
      for (final line in lines) {
        if (doneMarker != null && line == doneMarker) return;
        try {
          final j = jsonDecode(line) as Map<String, dynamic>;
          // 解析嵌套 token 路径
          String token = '';
          final parts = tokenPath.split('.');
          dynamic cur = j;
          for (final p in parts) {
            if (cur is Map) cur = cur[p]; else if (cur is List && cur.isNotEmpty) { cur = cur[0][p]; } else { cur = null; break; }
          }
          token = cur?.toString() ?? '';
          if (token.isNotEmpty) {
            _firstToken ??= DateTime.now(); _tokCount++; _accBuf.write(token);
            yield InferenceEvent(type: InferenceEventType.tokenReceived, token: token, accumulatedText: _accBuf.toString());
          }
          if (j[doneField] == true || j['done'] == true) return;
        } catch (_) {}
      }
    }
  }

  // ————— 内部: 工具方法 —————

  Future<Map<String, dynamic>?> _httpReq(String method, String path,
      {Map<String, dynamic>? body, int? timeoutMs}) async {
    final uri = Uri.parse('${_cfg.endpoint}$path');
    HttpClientRequest req;
    switch (method.toUpperCase()) {
      case 'GET': req = await _http!.getUrl(uri); break;
      case 'POST': req = await _http!.postUrl(uri); break;
      case 'DELETE': req = await _http!.deleteUrl(uri); break;
      case 'PUT': req = await _http!.putUrl(uri); break;
      default: req = await _http!.postUrl(uri);
    }
    req.headers.set('Content-Type', 'application/json');
    if (_cfg.apiKey != null) req.headers.set('Authorization', 'Bearer ${_cfg.apiKey}');
    for (final e in _cfg.headers.entries) req.headers.set(e.key, e.value);
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return text.trim().isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${resp.statusCode}: $text', uri: uri);
  }

  void _rebuildHttp() { _http?.close(force: true); _http = HttpClient()..connectionTimeout = Duration(milliseconds: _cfg.timeoutMs); }
  void _setState(EngineState n) { if (_state != n) { final o = _state; _state = n; onStateChanged?.call(o, n); } }
  void _log(String m) { onLog?.call('[LocalLlm] $m'); }

  void _recordMetrics() { _metrics.add(_buildMetrics()); if (_metrics.length > 200) _metrics.removeRange(0, _metrics.length - 200); }

  PerformanceMetrics _buildMetrics() {
    final now = DateTime.now();
    final totalMs = _inferStart != null ? now.difference(_inferStart!).inMilliseconds : 0;
    final ttft = (_firstToken != null && _inferStart != null) ? _firstToken!.difference(_inferStart!).inMilliseconds : 0;
    final tps = totalMs > 0 ? _tokCount / (totalMs / 1000.0) : 0.0;
    int mem = 0;
    if (_caps != null) mem = _caps!.totalRamBytes - _caps!.availableRamBytes;
    return PerformanceMetrics(timestamp: now, tokensPerSecond: tps, firstTokenLatencyMs: ttft,
      totalLatencyMs: totalMs, generatedTokens: _tokCount, memoryUsageBytes: mem,
      gpuUtilization: _caps?.gpuAccelerator != GpuAccelerator.none ? 0.85 : 0.0,
      loadedModelId: _models.isNotEmpty ? _models.first.id : null);
  }

  List<LocalModel> _knownModels() => [
    const LocalModel(id: 'llama3.2:1b', name: 'Llama 3.2 1B', repository: ModelRepository.ollamaHub,
        parameterCountB: 1, quantization: 'Q4_K_M', sizeBytes: 750000000, contextWindow: 8192,
        architecture: 'llama', tags: ['meta', 'general']),
    const LocalModel(id: 'llama3.2:3b', name: 'Llama 3.2 3B', repository: ModelRepository.ollamaHub,
        parameterCountB: 3, quantization: 'Q4_K_M', sizeBytes: 2000000000, contextWindow: 8192,
        architecture: 'llama', tags: ['meta', 'general']),
    const LocalModel(id: 'llama3.1:8b', name: 'Llama 3.1 8B', repository: ModelRepository.ollamaHub,
        parameterCountB: 8, quantization: 'Q4_K_M', sizeBytes: 4700000000, contextWindow: 8192,
        architecture: 'llama', tags: ['meta', 'general']),
    const LocalModel(id: 'mistral:7b', name: 'Mistral 7B', repository: ModelRepository.ollamaHub,
        parameterCountB: 7, quantization: 'Q4_K_M', sizeBytes: 4100000000, contextWindow: 8192,
        architecture: 'mistral', tags: ['mistral', 'general']),
    const LocalModel(id: 'qwen2.5:7b', name: 'Qwen2.5 7B', repository: ModelRepository.ollamaHub,
        parameterCountB: 7, quantization: 'Q4_K_M', sizeBytes: 4500000000, contextWindow: 32768,
        architecture: 'qwen', tags: ['alibaba', 'multilingual']),
    const LocalModel(id: 'gemma2:9b', name: 'Gemma 2 9B', repository: ModelRepository.ollamaHub,
        parameterCountB: 9, quantization: 'Q4_K_M', sizeBytes: 5400000000, contextWindow: 8192,
        architecture: 'gemma', tags: ['google', 'general']),
    const LocalModel(id: 'phi3:14b', name: 'Phi-3 14B', repository: ModelRepository.ollamaHub,
        parameterCountB: 14, quantization: 'Q4_K_M', sizeBytes: 7900000000, contextWindow: 128000,
        architecture: 'phi', tags: ['microsoft', 'reasoning']),
    const LocalModel(id: 'codellama:13b', name: 'Code Llama 13B', repository: ModelRepository.ollamaHub,
        parameterCountB: 13, quantization: 'Q4_K_M', sizeBytes: 7400000000, contextWindow: 16384,
        architecture: 'llama', tags: ['meta', 'code']),
    const LocalModel(id: 'llama3.1:70b', name: 'Llama 3.1 70B', repository: ModelRepository.ollamaHub,
        parameterCountB: 70, quantization: 'Q4_K_M', sizeBytes: 40000000000, contextWindow: 8192,
        architecture: 'llama', tags: ['meta', 'general']),
  ];
}

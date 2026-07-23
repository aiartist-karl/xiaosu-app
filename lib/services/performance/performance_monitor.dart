import 'dart:async';
import 'dart:math';

// ────────────────────────────────────────────────────────────────────────────
// 数据模型
// ────────────────────────────────────────────────────────────────────────────

/// 监控指标类型
enum MetricType {
  cpu, memory, fps, network, diskIO, battery, startup, render, apiResponse,
}

/// 告警级别
enum AlertLevel { normal, warning, critical }

/// 缓存策略
enum CacheStrategy { lru, lfu, fifo, ttl }

/// CPU 指标
class CpuMetric {
  final double usagePercent, userPercent, systemPercent, perCoreAvg;
  final int coreCount;
  final DateTime timestamp;
  const CpuMetric({
    required this.usagePercent, this.userPercent = 0, this.systemPercent = 0,
    this.perCoreAvg = 0, this.coreCount = 4, required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
    'usagePercent': usagePercent, 'userPercent': userPercent,
    'systemPercent': systemPercent, 'coreCount': coreCount,
    'perCoreAvg': perCoreAvg, 'timestamp': timestamp.toIso8601String(),
  };
}

/// 内存指标
class MemoryMetric {
  final int heapUsedMB, heapTotalMB, externalMB, nativeMB, totalMB, availableMB;
  final DateTime timestamp;
  const MemoryMetric({
    required this.heapUsedMB, required this.heapTotalMB,
    this.externalMB = 0, this.nativeMB = 0, required this.totalMB,
    this.availableMB = 0, required this.timestamp,
  });
  double get heapUsagePercent =>
      heapTotalMB > 0 ? (heapUsedMB / heapTotalMB * 100) : 0;
  Map<String, dynamic> toJson() => {
    'heapUsedMB': heapUsedMB, 'heapTotalMB': heapTotalMB,
    'externalMB': externalMB, 'nativeMB': nativeMB,
    'totalMB': totalMB, 'availableMB': availableMB,
    'heapUsagePercent': heapUsagePercent, 'timestamp': timestamp.toIso8601String(),
  };
}

/// 帧率指标
class FpsMetric {
  final double currentFps, averageFps, worstFrameMs;
  final int droppedFrames, totalFrames, jankCount;
  final DateTime timestamp;
  const FpsMetric({
    required this.currentFps, this.averageFps = 60, this.worstFrameMs = 16.67,
    this.droppedFrames = 0, this.totalFrames = 0, this.jankCount = 0,
    required this.timestamp,
  });
  double get jankPercent => totalFrames > 0 ? (jankCount / totalFrames * 100) : 0;
  Map<String, dynamic> toJson() => {
    'currentFps': currentFps, 'averageFps': averageFps,
    'droppedFrames': droppedFrames, 'jankCount': jankCount,
    'worstFrameMs': worstFrameMs, 'jankPercent': jankPercent,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 网络指标
class NetworkMetric {
  final int uploadBytes, downloadBytes, requestCount, errorCount;
  final double uploadKBps, downloadKBps, avgLatencyMs;
  final DateTime timestamp;
  const NetworkMetric({
    required this.uploadBytes, required this.downloadBytes,
    this.uploadKBps = 0, this.downloadKBps = 0,
    this.requestCount = 0, this.errorCount = 0, this.avgLatencyMs = 0,
    required this.timestamp,
  });
  int get totalBytes => uploadBytes + downloadBytes;
  double get errorRate => requestCount > 0 ? (errorCount / requestCount * 100) : 0;
  Map<String, dynamic> toJson() => {
    'uploadBytes': uploadBytes, 'downloadBytes': downloadBytes,
    'requestCount': requestCount, 'errorCount': errorCount,
    'avgLatencyMs': avgLatencyMs, 'errorRate': errorRate,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 磁盘 I/O 指标
class DiskIOMetric {
  final int readBytes, writeBytes, readOps, writeOps;
  final double readMBps, writeMBps;
  final DateTime timestamp;
  const DiskIOMetric({
    required this.readBytes, required this.writeBytes,
    this.readMBps = 0, this.writeMBps = 0,
    this.readOps = 0, this.writeOps = 0, required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
    'readBytes': readBytes, 'writeBytes': writeBytes,
    'readMBps': readMBps, 'writeMBps': writeMBps,
    'readOps': readOps, 'writeOps': writeOps,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 电池指标
class BatteryMetric {
  final double levelPercent, dischargeRatePerHour;
  final bool isCharging;
  final int estimatedMinutesRemaining;
  final DateTime timestamp;
  const BatteryMetric({
    required this.levelPercent, this.dischargeRatePerHour = 0,
    this.isCharging = false, this.estimatedMinutesRemaining = 0,
    required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
    'levelPercent': levelPercent, 'isCharging': isCharging,
    'dischargeRatePerHour': dischargeRatePerHour,
    'estimatedMinutesRemaining': estimatedMinutesRemaining,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 计时指标（启动/渲染/API）
class TimingMetric {
  final String name;
  final double durationMs;
  final String? route;
  final DateTime timestamp;
  const TimingMetric({
    required this.name, required this.durationMs,
    this.route, required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
    'name': name, 'durationMs': durationMs,
    'route': route, 'timestamp': timestamp.toIso8601String(),
  };
}

/// 告警阈值配置
class AlertThreshold {
  final MetricType metricType;
  final double warningLevel, criticalLevel;
  final Duration cooldownDuration;
  final bool enabled;
  const AlertThreshold({
    required this.metricType, required this.warningLevel,
    required this.criticalLevel,
    this.cooldownDuration = const Duration(minutes: 5),
    this.enabled = true,
  });
}

/// 性能告警
class PerformanceAlert {
  final String id;
  final AlertLevel level;
  final MetricType metricType;
  final String message;
  final double currentValue, threshold;
  final DateTime timestamp;
  PerformanceAlert({
    required this.id, required this.level, required this.metricType,
    required this.message, required this.currentValue, required this.threshold,
  }) : timestamp = DateTime.now();
}

/// 综合性能评分
class PerformanceScore {
  final double overall, cpuScore, memoryScore, fpsScore, networkScore, batteryScore;
  final DateTime timestamp;
  const PerformanceScore({
    required this.overall, required this.cpuScore, required this.memoryScore,
    required this.fpsScore, required this.networkScore,
    required this.batteryScore, required this.timestamp,
  });
  String get grade {
    if (overall >= 90) return 'A';
    if (overall >= 80) return 'B';
    if (overall >= 70) return 'C';
    if (overall >= 60) return 'D';
    return 'F';
  }
}

/// 优化建议
class OptimizationSuggestion {
  final String id, category, title, description, severity;
  final double estimatedImpact;
  final List<String> steps;
  const OptimizationSuggestion({
    required this.id, required this.category, required this.title,
    required this.description, this.severity = 'info',
    this.estimatedImpact = 0, this.steps = const [],
  });
}

/// 慢查询记录
class SlowQueryEntry {
  final String id, query;
  final double durationMs;
  final int resultCount;
  final DateTime timestamp;
  final String? source;
  const SlowQueryEntry({
    required this.id, required this.query, required this.durationMs,
    this.resultCount = 0, required this.timestamp, this.source,
  });
}

/// 大对象告警
class LargeObjectAlert {
  final String id, objectType, location;
  final int sizeBytes;
  final DateTime timestamp;
  const LargeObjectAlert({
    required this.id, required this.objectType,
    required this.sizeBytes, required this.location,
  }) : timestamp = DateTime.now();
}

/// 缓存配置
class CacheConfig {
  final CacheStrategy strategy;
  final int maxSizeMB;
  final Duration ttl;
  final bool enablePreload;
  final List<String> preloadKeys;
  const CacheConfig({
    this.strategy = CacheStrategy.lru, this.maxSizeMB = 100,
    this.ttl = const Duration(hours: 1),
    this.enablePreload = false, this.preloadKeys = const [],
  });
}

// ────────────────────────────────────────────────────────────────────────────
// PerformanceMonitor 主体
// ────────────────────────────────────────────────────────────────────────────

class PerformanceMonitor {
  static PerformanceMonitor? _inst;
  factory PerformanceMonitor() => _inst ??= PerformanceMonitor._();
  PerformanceMonitor._();

  final List<CpuMetric> _cpu = [];
  final List<MemoryMetric> _mem = [];
  final List<FpsMetric> _fps = [];
  final List<NetworkMetric> _net = [];
  final List<DiskIOMetric> _disk = [];
  final List<BatteryMetric> _bat = [];
  final List<TimingMetric> _timing = [];
  final List<PerformanceAlert> _alerts = [];
  final List<SlowQueryEntry> _slow = [];
  final List<LargeObjectAlert> _largeObjs = [];
  final List<OptimizationSuggestion> _sugs = [];
  final Map<String, AlertThreshold> _thresholds = {};
  final Map<String, DateTime> _cooldowns = {};
  final StreamController<PerformanceAlert> _alertCtrl =
      StreamController<PerformanceAlert>.broadcast();
  CacheConfig _cacheCfg = const CacheConfig();
  bool _monitoring = false;
  Timer? _timer;
  final DateTime _start = DateTime.now();

  // 默认阈值
  static const Map<MetricType, AlertThreshold> _defaults = {
    MetricType.cpu: AlertThreshold(metricType: MetricType.cpu, warningLevel: 70, criticalLevel: 90),
    MetricType.memory: AlertThreshold(metricType: MetricType.memory, warningLevel: 75, criticalLevel: 90),
    MetricType.fps: AlertThreshold(metricType: MetricType.fps, warningLevel: 45, criticalLevel: 30),
    MetricType.battery: AlertThreshold(metricType: MetricType.battery, warningLevel: 20, criticalLevel: 5),
  };

  Stream<PerformanceAlert> get alertStream => _alertCtrl.stream;
  bool get isMonitoring => _monitoring;
  int get historyLength => _cpu.length;

  // ── 启动/停止监控 ──
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_monitoring) return;
    _monitoring = true;
    for (final e in _defaults.entries)
      _thresholds.putIfAbsent(e.key.name, () => e.value);
    _timer = Timer.periodic(interval, (_) => _sample());
    recordTiming('monitor_start', 0);
  }

  void stopMonitoring() {
    _monitoring = false;
    _timer?.cancel();
    _timer = null;
  }

  // ── 指标采集 ──
  void recordCpu({required double usagePercent, double user = 0,
      double system = 0, int cores = 4}) {
    _cpu.add(CpuMetric(
      usagePercent: usagePercent, userPercent: user,
      systemPercent: system, coreCount: cores,
      perCoreAvg: cores > 0 ? usagePercent / cores : 0,
      timestamp: DateTime.now(),
    ));
    _trim(_cpu);
    _checkThreshold(MetricType.cpu, usagePercent);
  }

  void recordMemory({required int heapUsedMB, required int heapTotalMB,
      int externalMB = 0, int nativeMB = 0}) {
    final m = MemoryMetric(
      heapUsedMB: heapUsedMB, heapTotalMB: heapTotalMB,
      externalMB: externalMB, nativeMB: nativeMB,
      totalMB: heapUsedMB + externalMB + nativeMB,
      availableMB: heapTotalMB - heapUsedMB, timestamp: DateTime.now(),
    );
    _mem.add(m);
    _trim(_mem);
    _checkThreshold(MetricType.memory, m.heapUsagePercent);
    _detectLeak();
  }

  void recordFps({required double currentFps, double avg = 60,
      int dropped = 0, int total = 0, int janks = 0, double worstMs = 16.67}) {
    final m = FpsMetric(
      currentFps: currentFps, averageFps: avg, droppedFrames: dropped,
      totalFrames: total, jankCount: janks, worstFrameMs: worstMs,
      timestamp: DateTime.now(),
    );
    _fps.add(m);
    _trim(_fps);
    // 帧率告警（反向阈值）
    final t = _thresholds[MetricType.fps.name];
    if (t != null && t.enabled) {
      if (currentFps <= t.criticalLevel)
        _emitAlert(AlertLevel.critical, MetricType.fps, currentFps, t.criticalLevel,
            '帧率严重低于阈值: ${currentFps.toStringAsFixed(1)} FPS');
      else if (currentFps <= t.warningLevel)
        _emitAlert(AlertLevel.warning, MetricType.fps, currentFps, t.warningLevel,
            '帧率低于阈值: ${currentFps.toStringAsFixed(1)} FPS');
    }
  }

  void recordNetwork({required int up, required int down,
      int reqs = 0, int errors = 0, double latency = 0}) {
    _net.add(NetworkMetric(
      uploadBytes: up, downloadBytes: down,
      uploadKBps: up / 1024, downloadKBps: down / 1024,
      requestCount: reqs, errorCount: errors,
      avgLatencyMs: latency, timestamp: DateTime.now(),
    ));
    _trim(_net);
  }

  void recordDiskIO({required int readBytes, required int writeBytes,
      int readOps = 0, int writeOps = 0}) {
    _disk.add(DiskIOMetric(
      readBytes: readBytes, writeBytes: writeBytes,
      readMBps: readBytes / 1024 / 1024, writeMBps: writeBytes / 1024 / 1024,
      readOps: readOps, writeOps: writeOps, timestamp: DateTime.now(),
    ));
    _trim(_disk);
  }

  void recordBattery({required double level, bool charging = false, double rate = 0}) {
    _bat.add(BatteryMetric(
      levelPercent: level, isCharging: charging,
      dischargeRatePerHour: rate,
      estimatedMinutesRemaining: rate > 0 ? (level / rate * 60).round() : 0,
      timestamp: DateTime.now(),
    ));
    _trim(_bat);
    _checkThreshold(MetricType.battery, level);
  }

  void recordTiming(String name, double ms, {String? route}) {
    _timing.add(TimingMetric(
      name: name, durationMs: ms, route: route, timestamp: DateTime.now(),
    ));
    _trim(_timing);
    // 慢查询自动追踪
    if (ms > 1000) {
      _slow.add(SlowQueryEntry(
        id: 'sq_${DateTime.now().millisecondsSinceEpoch}',
        query: name, durationMs: ms, timestamp: DateTime.now(), source: route,
      ));
    }
  }

  void recordApiTiming(String endpoint, double responseMs) =>
      recordTiming('api:$endpoint', responseMs);
  void recordStartupTime(double ms) => recordTiming('cold_start', ms);
  void recordRenderTime(String widgetName, double ms) =>
      recordTiming('render:$widgetName', ms, route: widgetName);

  // ── 性能分析 ──
  void _detectLeak() {
    if (_mem.length < 30) return;
    final r = _mem.takeLast(30);
    final growth = r.last.heapUsedMB - r.first.heapUsedMB;
    if (growth > 50) {
      _sugs.add(OptimizationSuggestion(
        id: 'leak_${DateTime.now().millisecondsSinceEpoch}',
        category: 'memory_leak',
        title: '疑似内存泄漏',
        description: '堆内存增长 ${growth}MB（${r.first.heapUsedMB}MB → ${r.last.heapUsedMB}MB）',
        severity: growth > 100 ? 'critical' : 'warning',
        estimatedImpact: growth / r.last.heapUsedMB * 100,
        steps: [
          '检查未释放的 StreamSubscription',
          '检查未取消的 Timer',
          '检查未 dispose 的 Controller',
          '使用 Dart DevTools Memory 面板分析',
        ],
      ));
    }
  }

  List<SlowQueryEntry> getSlowQueries({double minMs = 1000, int limit = 20}) {
    final r = _slow.where((q) => q.durationMs >= minMs).toList()
      ..sort((a, b) => b.durationMs.compareTo(a.durationMs));
    return r.take(limit).toList();
  }

  void reportLargeObject(String type, int bytes, String loc,
      {int threshold = 10 * 1024 * 1024}) {
    if (bytes > threshold) {
      _largeObjs.add(LargeObjectAlert(
        id: 'lo_${DateTime.now().millisecondsSinceEpoch}',
        objectType: type, sizeBytes: bytes, location: loc,
      ));
      _sugs.add(OptimizationSuggestion(
        id: 'large_${DateTime.now().millisecondsSinceEpoch}',
        category: 'large_object',
        title: '大对象告警: $type',
        description: '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB 超过阈值',
        severity: bytes > 50 * 1024 * 1024 ? 'critical' : 'warning',
        steps: ['考虑流式处理', '使用分页获取', '实现懒加载'],
      ));
    }
  }

  // ── 性能报告 ──
  PerformanceScore calculateScore() {
    final cpu = _cpu.isEmpty ? 100.0 :
        max(0, 100 - _avg(_cpu.takeLast(20).map((m) => m.usagePercent)));
    final mem = _mem.isEmpty ? 100.0 : max(0, 100 - _mem.last.heapUsagePercent);
    final fps = _fps.isEmpty ? 100.0 :
        (_avg(_fps.takeLast(20).map((m) => m.currentFps)) / 60 * 100).clamp(0, 100);
    final net = _net.isEmpty ? 100.0 :
        max(0, 100 - _avg(_net.takeLast(20).map((m) => m.avgLatencyMs)) / 10);
    final bat = _bat.isEmpty ? 100.0 : _bat.last.levelPercent;
    final overall = (cpu * 0.25 + mem * 0.25 + fps * 0.2 + net * 0.15 + bat * 0.15).clamp(0, 100);
    return PerformanceScore(
      overall: overall, cpuScore: cpu, memoryScore: mem,
      fpsScore: fps, networkScore: net, batteryScore: bat,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> getRealtimeDashboard() => {
    'cpu': _cpu.isNotEmpty ? _cpu.last.toJson() : null,
    'memory': _mem.isNotEmpty ? _mem.last.toJson() : null,
    'fps': _fps.isNotEmpty ? _fps.last.toJson() : null,
    'network': _net.isNotEmpty ? _net.last.toJson() : null,
    'disk': _disk.isNotEmpty ? _disk.last.toJson() : null,
    'battery': _bat.isNotEmpty ? _bat.last.toJson() : null,
    'uptime': DateTime.now().difference(_start).inSeconds,
    'alertCount': _alerts.length,
    'slowQueryCount': _slow.length,
    'largeObjectCount': _largeObjs.length,
  };

  List<Map<String, dynamic>> getHistoryTrend({MetricType? metric, int maxPts = 60}) {
    switch (metric) {
      case MetricType.cpu:
        return _cpu.takeLast(maxPts).map((m) =>
            {'ts': m.timestamp.toIso8601String(), 'v': m.usagePercent, 'u': '%'}).toList();
      case MetricType.memory:
        return _mem.takeLast(maxPts).map((m) =>
            {'ts': m.timestamp.toIso8601String(), 'v': m.heapUsedMB, 'u': 'MB'}).toList();
      case MetricType.fps:
        return _fps.takeLast(maxPts).map((m) =>
            {'ts': m.timestamp.toIso8601String(), 'v': m.currentFps, 'u': 'FPS'}).toList();
      case MetricType.network:
        return _net.takeLast(maxPts).map((m) =>
            {'ts': m.timestamp.toIso8601String(), 'v': m.downloadKBps, 'u': 'KB/s'}).toList();
      case MetricType.battery:
        return _bat.takeLast(maxPts).map((m) =>
            {'ts': m.timestamp.toIso8601String(), 'v': m.levelPercent, 'u': '%'}).toList();
      default:
        return [];
    }
  }

  List<OptimizationSuggestion> getSuggestions() {
    _genSuggestions();
    return List.unmodifiable(_sugs);
  }

  // ── 性能优化 ──
  void triggerGC() {
    _sugs.add(OptimizationSuggestion(
      id: 'gc_${DateTime.now().millisecondsSinceEpoch}',
      category: 'gc', title: '手动触发GC',
      description: '已建议系统执行垃圾回收以释放内存', severity: 'info',
    ));
  }

  void updateCacheConfig(CacheConfig c) => _cacheCfg = c;
  CacheConfig getCacheConfig() => _cacheCfg;

  Map<String, dynamic> getCacheStats() => {
    'strategy': _cacheCfg.strategy.name,
    'maxSizeMB': _cacheCfg.maxSizeMB,
    'ttlSeconds': _cacheCfg.ttl.inSeconds,
    'preloadEnabled': _cacheCfg.enablePreload,
    'preloadKeyCount': _cacheCfg.preloadKeys.length,
  };

  List<Map<String, dynamic>> getPreloadSuggestions() {
    final s = <Map<String, dynamic>>[];
    if (_net.isNotEmpty && _avg(_net.takeLast(20).map((m) => m.avgLatencyMs)) > 200) {
      s.add({'type': 'api_preload', 'reason': 'API延迟偏高，建议预加载高频数据', 'impact': 'high'});
    }
    if (_fps.isNotEmpty && _fps.last.jankCount > 10) {
      s.add({'type': 'widget_preload', 'reason': '检测到卡顿，建议预渲染常用组件', 'impact': 'medium'});
    }
    return s;
  }

  List<Map<String, dynamic>> getLazyLoadRecommendations() {
    if (_mem.isEmpty || _mem.last.heapUsagePercent <= 70) return [];
    return [
      {'type': 'image_lazy_load', 'reason': '堆内存使用率 ${_mem.last.heapUsagePercent.toStringAsFixed(1)}%，建议图片懒加载'},
      {'type': 'data_lazy_load', 'reason': '建议列表数据改为分页懒加载'},
    ];
  }

  // ── 告警规则 ──
  void setThreshold(AlertThreshold t) => _thresholds[t.metricType.name] = t;
  void removeThreshold(MetricType t) => _thresholds.remove(t.name);
  List<AlertThreshold> getThresholds() => _thresholds.values.toList();

  List<PerformanceAlert> getAlerts({int limit = 50, AlertLevel? minLevel}) {
    var a = List<PerformanceAlert>.from(_alerts);
    if (minLevel != null) {
      final ml = AlertLevel.values.indexOf(minLevel);
      a = a.where((x) => AlertLevel.values.indexOf(x.level) >= ml).toList();
    }
    a.sort((x, y) => y.timestamp.compareTo(x.timestamp));
    return a.take(limit).toList();
  }

  void clearAlerts() => _alerts.clear();

  // ── 内部方法 ──
  void _sample() {
    final r = Random();
    recordCpu(usagePercent: 20 + r.nextDouble() * 40, user: 15 + r.nextDouble() * 25);
    recordMemory(heapUsedMB: 150 + r.nextInt(100), heapTotalMB: 512,
        externalMB: 20 + r.nextInt(30), nativeMB: 30 + r.nextInt(20));
    recordFps(currentFps: 50 + r.nextDouble() * 10, dropped: r.nextInt(5));
    recordNetwork(up: r.nextInt(10000), down: r.nextInt(50000),
        reqs: 5 + r.nextInt(20), latency: 50 + r.nextDouble() * 200);
  }

  void _checkThreshold(MetricType type, double val) {
    final t = _thresholds[type.name];
    if (t == null || !t.enabled) return;
    final ck = '${type.name}_${t.warningLevel}';
    final last = _cooldowns[ck];
    if (last != null && DateTime.now().difference(last) < t.cooldownDuration) return;
    if (val >= t.criticalLevel) {
      _emitAlert(AlertLevel.critical, type, val, t.criticalLevel,
          '${type.name}严重超限: ${val.toStringAsFixed(1)}');
      _cooldowns[ck] = DateTime.now();
    } else if (val >= t.warningLevel) {
      _emitAlert(AlertLevel.warning, type, val, t.warningLevel,
          '${type.name}超阈值: ${val.toStringAsFixed(1)}');
      _cooldowns[ck] = DateTime.now();
    }
  }

  void _emitAlert(AlertLevel lv, MetricType t, double val, double th, String msg) {
    final a = PerformanceAlert(
      id: 'al_${DateTime.now().millisecondsSinceEpoch}',
      level: lv, metricType: t, message: msg,
      currentValue: val, threshold: th,
    );
    _alerts.add(a);
    _alertCtrl.add(a);
  }

  void _genSuggestions() {
    if (_cpu.isNotEmpty) {
      final avg = _avg(_cpu.takeLast(20).map((m) => m.usagePercent));
      if (avg > 60) _addOnce('cpu', 'CPU使用率偏高',
          '平均CPU ${avg.toStringAsFixed(1)}%',
          ['减少UI线程计算', '使用compute()后台计算', '检查频繁重建的Widget']);
    }
    if (_net.isNotEmpty && _avg(_net.takeLast(20).map((m) => m.avgLatencyMs)) > 500) {
      final lat = _avg(_net.takeLast(20).map((m) => m.avgLatencyMs));
      _addOnce('net', '网络延迟偏高',
          '平均 ${lat.toStringAsFixed(0)}ms',
          ['实现请求缓存', '使用分页减少数据量', '考虑CDN加速']);
    }
  }

  void _addOnce(String cat, String title, String desc, List<String> steps) {
    if (_sugs.any((s) => s.category == cat)) return;
    _sugs.add(OptimizationSuggestion(
      id: 's_${cat}_${DateTime.now().millisecondsSinceEpoch}',
      category: cat, title: title, description: desc, steps: steps,
    ));
  }

  double _avg(Iterable<double> vals) {
    final list = vals.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  void _trim(List list, {int max = 3600}) { while (list.length > max) list.removeAt(0); }

  Future<void> dispose() async { stopMonitoring(); await _alertCtrl.close(); }
}

/// 扩展：从列表尾部取 n 个元素
extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => n >= length ? List.from(this) : sublist(length - n);
}

// ============================================================================
// 小酥 - 性能监控
// ============================================================================

/// 性能指标
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;

  const PerformanceMetric({
    required this.name,
    required this.value,
    this.unit = '',
    required this.timestamp,
  });
}

/// 性能监控服务
class PerformanceMonitor {
  static final PerformanceMonitor instance = PerformanceMonitor._();
  PerformanceMonitor._();

  final List<PerformanceMetric> _metrics = [];
  static const int _maxMetrics = 1000;

  // 运行时指标
  int _totalRequests = 0;
  double _totalLatencyMs = 0;
  int _errorCount = 0;

  /// 记录请求
  void recordRequest(double latencyMs, {bool isError = false}) {
    _totalRequests++;
    _totalLatencyMs += latencyMs;
    if (isError) _errorCount++;

    _addMetric(PerformanceMetric(
      name: 'request_latency',
      value: latencyMs,
      unit: 'ms',
      timestamp: DateTime.now(),
    ));
  }

  /// 平均延迟
  double get averageLatency =>
      _totalRequests > 0 ? _totalLatencyMs / _totalRequests : 0;

  /// 错误率
  double get errorRate =>
      _totalRequests > 0 ? _errorCount / _totalRequests : 0;

  /// 总请求数
  int get totalRequests => _totalRequests;

  /// 获取最近指标
  List<PerformanceMetric> getRecentMetrics({int limit = 50}) {
    final start = _metrics.length > limit ? _metrics.length - limit : 0;
    return _metrics.sublist(start);
  }

  void _addMetric(PerformanceMetric metric) {
    _metrics.add(metric);
    if (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }
  }

  /// 重置
  void reset() {
    _metrics.clear();
    _totalRequests = 0;
    _totalLatencyMs = 0;
    _errorCount = 0;
  }
}

// ============================================================================
// 小酥 AI 助手 - API 网关
// ============================================================================
// 统一的 API 调用入口，提供认证、限流、重试、熔断、缓存等中间件
// 所有网络请求通过此网关统一管理
// ============================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// API 网关
/// 统一的网络请求管理入口
class ApiGateway {
  /// 网关配置
  final ApiGatewayConfig _config;

  /// 认证拦截器
  late final AuthInterceptor _authInterceptor;

  /// 限流器
  late final RateLimiter _rateLimiter;

  /// 熔断器（按端点管理）
  final Map<String, CircuitBreaker> _circuitBreakers = {};

  /// 响应缓存
  late final ResponseCache _cache;

  /// 请求日志
  final List<RequestLog> _requestLogs = [];

  /// 最大日志数量
  static const int _maxLogCount = 100;

  /// 底层 HTTP 客户端（实际项目中使用 dio 或 http 包）
  final _HttpClient _httpClient;

  ApiGateway({
    required ApiGatewayConfig config,
    _HttpClient? httpClient,
  })  : _config = config,
        _httpClient = httpClient ?? _HttpClient() {
    _authInterceptor = AuthInterceptor(config: config);
    _rateLimiter = RateLimiter(
      maxRequests: config.maxRequestsPerMinute,
      windowDuration: const Duration(minutes: 1),
    );
    _cache = ResponseCache(maxSize: config.cacheMaxSize);
  }

  // ============================================================================
  // 核心请求方法
  // ============================================================================

  /// 发送 GET 请求
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    bool useCache = true,
    Duration? cacheDuration,
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    final cacheKey = 'GET:$url';

    // 检查缓存
    if (useCache) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    }

    return _executeRequest(
      method: 'GET',
      url: url,
      headers: headers,
      endpoint: endpoint,
      cacheKey: useCache ? cacheKey : null,
      cacheDuration: cacheDuration,
    );
  }

  /// 发送 POST 请求
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool useCache = false,
  }) async {
    final url = _buildUrl(endpoint, null);

    return _executeRequest(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
      endpoint: endpoint,
      cacheKey: useCache ? 'POST:$url:${jsonEncode(body)}' : null,
    );
  }

  /// 发送 PUT 请求
  Future<ApiResponse> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final url = _buildUrl(endpoint, null);

    return _executeRequest(
      method: 'PUT',
      url: url,
      headers: headers,
      body: body,
      endpoint: endpoint,
    );
  }

  /// 发送 DELETE 请求
  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = _buildUrl(endpoint, null);

    return _executeRequest(
      method: 'DELETE',
      url: url,
      headers: headers,
      endpoint: endpoint,
    );
  }

  // ============================================================================
  // 请求执行管线
  // ============================================================================

  /// 执行请求（经过所有中间件）
  Future<ApiResponse> _executeRequest({
    required String method,
    required String url,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? cacheKey,
    Duration? cacheDuration,
  }) async {
    final requestStopwatch = Stopwatch()..start();

    // 1. 熔断器检查
    final breaker = _getOrCreateBreaker(endpoint);
    if (breaker.isOpen) {
      _logRequest(method, url, 503, 0, 'CIRCUIT_OPEN');
      throw ApiException(
        message: '服务熔断中，请稍后再试',
        statusCode: 503,
        errorCode: 'CIRCUIT_OPEN',
      );
    }

    // 2. 限流检查
    if (!_rateLimiter.tryAcquire()) {
      _logRequest(method, url, 429, 0, 'RATE_LIMITED');
      throw ApiException(
        message: '请求频率过高，请稍后再试',
        statusCode: 429,
        errorCode: 'RATE_LIMITED',
      );
    }

    // 3. 认证注入
    final authHeaders = await _authInterceptor.injectAuth(headers ?? {});
    final allHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'XiaoSu/1.0',
      ...authHeaders,
    };

    // 4. 重试执行
    final maxRetries = _getRetryCount(endpoint);
    Object? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // 指数退避
          final delay = Duration(milliseconds: 1000 * (1 << attempt));
          await Future.delayed(delay);
        }

        // 发送实际请求
        final response = await _httpClient.request(
          method: method,
          url: url,
          headers: allHeaders,
          body: body,
          timeoutMs: _config.requestTimeoutMs,
        );

        requestStopwatch.stop();

        // 记录日志
        _logRequest(
          method,
          url,
          response.statusCode,
          requestStopwatch.elapsedMilliseconds,
          null,
        );

        // 5. 构建响应
        final apiResponse = ApiResponse(
          statusCode: response.statusCode,
          data: response.data,
          headers: response.headers,
          durationMs: requestStopwatch.elapsedMilliseconds,
          fromCache: false,
        );

        // 6. 缓存响应（如果是 GET 且成功）
        if (cacheKey != null &&
            method == 'GET' &&
            response.statusCode == 200) {
          _cache.set(
            cacheKey,
            apiResponse,
            duration: cacheDuration ?? _config.defaultCacheDuration,
          );
        }

        // 7. 更新熔断器状态
        breaker.recordSuccess();

        return apiResponse;
      } catch (e) {
        lastError = e;

        // 判断是否可重试
        if (e is ApiException && !_isRetryable(e.statusCode)) {
          breaker.recordFailure();
          rethrow;
        }

        // 最后一次重试仍然失败
        if (attempt == maxRetries) {
          breaker.recordFailure();
          requestStopwatch.stop();

          _logRequest(
            method,
            url,
            0,
            requestStopwatch.elapsedMilliseconds,
            e.toString(),
          );

          if (e is ApiException) rethrow;
          throw ApiException(
            message: '请求失败: $e',
            statusCode: 0,
            errorCode: 'REQUEST_ERROR',
          );
        }
      }
    }

    throw ApiException(
      message: '重试耗尽: $lastError',
      statusCode: 0,
      errorCode: 'RETRIES_EXHAUSTED',
    );
  }

  // ============================================================================
  // 缓存管理
  // ============================================================================

  /// 清除所有缓存
  void clearCache() => _cache.clear();

  /// 清除指定端点的缓存
  void clearEndpointCache(String endpoint) {
    _cache.clearWhere((key, _) => key.contains(endpoint));
  }

  // ============================================================================
  // 日志管理
  // ============================================================================

  /// 获取请求日志
  List<RequestLog> getRequestLogs({int? limit}) {
    final logs = _requestLogs.reversed.toList();
    if (limit != null && limit < logs.length) {
      return logs.sublist(0, limit);
    }
    return logs;
  }

  /// 记录请求日志
  void _logRequest(
    String method,
    String url,
    int statusCode,
    int durationMs,
    String? error,
  ) {
    _requestLogs.add(RequestLog(
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      error: error,
    ));

    // 限制日志数量
    while (_requestLogs.length > _maxLogCount) {
      _requestLogs.removeAt(0);
    }
  }

  // ============================================================================
  // 内部方法
  // ============================================================================

  /// 构建完整 URL
  String _buildUrl(String endpoint, Map<String, dynamic>? queryParams) {
    final baseUrl = _config.baseUrl.endsWith('/')
        ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
        : _config.baseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    String url = '$baseUrl$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .where((e) => e.value != null)
          .map((e) => '${Uri.encodeComponent(e.key)}='
              '${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url = '$url?$queryString';
    }

    return url;
  }

  /// 获取或创建熔断器
  CircuitBreaker _getOrCreateBreaker(String endpoint) {
    return _circuitBreakers.putIfAbsent(
      endpoint,
      () => CircuitBreaker(
        failureThreshold: _config.circuitBreakerThreshold,
        resetTimeout: _config.circuitBreakerResetTimeout,
      ),
    );
  }

  /// 获取重试次数
  int _getRetryCount(String endpoint) {
    // LLM API 重试次数更多
    if (endpoint.contains('/chat') || endpoint.contains('/completion')) {
      return _config.maxRetries + 1;
    }
    return _config.maxRetries;
  }

  /// 判断状态码是否可重试
  bool _isRetryable(int statusCode) {
    return statusCode == 429 || // Too Many Requests
        statusCode == 500 || // Internal Server Error
        statusCode == 502 || // Bad Gateway
        statusCode == 503 || // Service Unavailable
        statusCode == 504; // Gateway Timeout
  }
}

// ============================================================================
// 认证拦截器
// ============================================================================

/// 认证拦截器
/// 自动为请求注入认证信息
class AuthInterceptor {
  final ApiGatewayConfig _config;

  /// 当前 Access Token
  String? _accessToken;

  /// Token 过期时间
  DateTime? _tokenExpiry;

  /// Token 刷新锁
  bool _refreshing = false;

  AuthInterceptor({required ApiGatewayConfig config}) : _config = config;

  /// 注入认证头
  Future<Map<String, String>> injectAuth(Map<String, String> headers) async {
    final token = await _getValidToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // 添加 API Key（如果有）
    if (_config.apiKey.isNotEmpty) {
      headers['X-API-Key'] = _config.apiKey;
    }

    return headers;
  }

  /// 获取有效的 Token
  Future<String?> _getValidToken() async {
    // Token 存在且未过期
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    // 刷新 Token
    if (!_refreshing) {
      _refreshing = true;
      try {
        await _refreshToken();
      } finally {
        _refreshing = false;
      }
    }

    return _accessToken;
  }

  /// 刷新 Token
  Future<void> _refreshToken() async {
    // TODO: 实际项目中调用认证服务刷新 Token
    // 1. 使用 refresh_token 获取新的 access_token
    // 2. 更新本地存储
    _accessToken = _config.apiKey.isNotEmpty ? _config.apiKey : null;
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
  }

  /// 设置 Token（外部注入）
  void setToken(String token, {Duration validity = const Duration(hours: 1)}) {
    _accessToken = token;
    _tokenExpiry = DateTime.now().add(validity);
  }

  /// 清除 Token
  void clearToken() {
    _accessToken = null;
    _tokenExpiry = null;
  }
}

// ============================================================================
// 限流器
// ============================================================================

/// 限流器
/// 滑动窗口算法控制请求频率
class RateLimiter {
  /// 窗口内最大请求数
  final int maxRequests;

  /// 窗口时长
  final Duration windowDuration;

  /// 请求时间戳队列
  final Queue<DateTime> _timestamps = Queue();

  RateLimiter({
    required this.maxRequests,
    required this.windowDuration,
  });

  /// 尝试获取请求许可
  /// 返回 true 表示允许请求
  bool tryAcquire() {
    final now = DateTime.now();

    // 清理过期时间戳
    while (_timestamps.isNotEmpty &&
        now.difference(_timestamps.first) > windowDuration) {
      _timestamps.removeFirst();
    }

    // 检查是否超限
    if (_timestamps.length >= maxRequests) {
      return false;
    }

    _timestamps.add(now);
    return true;
  }

  /// 获取当前窗口内的请求数
  int get currentCount {
    final now = DateTime.now();
    while (_timestamps.isNotEmpty &&
        now.difference(_timestamps.first) > windowDuration) {
      _timestamps.removeFirst();
    }
    return _timestamps.length;
  }

  /// 重置限流器
  void reset() => _timestamps.clear();
}

// ============================================================================
// 熔断器
// ============================================================================

/// 熔断器
/// 防止级联故障，保护下游服务
class CircuitBreaker {
  /// 失败阈值（达到后开启熔断）
  final int failureThreshold;

  /// 重置超时（熔断恢复半开状态的等待时间）
  final Duration resetTimeout;

  /// 失败次数
  int _failureCount = 0;

  /// 最后失败时间
  DateTime? _lastFailureTime;

  /// 当前状态
  CircuitState _state = CircuitState.closed;

  CircuitBreaker({
    required this.failureThreshold,
    required this.resetTimeout,
  });

  /// 是否处于熔断（开启）状态
  bool get isOpen {
    if (_state == CircuitState.open) {
      // 检查是否到了恢复时间
      if (_lastFailureTime != null &&
          DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
        _state = CircuitState.halfOpen;
        return false;
      }
      return true;
    }
    return false;
  }

  /// 当前状态
  CircuitState get state => _state;

  /// 记录成功
  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  /// 记录失败
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// 重置
  void reset() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastFailureTime = null;
  }
}

/// 熔断器状态
enum CircuitState {
  /// 关闭（正常）
  closed,

  /// 开启（熔断）
  open,

  /// 半开（尝试恢复）
  halfOpen,
}

// ============================================================================
// 响应缓存
// ============================================================================

/// 响应缓存
/// 使用 LRU 策略的内存缓存
class ResponseCache {
  /// 最大缓存条目数
  final int maxSize;

  /// 缓存存储
  final LinkedHashMap<String, _CacheEntry> _store = LinkedHashMap();

  ResponseCache({required this.maxSize});

  /// 获取缓存
  ApiResponse? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;

    // 检查是否过期
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }

    // LRU：移到末尾
    _store.remove(key);
    _store[key] = entry;

    return entry.response;
  }

  /// 设置缓存
  void set(String key, ApiResponse response, {Duration? duration}) {
    // 删除已存在的条目
    _store.remove(key);

    // 如果已满，删除最旧的条目
    while (_store.length >= maxSize) {
      _store.remove(_store.keys.first);
    }

    _store[key] = _CacheEntry(
      response: response,
      expiry: DateTime.now().add(
        duration ?? const Duration(minutes: 5),
      ),
    );
  }

  /// 清除所有缓存
  void clear() => _store.clear();

  /// 条件清除
  void clearWhere(bool Function(String key, _CacheEntry entry) test) {
    _store.removeWhere(test);
  }

  /// 缓存大小
  int get size => _store.length;
}

/// 缓存条目
class _CacheEntry {
  final ApiResponse response;
  final DateTime expiry;

  _CacheEntry({required this.response, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

// ============================================================================
// 数据模型
// ============================================================================

/// API 响应
class ApiResponse {
  /// HTTP 状态码
  final int statusCode;

  /// 响应数据
  final dynamic data;

  /// 响应头
  final Map<String, String> headers;

  /// 请求耗时（毫秒）
  final int durationMs;

  /// 是否来自缓存
  final bool fromCache;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
    this.durationMs = 0,
    this.fromCache = false,
  });

  /// 是否成功
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  /// 获取 JSON 数据
  Map<String, dynamic>? get jsonData {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 获取字符串数据
  String get dataAsString => data?.toString() ?? '';
}

/// API 异常
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? errorCode;

  const ApiException({
    required this.message,
    required this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 请求日志
class RequestLog {
  final String method;
  final String url;
  final int statusCode;
  final int durationMs;
  final DateTime timestamp;
  final String? error;

  const RequestLog({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'url': url,
        'status_code': statusCode,
        'duration_ms': durationMs,
        'timestamp': timestamp.toIso8601String(),
        if (error != null) 'error': error,
      };
}

// ============================================================================
// 配置
// ============================================================================

/// API 网关配置
class ApiGatewayConfig {
  /// 基础 URL
  final String baseUrl;

  /// API 密钥
  final String apiKey;

  /// 请求超时（毫秒）
  final int requestTimeoutMs;

  /// 最大重试次数
  final int maxRetries;

  /// 每分钟最大请求数
  final int maxRequestsPerMinute;

  /// 熔断器失败阈值
  final int circuitBreakerThreshold;

  /// 熔断器重置超时
  final Duration circuitBreakerResetTimeout;

  /// 缓存最大条目数
  final int cacheMaxSize;

  /// 默认缓存时长
  final Duration defaultCacheDuration;

  const ApiGatewayConfig({
    required this.baseUrl,
    this.apiKey = '',
    this.requestTimeoutMs = 30000,
    this.maxRetries = 3,
    this.maxRequestsPerMinute = 60,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetTimeout = const Duration(seconds: 30),
    this.cacheMaxSize = 200,
    this.defaultCacheDuration = const Duration(minutes: 5),
  });
}

// ============================================================================
// HTTP 客户端抽象
// ============================================================================

/// 内部 HTTP 客户端
/// 实际项目中使用 dio/http 包替代
class _HttpClient {
  /// 发送 HTTP 请求
  Future<_HttpResponse> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    required int timeoutMs,
  }) async {
    // TODO: 实际项目中使用 dio 或 http 包
    // 这里模拟 HTTP 请求
    throw UnimplementedError(
      '请使用 dio 或 http 包实现实际的 HTTP 请求。'
      '示例: dio.get(url, options: Options(headers: headers))',
    );
  }
}

/// 内部 HTTP 响应
class _HttpResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  const _HttpResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
  });
}

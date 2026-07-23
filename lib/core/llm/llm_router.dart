/// ============================================================================
/// 小酥 AI 助手 — LLM 智能路由
/// ============================================================================
/// 根据任务复杂度、网络状态、成本预算等因素，智能选择合适的 LLM Provider。
/// 支持：
///   - 自动降级 (云端 → 本地)
///   - Provider 切换
///   - 任务复杂度评估
///   - 成本/延迟优化
/// ============================================================================

import 'dart:async';

import '../common/models.dart';
import 'llm_provider.dart';

// ———————————————————————————————— 路由配置 ————————————————————————————————

/// 任务复杂度级别
enum TaskComplexity {
  /// 简单：闲聊、简短回答、翻译等
  simple,

  /// 中等：知识问答、文案创作、代码补全等
  medium,

  /// 复杂：多步推理、长文写作、复杂代码等
  complex,

  /// 极复杂：需要 Function Calling 的多步任务
  veryComplex,
}

/// 路由策略
enum RoutingStrategy {
  /// 性能优先 — 总是选择最强模型
  performance,

  /// 成本优先 — 优先选择便宜模型
  cost,

  /// 均衡 — 根据复杂度动态匹配
  balanced,

  /// 手动 — 用户指定
  manual,
}

/// Provider 优先级配置
///
/// 定义每个 Provider 在不同复杂度下的优先级和启用状态。
class ProviderPriority {
  /// Provider 实例
  final LlmProvider provider;

  /// 每 1000 token 的输入价格（美元），用于成本计算
  final double inputPricePer1K;

  /// 每 1000 token 的输出价格（美元）
  final double outputPricePer1K;

  /// 平均响应延迟（毫秒）
  final int avgLatencyMs;

  /// 是否启用
  bool enabled;

  /// 适用的复杂度级别（null 表示所有级别）
  final List<TaskComplexity>? supportedComplexity;

  ProviderPriority({
    required this.provider,
    this.inputPricePer1K = 0.0,
    this.outputPricePer1K = 0.0,
    this.avgLatencyMs = 1000,
    this.enabled = true,
    this.supportedComplexity,
  });
}

// ———————————————————————————————— 网络状态 ————————————————————————————————

/// 网络状态枚举
enum NetworkState {
  /// 网络良好
  excellent,

  /// 网络一般
  good,

  /// 网络较差
  poor,

  /// 无网络（离线）
  offline,
}

// ———————————————————————————————— 智能路由 ————————————————————————————————

/// LLM 智能路由器
///
/// 核心职责：根据当前上下文（网络状态、任务复杂度、路由策略）
/// 从注册的 Provider 列表中选择最合适的一个。
///
/// 使用示例：
/// ```dart
/// final router = LlmRouter(strategy: RoutingStrategy.balanced);
/// router.registerProvider(ProviderPriority(
///   provider: openAiProvider,
///   inputPricePer1K: 0.005,
///   avgLatencyMs: 800,
/// ));
/// router.registerProvider(ProviderPriority(
///   provider: qwenProvider,
///   inputPricePer1K: 0.002,
///   avgLatencyMs: 600,
/// ));
///
/// // 根据任务自动选择
/// final provider = await router.selectProvider(
///   complexity: TaskComplexity.medium,
///   needFunctionCalling: false,
/// );
/// ```
class LlmRouter {
  /// 已注册的 Provider 优先级列表
  final List<ProviderPriority> _providers = [];

  /// 当前路由策略
  RoutingStrategy strategy;

  /// 当前网络状态
  NetworkState _networkState = NetworkState.excellent;

  /// 网络状态变更流
  final StreamController<NetworkState> _networkController =
      StreamController<NetworkState>.broadcast();

  /// 当前活跃的 Provider
  LlmProvider? _activeProvider;

  /// 降级回调（当所有云端 Provider 不可用时通知上层）
  void Function()? onAllProvidersUnavailable;

  LlmRouter({
    this.strategy = RoutingStrategy.balanced,
  });

  // ———————— Provider 管理 ————————

  /// 注册 Provider
  void registerProvider(ProviderPriority priority) {
    _providers.add(priority);
  }

  /// 移除 Provider
  void removeProvider(String providerId) {
    _providers.removeWhere((p) => p.provider.providerId == providerId);
  }

  /// 启用/禁用 Provider
  void setProviderEnabled(String providerId, bool enabled) {
    final provider = _providers.firstWhere(
      (p) => p.provider.providerId == providerId,
    );
    provider.enabled = enabled;
  }

  /// 获取所有已注册的 Provider
  List<LlmProvider> get allProviders =>
      _providers.map((p) => p.provider).toList();

  /// 获取当前活跃的 Provider
  LlmProvider? get activeProvider => _activeProvider;

  // ———————— 网络状态 ————————

  /// 更新网络状态
  void updateNetworkState(NetworkState state) {
    _networkState = state;
    _networkController.add(state);
  }

  /// 监听网络状态变化
  Stream<NetworkState> get networkStateStream => _networkController.stream;

  /// 当前网络状态
  NetworkState get networkState => _networkState;

  // ———————— 智能选择 ————————

  /// 根据任务需求选择最合适的 Provider
  ///
  /// [complexity] 任务复杂度
  /// [needFunctionCalling] 是否需要 Function Calling
  /// [estimatedInputTokens] 预估输入 token 数（用于成本计算）
  /// [estimatedOutputTokens] 预估输出 token 数
  /// 返回选中的 Provider，如果没有可用的则抛出异常
  Future<LlmProvider> selectProvider({
    TaskComplexity complexity = TaskComplexity.medium,
    bool needFunctionCalling = false,
    int estimatedInputTokens = 0,
    int estimatedOutputTokens = 0,
  }) async {
    // 获取可用 Provider 列表
    final available = _getAvailableProviders(
      complexity: complexity,
      needFunctionCalling: needFunctionCalling,
    );

    if (available.isEmpty) {
      onAllProvidersUnavailable?.call();
      throw LlmException('没有可用的 LLM Provider');
    }

    // 根据策略选择
    final selected = switch (strategy) {
      RoutingStrategy.performance => _selectByPerformance(available),
      RoutingStrategy.cost => _selectByCost(
          available,
          estimatedInputTokens,
          estimatedOutputTokens,
        ),
      RoutingStrategy.balanced => _selectByBalance(
          available,
          complexity,
          estimatedInputTokens,
          estimatedOutputTokens,
        ),
      RoutingStrategy.manual => _activeProvider ?? available.first.provider,
    };

    _activeProvider = selected;
    return selected;
  }

  /// 获取可用的 Provider 列表（过滤不可用和不匹配的）
  List<ProviderPriority> _getAvailableProviders({
    required TaskComplexity complexity,
    required bool needFunctionCalling,
  }) {
    return _providers.where((p) {
      // 检查是否启用
      if (!p.enabled) return false;

      // 检查 Provider 是否可用
      if (!p.provider.isAvailable) return false;

      // 检查网络状态
      if (_networkState == NetworkState.offline) {
        // 离线时只使用本地 Provider（providerId 以 "local" 开头的）
        if (!p.provider.providerId.startsWith('local')) return false;
      } else if (_networkState == NetworkState.poor) {
        // 网络差时优先使用低延迟 Provider
        // （此处不做过滤，但在评分中加权）
      }

      // 检查 Function Calling 支持
      if (needFunctionCalling && !p.provider.supportsFunctionCalling) {
        return false;
      }

      // 检查复杂度匹配
      if (p.supportedComplexity != null &&
          !p.supportedComplexity!.contains(complexity)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// 性能优先选择 — 选上下文窗口最大、延迟最低的
  LlmProvider _selectByPerformance(List<ProviderPriority> candidates) {
    // 按上下文窗口降序 + 延迟升序排序
    candidates.sort((a, b) {
      final ctxCompare =
          b.provider.maxContextTokens.compareTo(a.provider.maxContextTokens);
      if (ctxCompare != 0) return ctxCompare;
      return a.avgLatencyMs.compareTo(b.avgLatencyMs);
    });
    return candidates.first.provider;
  }

  /// 成本优先选择 — 选最便宜的
  LlmProvider _selectByCost(
    List<ProviderPriority> candidates,
    int inputTokens,
    int outputTokens,
  ) {
    candidates.sort((a, b) {
      final costA = _calculateCost(a, inputTokens, outputTokens);
      final costB = _calculateCost(b, inputTokens, outputTokens);
      return costA.compareTo(costB);
    });
    return candidates.first.provider;
  }

  /// 均衡选择 — 综合复杂度、成本、延迟打分
  LlmProvider _selectByBalance(
    List<ProviderPriority> candidates,
    TaskComplexity complexity,
    int inputTokens,
    int outputTokens,
  ) {
    // 为每个候选计算综合得分（越低越好）
    final scores = <ProviderPriority, double>{};

    for (final candidate in candidates) {
      double score = 0;

      // 复杂度因子：复杂任务倾向大模型
      switch (complexity) {
        case TaskComplexity.simple:
          // 简单任务：成本权重 0.6，延迟权重 0.4
          score += _normalizeCost(candidate, inputTokens, outputTokens) * 0.6;
          score += _normalizeLatency(candidate) * 0.4;
          break;
        case TaskComplexity.medium:
          // 中等任务：上下文权重 0.3，成本 0.4，延迟 0.3
          score += _normalizeContext(candidate) * 0.3;
          score += _normalizeCost(candidate, inputTokens, outputTokens) * 0.4;
          score += _normalizeLatency(candidate) * 0.3;
          break;
        case TaskComplexity.complex:
        case TaskComplexity.veryComplex:
          // 复杂任务：上下文权重 0.5，成本 0.2，延迟 0.3
          score += _normalizeContext(candidate) * 0.5;
          score += _normalizeCost(candidate, inputTokens, outputTokens) * 0.2;
          score += _normalizeLatency(candidate) * 0.3;
          break;
      }

      // 网络差时增加延迟权重
      if (_networkState == NetworkState.poor) {
        score += _normalizeLatency(candidate) * 0.3;
      }

      scores[candidate] = score;
    }

    // 选得分最低的
    final best = scores.entries.reduce((a, b) => a.value < b.value ? a : b);
    return best.key.provider;
  }

  /// 计算实际成本
  double _calculateCost(
    ProviderPriority p,
    int inputTokens,
    int outputTokens,
  ) {
    return (inputTokens / 1000) * p.inputPricePer1K +
        (outputTokens / 1000) * p.outputPricePer1K;
  }

  /// 归一化成本（简单 min-max 归一化）
  double _normalizeCost(
    ProviderPriority p,
    int inputTokens,
    int outputTokens,
  ) {
    if (_providers.isEmpty) return 0;
    final cost = _calculateCost(p, inputTokens, outputTokens);
    final costs =
        _providers.map((pp) => _calculateCost(pp, inputTokens, outputTokens));
    final minCost = costs.reduce((a, b) => a < b ? a : b);
    final maxCost = costs.reduce((a, b) => a > b ? a : b);
    if (maxCost == minCost) return 0.5;
    return (cost - minCost) / (maxCost - minCost);
  }

  /// 归一化延迟
  double _normalizeLatency(ProviderPriority p) {
    if (_providers.isEmpty) return 0;
    final latencies = _providers.map((pp) => pp.avgLatencyMs);
    final minLat = latencies.reduce((a, b) => a < b ? a : b);
    final maxLat = latencies.reduce((a, b) => a > b ? a : b);
    if (maxLat == minLat) return 0.5;
    return (p.avgLatencyMs - minLat) / (maxLat - minLat);
  }

  /// 归一化上下文窗口
  double _normalizeContext(ProviderPriority p) {
    if (_providers.isEmpty) return 0;
    final contexts = _providers.map((pp) => pp.provider.maxContextTokens);
    final minCtx = contexts.reduce((a, b) => a < b ? a : b);
    final maxCtx = contexts.reduce((a, b) => a > b ? a : b);
    if (maxCtx == minCtx) return 0.5;
    // 上下文越大越好，所以反向归一化
    return 1.0 -
        (p.provider.maxContextTokens - minCtx) / (maxCtx - minCtx);
  }

  // ———————————————————————————————— 降级策略 ————————————————————————————————

  /// 带自动降级的调用
  ///
  /// 如果首选 Provider 调用失败，自动切换到下一个可用 Provider。
  /// 返回成功响应和实际使用的 Provider。
  Future<(ChatResponse, LlmProvider)> chatWithFallback({
    required List<LlmMessage> messages,
    List<ToolDeclaration>? tools,
    TaskComplexity complexity = TaskComplexity.medium,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final candidates = _getAvailableProviders(
      complexity: complexity,
      needFunctionCalling: tools != null && tools.isNotEmpty,
    );

    if (candidates.isEmpty) {
      throw LlmException('没有可用的 LLM Provider 进行降级');
    }

    Object? lastError;

    for (final candidate in candidates) {
      try {
        final response = await candidate.provider.chat(
          messages: messages,
          tools: tools,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        _activeProvider = candidate.provider;
        return (response, candidate.provider);
      } catch (e) {
        lastError = e;
        // 继续尝试下一个 Provider
        continue;
      }
    }

    throw LlmException(
      '所有 Provider 均调用失败，最后一个错误: $lastError',
    );
  }

  // ———————————————————————————————— 便捷方法 ————————

  /// 切换路由策略
  void switchStrategy(RoutingStrategy newStrategy) {
    strategy = newStrategy;
  }

  /// 手动指定活跃 Provider
  void setActiveProvider(String providerId) {
    final found = _providers.firstWhere(
      (p) => p.provider.providerId == providerId,
    );
    _activeProvider = found.provider;
  }

  // ———————————————————————————————— 生命周期 ————————

  /// 释放资源
  Future<void> dispose() async {
    await _networkController.close();
    for (final p in _providers) {
      await p.provider.dispose();
    }
    _providers.clear();
  }
}

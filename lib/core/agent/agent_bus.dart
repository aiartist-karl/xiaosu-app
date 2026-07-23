/// ============================================================================
/// 小酥 AI 助手 — 事件驱动消息总线 (AgentBus)
/// ============================================================================
/// 实现 Agent 间的松耦合通信，包括：
///   - 基于 StreamController 的广播总线
///   - Agent 事件定义
///   - 订阅/取消订阅机制
///   - 状态查询
/// ============================================================================

import 'dart:async';

// ———————————————————————————————— 事件模型 ————————————————————————————————

/// Agent 事件 sealed 基类
///
/// 所有 Agent 生命周期事件和通信事件都继承自此基类。
/// 使用 sealed class 确保 pattern matching 的完备性。
sealed class AgentEvent {
  /// 事件来源 Agent ID
  final String sourceAgentId;

  /// 事件时间戳
  final DateTime timestamp;

  AgentEvent({required this.sourceAgentId}) : timestamp = DateTime.now();

  @override
  String toString() => '$runtimeType(from: $sourceAgentId)';
}

/// Agent 状态变更事件
class AgentStatusEvent extends AgentEvent {
  /// 新状态
  final AgentStatus status;

  /// 状态描述
  final String message;

  AgentStatusEvent({
    required super.sourceAgentId,
    required this.status,
    this.message = '',
  });
}

/// Agent 任务进度事件
class AgentProgressEvent extends AgentEvent {
  /// 任务 ID
  final String taskId;

  /// 进度 (0.0 ~ 1.0)
  final double progress;

  /// 进度描述
  final String description;

  AgentProgressEvent({
    required super.sourceAgentId,
    required this.taskId,
    required this.progress,
    this.description = '',
  });
}

/// Agent 消息通信事件
///
/// 用于 Agent 间传递数据消息。
class AgentMessageEvent extends AgentEvent {
  /// 目标 Agent ID（null 表示广播）
  final String? targetAgentId;

  /// 消息类型
  final String messageType;

  /// 消息内容
  final dynamic payload;

  /// 关联的请求 ID（用于请求-响应匹配）
  final String? requestId;

  AgentMessageEvent({
    required super.sourceAgentId,
    this.targetAgentId,
    required this.messageType,
    required this.payload,
    this.requestId,
  });
}

/// Agent 结果事件
///
/// Agent 完成任务后发布的结果。
class AgentResultEvent extends AgentEvent {
  /// 任务 ID
  final String taskId;

  /// 是否成功
  final bool success;

  /// 结果数据
  final dynamic data;

  /// 错误信息（失败时）
  final String? error;

  AgentResultEvent({
    required super.sourceAgentId,
    required this.taskId,
    required this.success,
    this.data,
    this.error,
  });
}

/// Agent 错误事件
class AgentErrorEvent extends AgentEvent {
  /// 错误类型
  final String errorType;

  /// 错误信息
  final String message;

  /// 原始异常
  final Object? originalError;

  AgentErrorEvent({
    required super.sourceAgentId,
    required this.errorType,
    required this.message,
    this.originalError,
  });
}

/// Agent 思考过程事件（用于 UI 展示）
class AgentThinkingEvent extends AgentEvent {
  /// 思考内容
  final String thought;

  AgentThinkingEvent({
    required super.sourceAgentId,
    required this.thought,
  });
}

// ———————————————————————————————— Agent 状态 ————————————————————————————————

/// Agent 运行状态
enum AgentStatus {
  /// 空闲，等待任务
  idle,

  /// 正在执行任务
  busy,

  /// 等待其他 Agent 响应
  waiting,

  /// 出错暂停
  error,

  /// 已销毁
  disposed,
}

// ———————————————————————————————— 消息总线 ————————————————————————————————

/// 事件过滤器
///
/// 用于在订阅时过滤特定类型的事件。
typedef EventFilter = bool Function(AgentEvent event);

/// Agent 消息总线
///
/// 基于 StreamController.broadcast 实现的发布-订阅模式，
/// 支持 Agent 间的松耦合通信。
///
/// 使用示例：
/// ```dart
/// final bus = AgentBus();
///
/// // 订阅所有事件
/// bus.subscribe('agent-1', (event) {
///   print('收到事件: $event');
/// });
///
/// // 发布事件
/// bus.publish(AgentMessageEvent(
///   sourceAgentId: 'agent-1',
///   messageType: 'result',
///   payload: '任务完成',
/// ));
/// ```
class AgentBus {
  /// 广播 StreamController
  final StreamController<AgentEvent> _controller =
      StreamController<AgentEvent>.broadcast();

  /// 订阅者映射：agentId → 订阅列表
  final Map<String, List<StreamSubscription<AgentEvent>>> _subscriptions = {};

  /// 已注册的 Agent ID 集合
  final Set<String> _registeredAgents = {};

  /// 各 Agent 当前状态
  final Map<String, AgentStatus> _agentStatuses = {};

  /// 消息总线是否已关闭
  bool _disposed = false;

  // ———————— 注册/注销 ————————

  /// 注册 Agent 到消息总线
  ///
  /// 注册后才能发布和订阅事件。
  void registerAgent(String agentId) {
    _checkDisposed();
    _registeredAgents.add(agentId);
    _agentStatuses[agentId] = AgentStatus.idle;
    _subscriptions[agentId] = [];
  }

  /// 注销 Agent
  ///
  /// 取消该 Agent 的所有订阅。
  void unregisterAgent(String agentId) {
    final subs = _subscriptions.remove(agentId);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _registeredAgents.remove(agentId);
    _agentStatuses.remove(agentId);
  }

  // ———————— 发布事件 ————————

  /// 发布事件到总线
  ///
  /// 所有订阅者都会收到此事件（除非有过滤器）。
  /// 如果事件指定了 targetAgentId，只有目标 Agent 会收到。
  void publish(AgentEvent event) {
    _checkDisposed();

    // 自动更新 Agent 状态
    if (event is AgentStatusEvent) {
      _agentStatuses[event.sourceAgentId] = event.status;
    }

    _controller.add(event);
  }

  /// 向指定 Agent 发送消息
  void sendMessage({
    required String fromAgentId,
    required String toAgentId,
    required String messageType,
    required dynamic payload,
    String? requestId,
  }) {
    publish(AgentMessageEvent(
      sourceAgentId: fromAgentId,
      targetAgentId: toAgentId,
      messageType: messageType,
      payload: payload,
      requestId: requestId,
    ));
  }

  // ———————— 订阅事件 ————————

  /// 订阅事件
  ///
  /// [agentId] 订阅者 Agent ID
  /// [onEvent] 事件回调
  /// [filter] 可选过滤器，返回 true 表示接收该事件
  /// 返回订阅对象，可用于取消订阅
  StreamSubscription<AgentEvent> subscribe(
    String agentId,
    void Function(AgentEvent event) onEvent, {
    EventFilter? filter,
  }) {
    _checkDisposed();

    final subscription = _controller.stream
        .where((event) {
          // 过滤非目标消息
          if (event is AgentMessageEvent &&
              event.targetAgentId != null &&
              event.targetAgentId != agentId) {
            return false;
          }
          // 应用自定义过滤器
          if (filter != null && !filter(event)) {
            return false;
          }
          return true;
        })
        .listen(onEvent);

    _subscriptions[agentId]?.add(subscription);
    return subscription;
  }

  /// 订阅特定类型的事件
  StreamSubscription<AgentEvent> subscribeToType<T extends AgentEvent>(
    String agentId,
    void Function(T event) onEvent,
  ) {
    return subscribe(
      agentId,
      (event) {
        if (event is T) onEvent(event);
      },
    );
  }

  /// 订阅来自特定 Agent 的事件
  StreamSubscription<AgentEvent> subscribeToAgent(
    String subscriberId,
    String targetAgentId,
    void Function(AgentEvent event) onEvent,
  ) {
    return subscribe(
      subscriberId,
      onEvent,
      filter: (event) => event.sourceAgentId == targetAgentId,
    );
  }

  /// 取消指定 Agent 的所有订阅
  void unsubscribeAll(String agentId) {
    final subs = _subscriptions.remove(agentId);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _subscriptions[agentId] = [];
  }

  // ———————— 状态查询 ————————

  /// 获取 Agent 当前状态
  AgentStatus getAgentStatus(String agentId) {
    return _agentStatuses[agentId] ?? AgentStatus.idle;
  }

  /// 设置 Agent 状态（便捷方法）
  void setAgentStatus(String agentId, AgentStatus status, {String message = ''}) {
    _agentStatuses[agentId] = status;
    publish(AgentStatusEvent(
      sourceAgentId: agentId,
      status: status,
      message: message,
    ));
  }

  /// 获取所有已注册的 Agent ID
  Set<String> get registeredAgents => Set.unmodifiable(_registeredAgents);

  /// 事件流（用于直接监听）
  Stream<AgentEvent> get eventStream => _controller.stream;

  // ———————— 生命周期 ————————

  /// 关闭消息总线
  ///
  /// 取消所有订阅并关闭 StreamController。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // 取消所有订阅
    for (final subs in _subscriptions.values) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
    _subscriptions.clear();
    _registeredAgents.clear();
    _agentStatuses.clear();

    await _controller.close();
  }

  /// 检查是否已关闭
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('AgentBus 已被销毁，无法执行操作');
    }
  }
}

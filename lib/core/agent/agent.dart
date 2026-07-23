/// ============================================================================
/// 小酥 AI 助手 — Agent 抽象接口
/// ============================================================================
/// 定义 Agent 系统的核心抽象，包括：
///   - Agent 基类
///   - Task 任务模型
///   - AgentResult 结果模型
///   - AgentRegistry 注册表
/// 所有具体 Agent（Supervisor、Coding、Search 等）都继承 Agent 基类。
/// ============================================================================

import 'dart:async';

import '../common/models.dart';
import '../llm/llm_provider.dart';
import 'agent_bus.dart';
import 'task_dag.dart';

// ———————————————————————————————— 任务模型 ————————————————————————————————

/// 任务请求
///
/// 描述一个需要 Agent 完成的任务，由 Supervisor 创建并分发。
class Task {
  /// 任务唯一 ID
  final String id;

  /// 任务描述（自然语言）
  final String description;

  /// 任务类型标签（用于路由到合适的 Agent）
  final String taskType;

  /// 任务输入数据
  final dynamic inputData;

  /// 关联的会话 ID
  final String? sessionId;

  /// 任务优先级 (0 = 最高)
  final int priority;

  /// 任务创建时间
  final DateTime createdAt;

  /// 附加参数
  final Map<String, dynamic> params;

  Task({
    required this.id,
    required this.description,
    this.taskType = 'general',
    this.inputData,
    this.sessionId,
    this.priority = 0,
    DateTime? createdAt,
    this.params = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Task($id, type=$taskType, "$description")';
}

// ———————————————————————————————— Agent 结果 ————————————————————————————————

/// Agent 执行结果
///
/// 封装 Agent 完成任务后的输出。
sealed class AgentResult {
  /// 来源 Agent ID
  final String agentId;

  /// 关联的任务 ID
  final String taskId;

  /// 执行耗时
  final Duration duration;

  const AgentResult({
    required this.agentId,
    required this.taskId,
    required this.duration,
  });
}

/// 成功结果
class AgentSuccess extends AgentResult {
  /// 结果数据
  final dynamic data;

  /// 人类可读的结果描述
  final String summary;

  /// 产出物路径列表（如生成的文件）
  final List<String> artifacts;

  const AgentSuccess({
    required super.agentId,
    required super.taskId,
    required super.duration,
    required this.data,
    this.summary = '',
    this.artifacts = const [],
  });
}

/// 失败结果
class AgentFailure extends AgentResult {
  /// 错误消息
  final String error;

  /// 错误码
  final String errorCode;

  /// 原始异常
  final Object? originalError;

  const AgentFailure({
    required super.agentId,
    required super.taskId,
    required super.duration,
    required this.error,
    this.errorCode = 'UNKNOWN',
    this.originalError,
  });
}

// ———————————————————————————————— Agent 基类 ————————————————————————————————

/// Agent 抽象基类
///
/// 所有具体 Agent 都必须继承此类并实现 [execute] 方法。
///
/// Agent 的生命周期：
/// 1. 注册到 AgentRegistry
/// 2. 接收 Task 任务
/// 3. 执行 execute() 方法
/// 4. 通过 AgentBus 发布事件
/// 5. 返回 AgentResult
///
/// 使用示例：
/// ```dart
/// class CodingAgent extends Agent {
///   CodingAgent() : super(
///     agentId: 'coding',
///     agentName: '代码助手',
///     capabilities: ['code_generation', 'code_review', 'debug'],
///   );
///
///   @override
///   Future<AgentResult> execute(Task task) async {
///     // 实现具体逻辑...
///   }
/// }
/// ```
abstract class Agent {
  /// Agent 唯一标识
  final String agentId;

  /// Agent 名称（人类可读）
  final String agentName;

  /// Agent 描述
  final String description;

  /// Agent 能力标签列表（用于 Supervisor 路由）
  final List<String> capabilities;

  /// Agent 支持的任务类型
  final List<String> supportedTaskTypes;

  /// 关联的 LLM Provider（可选，部分 Agent 可能不需要 LLM）
  LlmProvider? llmProvider;

  /// 关联的消息总线
  AgentBus? bus;

  /// Agent 当前状态
  AgentStatus _status = AgentStatus.idle;

  /// 统计信息
  int _totalTasks = 0;
  int _successTasks = 0;
  int _failedTasks = 0;

  Agent({
    required this.agentId,
    required this.agentName,
    this.description = '',
    this.capabilities = const [],
    this.supportedTaskTypes = const ['general'],
    this.llmProvider,
    this.bus,
  });

  // ———————— 核心方法 ————————

  /// 执行任务（子类必须实现）
  ///
  /// 接收一个 [Task]，执行相应逻辑，返回 [AgentResult]。
  /// 子类应在此方法中：
  /// 1. 发布进度事件（通过 bus）
  /// 2. 调用 LLM（如需要）
  /// 3. 调用工具（如需要）
  /// 4. 构造并返回结果
  Future<AgentResult> execute(Task task);

  /// 检查 Agent 是否能处理指定任务
  bool canHandle(Task task) {
    // 按任务类型匹配
    if (supportedTaskTypes.contains(task.taskType)) return true;
    // 按能力标签匹配
    if (capabilities.contains(task.taskType)) return true;
    return false;
  }

  // ———————— 事件发布便捷方法 ————————

  /// 发布思考过程（用于 UI 展示）
  void publishThought(String thought) {
    bus?.publish(AgentThinkingEvent(
      sourceAgentId: agentId,
      thought: thought,
    ));
  }

  /// 发布进度更新
  void publishProgress(String taskId, double progress, String description) {
    bus?.publish(AgentProgressEvent(
      sourceAgentId: agentId,
      taskId: taskId,
      progress: progress,
      description: description,
    ));
  }

  /// 发布错误事件
  void publishError(String errorType, String message, [Object? error]) {
    bus?.publish(AgentErrorEvent(
      sourceAgentId: agentId,
      errorType: errorType,
      message: message,
      originalError: error,
    ));
  }

  // ———————— 状态管理 ————————

  /// 当前状态
  AgentStatus get status => _status;

  /// 设置状态
  set status(AgentStatus value) {
    _status = value;
    bus?.setAgentStatus(agentId, value);
  }

  /// 统计信息
  int get totalTasks => _totalTasks;
  int get successTasks => _successTasks;
  int get failedTasks => _failedTasks;
  double get successRate =>
      _totalTasks == 0 ? 0.0 : _successTasks / _totalTasks;

  /// 记录任务执行（在 execute 前后调用）
  void recordSuccess() {
    _totalTasks++;
    _successTasks++;
  }

  void recordFailure() {
    _totalTasks++;
    _failedTasks++;
  }

  // ———————— 生命周期 ————————

  /// 初始化 Agent（注册后调用）
  Future<void> initialize() async {
    status = AgentStatus.idle;
  }

  /// 销毁 Agent
  Future<void> dispose() async {
    status = AgentStatus.disposed;
    bus?.unregisterAgent(agentId);
  }

  @override
  String toString() => 'Agent($agentId: $agentName)';
}

// ———————————————————————————————— Agent 注册表 ————————————————————————————————

/// Agent 注册表
///
/// 管理所有已注册的 Agent 实例，提供查找、路由等功能。
/// Supervisor 通过注册表获取可调度 Agent 列表。
///
/// TODO: 实际项目中使用 Riverpod Provider 管理单例
class AgentRegistry {
  /// 已注册的 Agent 映射
  final Map<String, Agent> _agents = {};

  /// 关联的消息总线
  final AgentBus bus;

  AgentRegistry({required this.bus});

  /// 注册 Agent
  ///
  /// 注册时自动关联消息总线并初始化。
  Future<void> register(Agent agent) async {
    if (_agents.containsKey(agent.agentId)) {
      throw AgentException(
        agent.agentId,
        'Agent "${agent.agentId}" 已注册，不允许重复注册',
      );
    }

    // 关联消息总线
    agent.bus = bus;
    bus.registerAgent(agent.agentId);

    // 注册到映射
    _agents[agent.agentId] = agent;

    // 初始化
    await agent.initialize();
  }

  /// 注销 Agent
  Future<void> unregister(String agentId) async {
    final agent = _agents.remove(agentId);
    if (agent != null) {
      await agent.dispose();
    }
  }

  /// 获取指定 Agent
  Agent? get(String agentId) => _agents[agentId];

  /// 获取所有已注册的 Agent
  List<Agent> get allAgents => _agents.values.toList();

  /// 根据任务类型查找合适的 Agent 列表
  List<Agent> findAgentsForTask(Task task) {
    return _agents.values.where((agent) => agent.canHandle(task)).toList();
  }

  /// 根据能力标签查找 Agent
  List<Agent> findByCapability(String capability) {
    return _agents.values
        .where((agent) => agent.capabilities.contains(capability))
        .toList();
  }

  /// 获取已注册 Agent 数量
  int get length => _agents.length;

  /// 是否为空
  bool get isEmpty => _agents.isEmpty;

  /// 打印注册表（调试用）
  String toDebugString() {
    final buffer = StringBuffer('AgentRegistry (${_agents.length} agents):\n');
    for (final agent in _agents.values) {
      buffer.writeln(
        '  [${agent.status.name}] ${agent.agentId}: ${agent.agentName} '
        '(tasks: ${agent.totalTasks}, success: ${agent.successRate.toStringAsFixed(1)}%)',
      );
      buffer.writeln('    capabilities: ${agent.capabilities.join(", ")}');
    }
    return buffer.toString();
  }

  /// 销毁所有 Agent
  Future<void> disposeAll() async {
    for (final agent in _agents.values) {
      await agent.dispose();
    }
    _agents.clear();
  }
}

/// ============================================================================
/// 小酥 AI 助手 — 任务 DAG (有向无环图)
/// ============================================================================
/// 实现基于 DAG 的任务依赖管理与拓扑排序，支持：
///   - 构建任务依赖图
///   - Kahn's algorithm 拓扑排序
///   - 按层级分组（同层可并行执行）
///   - 环检测
/// ============================================================================

import '../common/models.dart';

// ———————————————————————————————— 任务节点 ————————————————————————————————

/// 任务执行状态
enum TaskStatus {
  /// 等待执行
  pending,

  /// 正在执行
  running,

  /// 执行成功
  completed,

  /// 执行失败
  failed,

  /// 被跳过（依赖失败）
  skipped,
}

/// DAG 中的任务节点
///
/// 每个节点代表一个可独立执行的子任务，
/// 通过依赖关系形成有向无环图。
class TaskNode {
  /// 任务唯一 ID
  final String id;

  /// 任务描述
  final String description;

  /// 目标 Agent ID（由哪个 Agent 执行）
  final String assignedAgentId;

  /// 当前任务状态
  TaskStatus status;

  /// 任务执行结果
  String? result;

  /// 错误信息（失败时）
  String? error;

  /// 依赖的前置任务 ID 列表
  final List<String> dependencies;

  /// 任务优先级 (0 = 最高)
  final int priority;

  /// 任务创建时间
  final DateTime createdAt;

  /// 任务开始执行时间
  DateTime? startedAt;

  /// 任务完成时间
  DateTime? completedAt;

  TaskNode({
    required this.id,
    required this.description,
    required this.assignedAgentId,
    this.status = TaskStatus.pending,
    this.result,
    this.error,
    this.dependencies = const [],
    this.priority = 0,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 耗时（毫秒）
  Duration? get duration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }

  /// 是否已完成（成功或失败）
  bool get isTerminal =>
      status == TaskStatus.completed ||
      status == TaskStatus.failed ||
      status == TaskStatus.skipped;

  @override
  String toString() => 'TaskNode($id, agent=$assignedAgentId, status=$status)';
}

// ———————————————————————————————— DAG 图结构 ————————————————————————————————

/// 任务 DAG 执行计划
///
/// 使用邻接表实现的有向无环图，支持拓扑排序和并行分组。
class TaskDAG {
  /// 计划唯一 ID
  final String planId;

  /// 所有任务节点映射：id → TaskNode
  final Map<String, TaskNode> _nodes = {};

  /// 邻接表：id → 依赖此任务的后续任务 ID 列表
  final Map<String, List<String>> _adjacency = {};

  /// 创建时间
  final DateTime createdAt;

  TaskDAG({required this.planId, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  /// ———————— 构建操作 ————————

  /// 添加任务节点
  ///
  /// [node] 任务节点
  /// 如果存在相同 ID 的节点则抛出异常
  void addNode(TaskNode node) {
    if (_nodes.containsKey(node.id)) {
      throw AgentException(
        'TaskDAG',
        '任务 ID "${node.id}" 已存在，不允许重复',
      );
    }
    _nodes[node.id] = node;
    _adjacency[node.id] = [];

    // 注册反向边
    for (final depId in node.dependencies) {
      if (!_adjacency.containsKey(depId)) {
        throw AgentException(
          'TaskDAG',
          '任务 "${node.id}" 依赖了不存在的任务 "$depId"',
        );
      }
      _adjacency[depId]!.add(node.id);
    }
  }

  /// 批量添加任务节点
  void addAllNodes(List<TaskNode> nodes) {
    for (final node in nodes) {
      addNode(node);
    }
  }

  /// ———————— 查询操作 ————————

  /// 获取所有任务节点
  List<TaskNode> get allNodes => _nodes.values.toList();

  /// 获取指定任务节点
  TaskNode? getNode(String id) => _nodes[id];

  /// 获取任务总数
  int get length => _nodes.length;

  /// 是否为空
  bool get isEmpty => _nodes.isEmpty;

  /// 获取指定任务的后续任务（依赖它的任务）
  List<TaskNode> getDependents(String taskId) {
    final ids = _adjacency[taskId] ?? [];
    return ids.map((id) => _nodes[id]!).toList();
  }

  /// 获取指定任务的前置任务（它依赖的任务）
  List<TaskNode> getDependencies(String taskId) {
    final node = _nodes[taskId];
    if (node == null) return [];
    return node.dependencies
        .where((depId) => _nodes.containsKey(depId))
        .map((depId) => _nodes[depId]!)
        .toList();
  }

  // ———————————————————————————————— 拓扑排序 ————————————————————————————————

  /// Kahn's algorithm 拓扑排序
  ///
  /// 返回拓扑有序的任务 ID 列表。
  /// 如果检测到环则抛出 AgentException。
  ///
  /// 算法步骤：
  /// 1. 计算每个节点的入度
  /// 2. 将入度为 0 的节点加入队列
  /// 3. 依次出队，减少后继节点入度
  /// 4. 若最终排序数量 < 总节点数，说明存在环
  List<String> topologicalSort() {
    // Step 1: 计算入度
    final inDegree = <String, int>{};
    for (final node in _nodes.values) {
      inDegree[node.id] = node.dependencies
          .where((depId) => _nodes.containsKey(depId))
          .length;
    }

    // Step 2: 入度为 0 的节点加入队列
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    // Step 3: BFS 拓扑排序
    final sorted = <String>[];
    while (queue.isNotEmpty) {
      // 从队列中取出入度最小的（按优先级排序）
      queue.sort((a, b) {
        final nodeA = _nodes[a]!;
        final nodeB = _nodes[b]!;
        return nodeA.priority.compareTo(nodeB.priority);
      });
      final current = queue.removeAt(0);
      sorted.add(current);

      // 减少后继节点入度
      for (final nextId in _adjacency[current] ?? []) {
        inDegree[nextId] = (inDegree[nextId] ?? 0) - 1;
        if (inDegree[nextId] == 0) {
          queue.add(nextId);
        }
      }
    }

    // Step 4: 环检测
    if (sorted.length != _nodes.length) {
      final unsorted = _nodes.keys.where((id) => !sorted.contains(id)).toList();
      throw AgentException(
        'TaskDAG',
        '检测到任务依赖环！涉及任务: ${unsorted.join(", ")}',
      );
    }

    return sorted;
  }

  /// 按执行层级分组（同层可并行执行）
  ///
  /// 返回二维列表，每个子列表代表一个执行层级，
  /// 同层内的任务可以并行执行，但必须等前一层级全部完成。
  ///
  /// 示例：
  ///   层级 0: [TaskA]          — 无依赖，可立即执行
  ///   层级 1: [TaskB, TaskC]   — 依赖 TaskA，可并行执行
  ///   层级 2: [TaskD]          — 依赖 TaskB 和 TaskC
  List<List<TaskNode>> groupByLevels() {
    if (_nodes.isEmpty) return [];

    // 计算每个节点的层级（最长路径）
    final levels = <String, int>{};

    // 先做拓扑排序
    final sorted = topologicalSort();

    // 按拓扑序计算层级
    for (final id in sorted) {
      final node = _nodes[id]!;
      if (node.dependencies.isEmpty) {
        levels[id] = 0;
      } else {
        // 当前节点层级 = 所有前置任务层级最大值 + 1
        int maxDepLevel = 0;
        for (final depId in node.dependencies) {
          if (levels.containsKey(depId)) {
            maxDepLevel = maxDepLevel < levels[depId]!
                ? levels[depId]!
                : maxDepLevel;
          }
        }
        levels[id] = maxDepLevel + 1;
      }
    }

    // 按层级分组
    final maxLevel = levels.values.fold(0, (a, b) => a > b ? a : b);
    final result = <List<TaskNode>>[];
    for (int i = 0; i <= maxLevel; i++) {
      final levelNodes = levels.entries
          .where((e) => e.value == i)
          .map((e) => _nodes[e.key]!)
          .toList();
      if (levelNodes.isNotEmpty) {
        result.add(levelNodes);
      }
    }

    return result;
  }

  /// 获取当前可执行的任务（所有依赖已完成）
  ///
  /// 在运行时动态调用，返回所有依赖已满足且状态为 pending 的任务。
  List<TaskNode> getReadyTasks() {
    return _nodes.values.where((node) {
      if (node.status != TaskStatus.pending) return false;
      // 检查所有依赖是否已完成
      return node.dependencies.every((depId) {
        final dep = _nodes[depId];
        return dep != null && dep.status == TaskStatus.completed;
      });
    }).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 是否有任务失败
  bool get hasFailedTasks =>
      _nodes.values.any((n) => n.status == TaskStatus.failed);

  /// 是否全部完成
  bool get isAllCompleted =>
      _nodes.values.every((n) => n.isTerminal);

  /// 获取执行进度 (0.0 ~ 1.0)
  double get progress {
    if (_nodes.isEmpty) return 0.0;
    final completed = _nodes.values.where((n) => n.isTerminal).length;
    return completed / _nodes.length;
  }

  /// 打印 DAG 结构（调试用）
  String toDebugString() {
    final buffer = StringBuffer('TaskDAG(plan=$planId, nodes=${_nodes.length})\n');
    final levels = groupByLevels();
    for (int i = 0; i < levels.length; i++) {
      buffer.writeln('  Level $i:');
      for (final node in levels[i]) {
        buffer.writeln(
            '    [${node.status.name}] ${node.id} (agent=${node.assignedAgentId}) → ${node.description}');
        if (node.dependencies.isNotEmpty) {
          buffer.writeln('      deps: ${node.dependencies.join(", ")}');
        }
      }
    }
    return buffer.toString();
  }
}

/// ============================================================================
/// 小酥 AI 助手 — Supervisor Agent (任务编排)
/// ============================================================================
/// Supervisor 是整个多 Agent 系统的调度中枢，负责：
///   1. 意图分析 — 理解用户请求的真实意图
///   2. 任务分解 — 将复杂请求拆分为可执行的子任务
///   3. DAG 构建 — 分析子任务依赖关系，构建有向无环图
///   4. 拓扑调度 — 按拓扑序调用对应 Agent 执行任务
///   5. 结果合成 — 收集所有子任务结果，生成最终回复
/// ============================================================================

import 'dart:async';

import '../common/models.dart';
import '../llm/llm_provider.dart';
import 'agent.dart';
import 'agent_bus.dart';
import 'task_dag.dart';

// ———————————————————————————————— 意图分析 ————————————————————————————————

/// 意图类型
enum IntentType {
  /// 简单问答 — 直接回答
  simpleQA,

  /// 创作任务 — 写文章、文案等
  creation,

  /// 代码任务 — 编码、调试
  coding,

  /// 搜索任务 — 联网搜索
  search,

  /// 数据分析 — 表格处理、图表
  dataAnalysis,

  /// 复合任务 — 需要多个 Agent 协作
  composite,

  /// 闲聊 — 日常对话
  chitchat,
}

/// 意图分析结果
class IntentResult {
  /// 意图类型
  final IntentType intentType;

  /// 置信度 (0.0 ~ 1.0)
  final double confidence;

  /// 任务复杂度评估
  final TaskComplexity complexity;

  /// 提取的关键词/实体
  final List<String> entities;

  /// 是否需要联网
  final bool needWebSearch;

  /// 是否需要工具调用
  final bool needTools;

  /// 原始分析文本
  final String analysisText;

  const IntentResult({
    required this.intentType,
    this.confidence = 0.8,
    this.complexity = TaskComplexity.medium,
    this.entities = const [],
    this.needWebSearch = false,
    this.needTools = false,
    this.analysisText = '',
  });
}

// ———————————————————————————————— Supervisor Agent ————————————————————————————————

/// Supervisor Agent — 多 Agent 系统的调度中枢
///
/// 核心工作流：
/// ```
/// 用户输入 → 意图分析 → 任务分解 → DAG 构建 → 拓扑调度 → 结果合成 → 输出
/// ```
///
/// Supervisor 本身不执行具体任务，而是协调其他 Agent 协作完成。
///
/// TODO: 实际项目中使用 Riverpod 管理单例
class SupervisorAgent extends Agent {
  /// Agent 注册表（用于查找可调度的 Agent）
  final AgentRegistry registry;

  /// 消息总线
  final AgentBus bus;

  /// 最大并发任务数
  final int maxConcurrency;

  /// 任务超时时间（秒）
  final int taskTimeoutSeconds;

  SupervisorAgent({
    required this.registry,
    required this.bus,
    required LlmProvider llmProvider,
    this.maxConcurrency = 3,
    this.taskTimeoutSeconds = 120,
  }) : super(
          agentId: 'supervisor',
          agentName: '任务编排者',
          description: '负责分析用户意图、分解任务、调度 Agent、合成结果',
          capabilities: [
            'intent_analysis',
            'task_decomposition',
            'task_scheduling',
            'result_synthesis',
          ],
          supportedTaskTypes: ['general', 'composite', 'multi_step'],
          llmProvider: llmProvider,
          bus: bus,
        );

  // ———————————————————————————————— 核心执行流程 ————————————————————————————————

  @override
  Future<AgentResult> execute(Task task) async {
    final startTime = DateTime.now();
    status = AgentStatus.busy;

    try {
      // Step 1: 意图分析
      publishThought('🧠 正在分析用户意图...');
      final intent = await _analyzeIntent(task);
      publishProgress(task.id, 0.1, '意图分析完成: ${intent.intentType.name}');

      // Step 2: 根据意图决定执行策略
      if (intent.complexity == TaskComplexity.simple ||
          intent.intentType == IntentType.simpleQA ||
          intent.intentType == IntentType.chitchat) {
        // 简单任务：直接调用 LLM 回答
        publishThought('💬 简单任务，直接回答...');
        return await _handleSimpleTask(task, intent, startTime);
      }

      // Step 3: 复杂任务 — 任务分解
      publishThought('📋 正在分解任务...');
      final dag = await _decomposeTask(task, intent);
      publishProgress(task.id, 0.3, '任务分解完成，共 ${dag.length} 个子任务');

      // Step 4: 拓扑调度执行
      publishThought('⚡ 开始调度子任务...');
      final results = await _scheduleAndExecute(dag, task);
      publishProgress(task.id, 0.8, '子任务执行完成');

      // Step 5: 结果合成
      publishThought('📝 正在合成最终结果...');
      final finalResult = await _synthesizeResults(task, results, dag);
      publishProgress(task.id, 1.0, '任务完成');

      recordSuccess();
      status = AgentStatus.idle;

      final duration = DateTime.now().difference(startTime);
      return AgentSuccess(
        agentId: agentId,
        taskId: task.id,
        duration: duration,
        data: finalResult,
        summary: '任务编排完成，共执行 ${dag.length} 个子任务',
      );
    } catch (e) {
      recordFailure();
      status = AgentStatus.error;

      final duration = DateTime.now().difference(startTime);
      return AgentFailure(
        agentId: agentId,
        taskId: task.id,
        duration: duration,
        error: 'Supervisor 执行失败: ${e.toString()}',
        errorCode: 'SUPERVISOR_ERROR',
        originalError: e,
      );
    }
  }

  // ———————————————————————————————— 意图分析 ————————————————————————————————

  /// 分析用户输入的意图
  ///
  /// 使用 LLM 快速判断任务类型和复杂度，
  /// 为后续的任务分解和 Agent 路由提供依据。
  Future<IntentResult> _analyzeIntent(Task task) async {
    if (llmProvider == null) {
      // 没有 LLM，使用简单规则匹配
      return _ruleBasedIntentAnalysis(task);
    }

    try {
      // 构造意图分析提示词
      final messages = <LlmMessage>[
        SystemMessage(
          '你是一个任务分类器。分析用户输入，判断任务类型和复杂度。\n'
          '返回 JSON 格式：\n'
          '{"intent": "simpleQA|creation|coding|search|dataAnalysis|composite|chitchat",'
          ' "complexity": "simple|medium|complex|veryComplex",'
          ' "entities": ["关键词1", "关键词2"],'
          ' "needWebSearch": true/false,'
          ' "needTools": true/false}',
        ),
        UserMessage(task.description),
      ];

      final response = await llmProvider!.chat(
        messages: messages,
        temperature: 0.1, // 低温度保证分类稳定性
        maxTokens: 200,
      );

      // 解析 LLM 返回的 JSON
      return _parseIntentResult(response.message.content);
    } catch (e) {
      // LLM 调用失败，降级到规则匹配
      return _ruleBasedIntentAnalysis(task);
    }
  }

  /// 基于规则的意图分析（LLM 不可用时的降级方案）
  IntentResult _ruleBasedIntentAnalysis(Task task) {
    final text = task.description.toLowerCase();

    // 代码相关关键词
    if (text.contains('代码') ||
        text.contains('编程') ||
        text.contains('bug') ||
        text.contains('函数') ||
        text.contains('debug') ||
        text.contains('写一个')) {
      return IntentResult(
        intentType: IntentType.coding,
        complexity: text.length > 100
            ? TaskComplexity.complex
            : TaskComplexity.medium,
        needTools: true,
        analysisText: '规则匹配: 代码任务',
      );
    }

    // 搜索相关
    if (text.contains('搜索') ||
        text.contains('最新') ||
        text.contains('查找') ||
        text.contains('今天')) {
      return IntentResult(
        intentType: IntentType.search,
        complexity: TaskComplexity.simple,
        needWebSearch: true,
        analysisText: '规则匹配: 搜索任务',
      );
    }

    // 简单判断
    if (task.description.length < 30) {
      return IntentResult(
        intentType: IntentType.simpleQA,
        complexity: TaskComplexity.simple,
        analysisText: '规则匹配: 简单问答',
      );
    }

    return IntentResult(
      intentType: IntentType.composite,
      complexity: TaskComplexity.complex,
      needTools: true,
      analysisText: '规则匹配: 复合任务',
    );
  }

  /// 解析意图分析结果
  IntentResult _parseIntentResult(String llmOutput) {
    // TODO: 实际项目中用 jsonDecode 解析
    // 这里简单处理，默认返回中等复杂度
    return IntentResult(
      intentType: IntentType.composite,
      complexity: TaskComplexity.medium,
      analysisText: llmOutput,
    );
  }

  // ———————————————————————————————— 简单任务处理 ————————————————————————————————

  /// 处理简单任务（直接调用 LLM）
  Future<AgentResult> _handleSimpleTask(
    Task task,
    IntentResult intent,
    DateTime startTime,
  ) async {
    if (llmProvider == null) {
      return AgentFailure(
        agentId: agentId,
        taskId: task.id,
        duration: DateTime.now().difference(startTime),
        error: '没有可用的 LLM Provider',
        errorCode: 'NO_LLM',
      );
    }

    try {
      final messages = <LlmMessage>[
        SystemMessage('你是小酥，一个友好、聪明的 AI 助手。请简洁准确地回答用户的问题。'),
        UserMessage(task.description),
      ];

      // 流式输出
      final buffer = StringBuffer();
      await for (final chunk in llmProvider!.streamChat(
        messages: messages,
        temperature: 0.7,
      )) {
        buffer.write(chunk.deltaContent);
      }

      recordSuccess();
      status = AgentStatus.idle;

      return AgentSuccess(
        agentId: agentId,
        taskId: task.id,
        duration: DateTime.now().difference(startTime),
        data: buffer.toString(),
        summary: buffer.toString(),
      );
    } catch (e) {
      recordFailure();
      return AgentFailure(
        agentId: agentId,
        taskId: task.id,
        duration: DateTime.now().difference(startTime),
        error: e.toString(),
        errorCode: 'LLM_ERROR',
        originalError: e,
      );
    }
  }

  // ———————————————————————————————— 任务分解 ————————————————————————————————

  /// 将复杂任务分解为子任务 DAG
  ///
  /// 使用 LLM 分析任务依赖关系，构建 TaskDAG。
  Future<TaskDAG> _decomposeTask(Task task, IntentResult intent) async {
    final dag = TaskDAG(planId: 'plan_${task.id}');

    if (llmProvider == null) {
      // 无 LLM 时的简单分解
      return _simpleDecompose(task, dag);
    }

    try {
      // 获取可用 Agent 列表
      final availableAgents = registry.allAgents;
      final agentDescriptions = availableAgents
          .where((a) => a.agentId != 'supervisor')
          .map((a) => '- ${a.agentId}: ${a.agentName} (${a.capabilities.join(", ")})')
          .join('\n');

      final messages = <LlmMessage>[
        SystemMessage(
          '你是任务规划器。将用户请求分解为子任务，并分配给合适的 Agent。\n'
          '可用 Agent:\n$agentDescriptions\n\n'
          '返回 JSON 数组，每个元素包含:\n'
          '{"id": "task_1", "description": "子任务描述", "agent": "agent_id", "depends_on": []}\n'
          '依赖关系用 depends_on 数组表示（填写前置任务的 id）。',
        ),
        UserMessage(task.description),
      ];

      final response = await llmProvider!.chat(
        messages: messages,
        temperature: 0.2,
        maxTokens: 1000,
      );

      // 解析子任务并构建 DAG
      return _parseDecomposedTasks(response.message.content, dag);
    } catch (e) {
      // 降级到简单分解
      return _simpleDecompose(task, dag);
    }
  }

  /// 简单分解（规则方式，用于 LLM 不可用时）
  TaskDAG _simpleDecompose(Task task, TaskDAG dag) {
    // 默认创建一个单一任务
    dag.addNode(TaskNode(
      id: 'subtask_1',
      description: task.description,
      assignedAgentId: registry.allAgents.isNotEmpty
          ? registry.allAgents.first.agentId
          : 'supervisor',
      dependencies: [],
    ));
    return dag;
  }

  /// 解析 LLM 返回的任务分解结果
  TaskDAG _parseDecomposedTasks(String llmOutput, TaskDAG dag) {
    // TODO: 实际项目中用 jsonDecode 解析
    // 简单占位：创建单个任务
    return _simpleDecompose(Task(id: dag.planId, description: llmOutput), dag);
  }

  // ———————————————————————————————— 拓扑调度 ————————————————————————————————

  /// 按 DAG 拓扑序调度执行子任务
  ///
  /// 核心调度逻辑：
  /// 1. 获取当前可执行的任务（所有依赖已完成）
  /// 2. 并发执行同层任务（不超过 maxConcurrency）
  /// 3. 等待完成后更新状态，重复步骤 1
  /// 4. 直到所有任务完成或出现不可恢复的错误
  Future<Map<String, AgentResult>> _scheduleAndExecute(
    TaskDAG dag,
    Task parentTask,
  ) async {
    final results = <String, AgentResult>{};

    while (!dag.isAllCompleted) {
      final readyTasks = dag.getReadyTasks();

      if (readyTasks.isEmpty && !dag.isAllCompleted) {
        // 没有可执行的任务但未完成 → 可能是死锁
        if (dag.hasFailedTasks) {
          // 有任务失败，跳过依赖失败的任务
          _skipDependentTasks(dag);
          continue;
        }
        break; // 没有可做的了
      }

      // 并发执行本层任务（控制并发数）
      final batch = readyTasks.take(maxConcurrency).toList();
      final futures = batch.map((taskNode) => _executeSubTask(taskNode, dag));

      // 等待本批次完成
      final batchResults = await Future.wait(futures);

      for (final result in batchResults) {
        results[result.$1] = result.$2;
      }

      publishProgress(
        parentTask.id,
        0.3 + dag.progress * 0.5,
        '进度: ${(dag.progress * 100).toStringAsFixed(0)}%',
      );
    }

    return results;
  }

  /// 执行单个子任务
  ///
  /// 从注册表中找到对应的 Agent，执行任务，更新 DAG 节点状态。
  Future<(String, AgentResult)> _executeSubTask(
    TaskNode taskNode,
    TaskDAG dag,
  ) async {
    taskNode.status = TaskStatus.running;
    taskNode.startedAt = DateTime.now();

    // 查找 Agent
    final agent = registry.get(taskNode.assignedAgentId);
    if (agent == null) {
      taskNode.status = TaskStatus.failed;
      taskNode.error = 'Agent "${taskNode.assignedAgentId}" 未注册';
      taskNode.completedAt = DateTime.now();
      return (
        taskNode.id,
        AgentFailure(
          agentId: taskNode.assignedAgentId,
          taskId: taskNode.id,
          duration: Duration.zero,
          error: 'Agent 未找到',
          errorCode: 'AGENT_NOT_FOUND',
        )
      );
    }

    // 收集依赖任务的结果作为上下文
    final contextParts = <String>[];
    for (final depId in taskNode.dependencies) {
      final depNode = dag.getNode(depId);
      if (depNode?.result != null) {
        contextParts.add('[${depNode!.description}]: ${depNode.result}');
      }
    }

    // 构建子任务
    final task = Task(
      id: taskNode.id,
      description: contextParts.isEmpty
          ? taskNode.description
          : '${taskNode.description}\n\n前置任务结果:\n${contextParts.join("\n")}',
      taskType: taskNode.assignedAgentId,
    );

    publishThought('🔄 调度 ${agent.agentName} 执行: ${taskNode.description}');

    try {
      // 执行子任务（带超时控制）
      final result = await agent.execute(task).timeout(
            Duration(seconds: taskTimeoutSeconds),
            onTimeout: () => AgentFailure(
              agentId: agent.agentId,
              taskId: taskNode.id,
              duration: Duration(seconds: taskTimeoutSeconds),
              error: '子任务执行超时 (${taskTimeoutSeconds}s)',
              errorCode: 'TIMEOUT',
            ),
          );

      // 更新 DAG 节点状态
      if (result is AgentSuccess) {
        taskNode.status = TaskStatus.completed;
        taskNode.result = result.summary.isNotEmpty
            ? result.summary
            : result.data?.toString() ?? '';
      } else {
        taskNode.status = TaskStatus.failed;
        taskNode.error = (result as AgentFailure).error;
      }

      taskNode.completedAt = DateTime.now();
      return (taskNode.id, result);
    } catch (e) {
      taskNode.status = TaskStatus.failed;
      taskNode.error = e.toString();
      taskNode.completedAt = DateTime.now();

      return (
        taskNode.id,
        AgentFailure(
          agentId: agent.agentId,
          taskId: taskNode.id,
          duration: DateTime.now().difference(taskNode.startedAt!),
          error: '执行异常: ${e.toString()}',
          errorCode: 'EXECUTION_ERROR',
          originalError: e,
        )
      );
    }
  }

  /// 跳过依赖失败任务的后续任务
  void _skipDependentTasks(TaskDAG dag) {
    for (final node in dag.allNodes) {
      if (node.status != TaskStatus.pending) continue;

      final hasFailedDep = node.dependencies.any((depId) {
        final dep = dag.getNode(depId);
        return dep != null &&
            (dep.status == TaskStatus.failed ||
                dep.status == TaskStatus.skipped);
      });

      if (hasFailedDep) {
        node.status = TaskStatus.skipped;
      }
    }
  }

  // ———————————————————————————————— 结果合成 ————————————————————————————————

  /// 合成所有子任务结果为最终回复
  ///
  /// 使用 LLM 将多个子任务结果整合为连贯的最终回答。
  Future<String> _synthesizeResults(
    Task task,
    Map<String, AgentResult> results,
    TaskDAG dag,
  ) async {
    // 收集所有成功结果
    final successResults = results.entries
        .where((e) => e.value is AgentSuccess)
        .map((e) {
      final node = dag.getNode(e.key);
      final result = e.value as AgentSuccess;
      return '[${node?.description ?? e.key}]: ${result.summary}';
    }).toList();

    // 收集失败信息
    final failedResults = results.entries
        .where((e) => e.value is AgentFailure)
        .map((e) {
      final node = dag.getNode(e.key);
      final result = e.value as AgentFailure;
      return '[${node?.description ?? e.key}] 失败: ${result.error}';
    }).toList();

    // 如果有 LLM，用它来合成
    if (llmProvider != null && successResults.isNotEmpty) {
      try {
        final messages = <LlmMessage>[
          SystemMessage(
            '你是小酥 AI 助手。根据以下子任务执行结果，生成连贯、完整的最终回答。\n'
            '要求：\n'
            '- 回答要自然流畅，不要暴露内部任务分解过程\n'
            '- 如果某些子任务失败，在回答中合理处理\n'
            '- 保持小酥的角色风格',
          ),
          UserMessage(
            '用户原始请求: ${task.description}\n\n'
            '子任务执行结果:\n${successResults.join("\n")}\n'
            '${failedResults.isNotEmpty ? "\n失败的任务:\n${failedResults.join("\n")}" : ""}',
          ),
        ];

        final response = await llmProvider!.chat(
          messages: messages,
          temperature: 0.5,
          maxTokens: 2000,
        );

        return response.message.content;
      } catch (e) {
        // LLM 合成失败，直接拼接
      }
    }

    // 无 LLM 或 LLM 失败，直接拼接结果
    final buffer = StringBuffer();
    if (successResults.isNotEmpty) {
      buffer.writeln('以下是任务执行结果：\n');
      for (final result in successResults) {
        buffer.writeln('• $result');
      }
    }
    if (failedResults.isNotEmpty) {
      buffer.writeln('\n以下任务未能完成：');
      for (final result in failedResults) {
        buffer.writeln('• $result');
      }
    }
    return buffer.toString();
  }
}

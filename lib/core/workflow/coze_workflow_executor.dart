// ============================================================================
// 小酥APP - Coze Studio 工作流执行器
// Phase 4: 对接 Coze Studio 工作流运行 API，支持同步/流式/调试模式
// ============================================================================

import 'dart:async';
import 'dart:convert';
import '../../data/models/workflow_model.dart';
import '../../data/repositories/workflow_repository.dart';

/// Coze Studio 工作流执行器
///
/// 职责:
/// 1. 调用 Coze Studio /v1/workflow/run 同步执行工作流
/// 2. 调用 /v1/workflow/stream_run 流式执行工作流
/// 3. 支持中断恢复 /v1/workflow/stream_resume
/// 4. 节点级调试模式
/// 5. 将 Coze Studio 返回结果转换为本地 WorkflowEngine 可识别的格式
class CozeWorkflowExecutor {
  final WorkflowRepository _repository;

  /// 执行状态回调
  void Function(String nodeId, CozeWorkflowRunStatus status)? onNodeStatusChanged;

  /// 整体执行状态回调
  void Function(CozeWorkflowRunRecord record)? onExecutionChanged;

  /// 日志回调
  void Function(String message)? onLog;

  CozeWorkflowExecutor({
    WorkflowRepository? repository,
    this.onNodeStatusChanged,
    this.onExecutionChanged,
    this.onLog,
  }) : _repository = repository ?? WorkflowRepository();

  // ==========================================================================
  // 同步执行
  // ==========================================================================

  /// 同步执行 Coze Studio 工作流
  ///
  /// 调用 POST /v1/workflow/run
  /// 等待执行完成并返回完整结果
  Future<CozeWorkflowRunRecord> executeSync({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? botId,
    String? conversationId,
  }) async {
    _log('开始同步执行工作流: $workflowId');

    final response = await _repository.runWorkflow(
      workflowId: workflowId,
      parameters: parameters,
      botId: botId,
      conversationId: conversationId,
    );

    if (!response.success) {
      _log('执行失败: ${response.error}');
      // 返回一个失败的记录
      return CozeWorkflowRunRecord(
        runId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        workflowId: workflowId,
        status: CozeWorkflowRunStatus.failed,
        errorMessage: response.error,
        finishedAt: DateTime.now(),
      );
    }

    final record = response.data!;
    _log('执行完成: ${record.runId}, 状态=${record.status.value}');
    onExecutionChanged?.call(record);

    // 将节点级详情通过回调通知
    for (final detail in record.nodeDetails) {
      onNodeStatusChanged?.call(detail.nodeId, detail.status);
    }

    return record;
  }

  /// 使用 [CozeWorkflowRunParams] 执行
  Future<CozeWorkflowRunRecord> executeWithParams(
    CozeWorkflowRunParams params,
  ) async {
    return executeSync(
      workflowId: params.workflowId,
      parameters: params.parameters,
      botId: params.botId,
      conversationId: params.conversationId,
    );
  }

  // ==========================================================================
  // 流式执行
  // ==========================================================================

  /// 流式执行 Coze Studio 工作流
  ///
  /// 调用 POST /v1/workflow/stream_run
  /// 返回 SSE 事件流，逐节点推送中间结果
  ///
  /// 使用示例:
  /// ```dart
  /// final result = await executor.executeStream(
  ///   workflowId: 'wf_xxx',
  ///   parameters: {'input': 'hello'},
  /// );
  ///
  /// result.stream.listen((event) {
  ///   if (event.isMessage) {
  ///     print('节点 ${event.nodeId}: ${event.nodeOutput}');
  ///   } else if (event.isDone) {
  ///     print('执行完成');
  ///   } else if (event.isError) {
  ///     print('错误: ${event.data}');
  ///   }
  /// });
  /// ```
  Future<CozeStreamExecutionResult> executeStream({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? botId,
    String? conversationId,
  }) async {
    _log('开始流式执行工作流: $workflowId');

    final response = await _repository.runWorkflowStream(
      workflowId: workflowId,
      parameters: parameters,
      botId: botId,
      conversationId: conversationId,
    );

    if (!response.success) {
      _log('流式执行失败: ${response.error}');
      return CozeStreamExecutionResult(
        workflowId: workflowId,
        success: false,
        error: response.error,
        stream: const Stream.empty(),
      );
    }

    // 包装流，在流中触发回调
    final controller = StreamController<CozeWorkflowStreamEvent>();
    final collectedEvents = <CozeWorkflowStreamEvent>[];
    String? runId;
    bool hasError = false;
    String? errorMessage;

    response.data!.listen(
      (event) {
        collectedEvents.add(event);

        if (event.isMessage) {
          final nodeId = event.nodeId;
          if (nodeId != null) {
            onNodeStatusChanged?.call(nodeId, CozeWorkflowRunStatus.success);
          }
        } else if (event.isDone) {
          runId = event.data['run_id']?.toString() ??
              event.data['execution_id']?.toString();
          _log('流式执行完成: runId=$runId');
        } else if (event.isError) {
          hasError = true;
          errorMessage = event.data['error_message']?.toString() ??
              event.data['message']?.toString();
          _log('流式执行错误: $errorMessage');
        }

        controller.add(event);
      },
      onError: (error) {
        hasError = true;
        errorMessage = error.toString();
        controller.addError(error);
      },
      onDone: () {
        // 构建最终执行记录
        final record = CozeWorkflowRunRecord(
          runId: runId ?? 'stream_${DateTime.now().millisecondsSinceEpoch}',
          workflowId: workflowId,
          status: hasError
              ? CozeWorkflowRunStatus.failed
              : CozeWorkflowRunStatus.success,
          errorMessage: errorMessage,
          finishedAt: DateTime.now(),
          output: _extractFinalOutput(collectedEvents),
          nodeDetails: _extractNodeDetails(collectedEvents),
        );

        onExecutionChanged?.call(record);
        controller.close();
      },
    );

    return CozeStreamExecutionResult(
      workflowId: workflowId,
      success: true,
      stream: controller.stream,
    );
  }

  /// 恢复流式执行（中断恢复）
  ///
  /// POST /v1/workflow/stream_resume
  Future<CozeStreamExecutionResult> resumeStream({
    required String workflowId,
    required String runId,
    Map<String, dynamic> resumeData = const {},
  }) async {
    _log('恢复流式执行: workflowId=$workflowId, runId=$runId');

    final response = await _repository.resumeWorkflowStream(
      workflowId: workflowId,
      runId: runId,
      resumeData: resumeData,
    );

    if (!response.success) {
      return CozeStreamExecutionResult(
        workflowId: workflowId,
        success: false,
        error: response.error,
        stream: const Stream.empty(),
      );
    }

    final controller = StreamController<CozeWorkflowStreamEvent>();
    response.data!.listen(
      (event) {
        if (event.isMessage) {
          final nodeId = event.nodeId;
          if (nodeId != null) {
            onNodeStatusChanged?.call(nodeId, CozeWorkflowRunStatus.success);
          }
        }
        controller.add(event);
      },
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    return CozeStreamExecutionResult(
      workflowId: workflowId,
      success: true,
      stream: controller.stream,
    );
  }

  // ==========================================================================
  // 聊天流执行
  // ==========================================================================

  /// 聊天流方式运行工作流
  ///
  /// POST /v1/workflows/chat
  /// 适用于对话式工作流，支持多轮对话
  Future<CozeStreamExecutionResult> executeChat({
    required String workflowId,
    required List<Map<String, dynamic>> messages,
    String? conversationId,
  }) async {
    _log('聊天流执行工作流: $workflowId, 消息数=${messages.length}');

    final response = await _repository.chatWorkflow(
      workflowId: workflowId,
      messages: messages,
      conversationId: conversationId,
    );

    if (!response.success) {
      return CozeStreamExecutionResult(
        workflowId: workflowId,
        success: false,
        error: response.error,
        stream: const Stream.empty(),
      );
    }

    final controller = StreamController<CozeWorkflowStreamEvent>();
    response.data!.listen(
      (event) {
        if (event.isMessage) {
          final nodeId = event.nodeId;
          if (nodeId != null) {
            onNodeStatusChanged?.call(nodeId, CozeWorkflowRunStatus.success);
          }
        }
        controller.add(event);
      },
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    return CozeStreamExecutionResult(
      workflowId: workflowId,
      success: true,
      stream: controller.stream,
    );
  }

  // ==========================================================================
  // 调试模式
  // ==========================================================================

  /// 测试运行（调试模式）
  ///
  /// 调用 POST /api/workflow_api/test_run
  /// 支持指定单节点调试
  Future<CozeWorkflowRunRecord> debugRun({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? nodeId,
  }) async {
    _log('调试运行工作流: $workflowId, 节点=$nodeId');

    final response = await _repository.testRunWorkflow(
      workflowId: workflowId,
      parameters: parameters,
      nodeId: nodeId,
    );

    if (!response.success) {
      return CozeWorkflowRunRecord(
        runId: 'debug_${DateTime.now().millisecondsSinceEpoch}',
        workflowId: workflowId,
        status: CozeWorkflowRunStatus.failed,
        errorMessage: response.error,
        finishedAt: DateTime.now(),
      );
    }

    final record = response.data!;
    _log('调试运行完成: ${record.runId}, 状态=${record.status.value}');
    onExecutionChanged?.call(record);
    return record;
  }

  /// 单节点调试
  ///
  /// 调用 POST /api/workflow_api/nodeDebug
  /// 对单个节点进行独立调试执行
  Future<CozeNodeDebugResult> debugNode({
    required String workflowId,
    required String nodeId,
    Map<String, dynamic> inputData = const {},
  }) async {
    _log('调试节点: workflowId=$workflowId, nodeId=$nodeId');

    final response = await _repository.debugNode(
      workflowId: workflowId,
      nodeId: nodeId,
      inputData: inputData,
    );

    if (!response.success) {
      return CozeNodeDebugResult(
        nodeId: nodeId,
        success: false,
        error: response.error,
      );
    }

    final data = response.data ?? {};
    _log('节点调试完成: $nodeId');

    return CozeNodeDebugResult(
      nodeId: nodeId,
      success: true,
      output: data['output'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['output'] as Map)
          : data,
      executionTime: data['execution_time'] is int
          ? Duration(milliseconds: data['execution_time'] as int)
          : null,
      tokenUsage: data['token_usage'] is int ? data['token_usage'] as int : null,
      rawResponse: data,
    );
  }

  // ==========================================================================
  // 运行管理
  // ==========================================================================

  /// 取消正在执行的工作流
  Future<bool> cancelExecution({
    required String workflowId,
    required String runId,
  }) async {
    _log('取消执行: workflowId=$workflowId, runId=$runId');

    final response = await _repository.cancelWorkflowRun(
      workflowId: workflowId,
      runId: runId,
    );

    return response.success;
  }

  /// 获取运行历史
  Future<List<CozeWorkflowRunRecord>> getRunHistory(
    String workflowId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final response = await _repository.fetchRunHistory(
      workflowId: workflowId,
      page: page,
      pageSize: pageSize,
    );

    return response.success ? (response.data ?? []) : [];
  }

  /// 获取执行过程详情
  Future<List<CozeNodeExecutionDetail>> getExecutionProcess({
    required String workflowId,
    required String runId,
  }) async {
    final response = await _repository.fetchExecutionProcess(
      workflowId: workflowId,
      runId: runId,
    );

    return response.success ? (response.data ?? []) : [];
  }

  // ==========================================================================
  // 辅助方法
  // ==========================================================================

  /// 从 SSE 事件流中提取最终输出
  Map<String, dynamic>? _extractFinalOutput(
    List<CozeWorkflowStreamEvent> events,
  ) {
    // 查找 Done 事件中的输出
    for (final event in events.reversed) {
      if (event.isDone && event.data.containsKey('output')) {
        return Map<String, dynamic>.from(event.data['output'] as Map);
      }
    }
    // 查找最后一个 Message 事件中的内容
    for (final event in events.reversed) {
      if (event.isMessage && event.nodeOutput != null) {
        return {'final_output': event.nodeOutput};
      }
    }
    return null;
  }

  /// 从 SSE 事件流中提取节点执行详情
  List<CozeNodeExecutionDetail> _extractNodeDetails(
    List<CozeWorkflowStreamEvent> events,
  ) {
    final nodeMap = <String, CozeNodeExecutionDetail>{};
    final now = DateTime.now();

    for (final event in events) {
      if (event.isMessage && event.nodeId != null) {
        final nodeId = event.nodeId!;
        nodeMap[nodeId] = CozeNodeExecutionDetail(
          nodeId: nodeId,
          nodeName: event.data['node_name']?.toString() ?? '',
          nodeType: event.nodeType ?? '',
          status: CozeWorkflowRunStatus.success,
          startedAt: now,
          finishedAt: now,
          output: event.data.containsKey('content')
              ? {'content': event.data['content']}
              : null,
        );
      }
    }

    return nodeMap.values.toList();
  }

  void _log(String msg) => onLog?.call(msg);
}

/// 流式执行结果
class CozeStreamExecutionResult {
  final String workflowId;
  final bool success;
  final String? error;
  final Stream<CozeWorkflowStreamEvent> stream;

  CozeStreamExecutionResult({
    required this.workflowId,
    required this.success,
    this.error,
    required this.stream,
  });

  /// 收集所有事件并返回完整执行记录
  Future<CozeWorkflowRunRecord> collectAll() async {
    final events = <CozeWorkflowStreamEvent>[];
    await for (final event in stream) {
      events.add(event);
    }

    String? runId;
    bool hasError = false;
    String? errorMessage;
    Map<String, dynamic>? output;

    for (final event in events) {
      if (event.isDone) {
        runId = event.data['run_id']?.toString() ??
            event.data['execution_id']?.toString();
        if (event.data.containsKey('output')) {
          output = Map<String, dynamic>.from(event.data['output'] as Map);
        }
      }
      if (event.isError) {
        hasError = true;
        errorMessage = event.data['error_message']?.toString();
      }
    }

    return CozeWorkflowRunRecord(
      runId: runId ?? 'collected_${DateTime.now().millisecondsSinceEpoch}',
      workflowId: workflowId,
      status: hasError
          ? CozeWorkflowRunStatus.failed
          : CozeWorkflowRunStatus.success,
      errorMessage: errorMessage ?? error,
      output: output,
      finishedAt: DateTime.now(),
    );
  }
}

/// 单节点调试结果
class CozeNodeDebugResult {
  final String nodeId;
  final bool success;
  final Map<String, dynamic>? output;
  final Duration? executionTime;
  final int? tokenUsage;
  final String? error;
  final Map<String, dynamic>? rawResponse;

  CozeNodeDebugResult({
    required this.nodeId,
    required this.success,
    this.output,
    this.executionTime,
    this.tokenUsage,
    this.error,
    this.rawResponse,
  });
}

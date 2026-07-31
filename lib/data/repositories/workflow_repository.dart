// ============================================================================
// 小酥APP - Coze Studio 工作流数据仓库
// Phase 4: 封装所有工作流相关 API 调用
// ============================================================================

import 'dart:convert';
import '../models/workflow_model.dart';
import '../../core/gateway/api_gateway.dart';
import '../../config/app_config.dart';

/// 工作流数据仓库 - 封装所有 Coze Studio 工作流 API 调用
///
/// 分层设计:
/// - OpenAPI v1（PAT 认证）：运行、流式运行、历史查询等
/// - 内部 API（Session 认证）：CRUD、画布、节点管理、调试等
class WorkflowRepository {
  final ApiGateway _api;

  WorkflowRepository({ApiGateway? api}) : _api = api ?? ApiGateway.instance;

  // ==========================================================================
  // OpenAPI v1 — PAT 认证（运行类）
  // ==========================================================================

  /// 同步运行工作流
  ///
  /// POST /v1/workflow/run
  /// Body: { workflow_id, parameters, bot_id?, conversation_id? }
  /// Response: { data: { run_id, execute_status, output?, ... } }
  Future<ApiResponse<CozeWorkflowRunRecord>> runWorkflow({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? botId,
    String? conversationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'parameters': parameters,
      };
      if (botId != null) body['bot_id'] = botId;
      if (conversationId != null) body['conversation_id'] = conversationId;

      final response = await _api.post(
        '/v1/workflow/run',
        body: body,
        authType: CozeAuthType.pat,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '运行工作流失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) {
        return ApiResponse.fail('响应数据为空');
      }

      // Coze v1 API 外层可能有 data 嵌套
      final runData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      final record = CozeWorkflowRunRecord.fromJson({
        ...runData,
        'workflow_id': workflowId,
      });

      return ApiResponse.ok(record);
    } catch (e) {
      return ApiResponse.fail('运行工作流异常: ${e.toString()}');
    }
  }

  /// 流式运行工作流
  ///
  /// POST /v1/workflow/stream_run
  /// Body: { workflow_id, parameters, bot_id?, conversation_id? }
  /// Response: SSE 流
  ///
  /// SSE 事件类型:
  /// - Message: 节点执行中间结果 { node_id, node_type, content, ... }
  /// - Done: 执行完成 { workflow_id, execution_id, ... }
  /// - Error: 执行出错 { error_code, error_message }
  Future<ApiResponse<Stream<CozeWorkflowStreamEvent>>> runWorkflowStream({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? botId,
    String? conversationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'parameters': parameters,
      };
      if (botId != null) body['bot_id'] = botId;
      if (conversationId != null) body['conversation_id'] = conversationId;

      final streamedResponse = await _api.postStream(
        '/v1/workflow/stream_run',
        body: body,
        authType: CozeAuthType.pat,
      );

      if (streamedResponse.statusCode >= 400) {
        final body = await streamedResponse.stream.bytesToString();
        return ApiResponse.fail(
          '流式运行失败: HTTP ${streamedResponse.statusCode} - $body',
          statusCode: streamedResponse.statusCode,
        );
      }

      // 解析 SSE 流
      final stream = streamedResponse.stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data:'))
          .map((line) => CozeWorkflowStreamEvent.fromSseLine(line));

      return ApiResponse.ok(stream);
    } catch (e) {
      return ApiResponse.fail('流式运行异常: ${e.toString()}');
    }
  }

  /// 恢复流式工作流（中断恢复）
  ///
  /// POST /v1/workflow/stream_resume
  /// Body: { workflow_id, run_id, resume_data }
  Future<ApiResponse<Stream<CozeWorkflowStreamEvent>>> resumeWorkflowStream({
    required String workflowId,
    required String runId,
    Map<String, dynamic> resumeData = const {},
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'run_id': runId,
        ...resumeData,
      };

      final streamedResponse = await _api.postStream(
        '/v1/workflow/stream_resume',
        body: body,
        authType: CozeAuthType.pat,
      );

      if (streamedResponse.statusCode >= 400) {
        final respBody = await streamedResponse.stream.bytesToString();
        return ApiResponse.fail(
          '恢复工作流失败: HTTP ${streamedResponse.statusCode} - $respBody',
          statusCode: streamedResponse.statusCode,
        );
      }

      final stream = streamedResponse.stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data:'))
          .map((line) => CozeWorkflowStreamEvent.fromSseLine(line));

      return ApiResponse.ok(stream);
    } catch (e) {
      return ApiResponse.fail('恢复工作流异常: ${e.toString()}');
    }
  }

  /// 获取工作流运行历史
  ///
  /// GET /v1/workflow/get_run_history
  /// Query: workflow_id, page, page_size
  Future<ApiResponse<List<CozeWorkflowRunRecord>>> fetchRunHistory({
    required String workflowId,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.get(
        '/v1/workflow/get_run_history',
        queryParams: {
          'workflow_id': workflowId,
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
        authType: CozeAuthType.pat,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取运行历史失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final runsRaw = data['runs'] as List? ?? data['data'] as List? ?? [];
      final records = runsRaw
          .map((e) => CozeWorkflowRunRecord.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();

      return ApiResponse.ok(records);
    } catch (e) {
      return ApiResponse.fail('获取运行历史异常: ${e.toString()}');
    }
  }

  /// 获取单个工作流信息
  ///
  /// GET /v1/workflows/:workflow_id
  Future<ApiResponse<CozeWorkflowDetail>> fetchWorkflowDetail(
    String workflowId,
  ) async {
    try {
      final response = await _api.get(
        '/v1/workflows/$workflowId',
        authType: CozeAuthType.pat,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取工作流详情失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final detail = CozeWorkflowDetail.fromJson(data);
      return ApiResponse.ok(detail);
    } catch (e) {
      return ApiResponse.fail('获取工作流详情异常: ${e.toString()}');
    }
  }

  /// 聊天流运行工作流
  ///
  /// POST /v1/workflows/chat
  /// Body: { workflow_id, messages, conversation_id?, ... }
  Future<ApiResponse<Stream<CozeWorkflowStreamEvent>>> chatWorkflow({
    required String workflowId,
    required List<Map<String, dynamic>> messages,
    String? conversationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'messages': messages,
      };
      if (conversationId != null) body['conversation_id'] = conversationId;

      final streamedResponse = await _api.postStream(
        '/v1/workflows/chat',
        body: body,
        authType: CozeAuthType.pat,
      );

      if (streamedResponse.statusCode >= 400) {
        final respBody = await streamedResponse.stream.bytesToString();
        return ApiResponse.fail(
          '聊天流运行失败: HTTP ${streamedResponse.statusCode} - $respBody',
          statusCode: streamedResponse.statusCode,
        );
      }

      final stream = streamedResponse.stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data:'))
          .map((line) => CozeWorkflowStreamEvent.fromSseLine(line));

      return ApiResponse.ok(stream);
    } catch (e) {
      return ApiResponse.fail('聊天流运行异常: ${e.toString()}');
    }
  }

  /// 创建工作流会话
  ///
  /// POST /v1/workflow/conversation/create
  /// Body: { workflow_id }
  Future<ApiResponse<String>> createWorkflowConversation(
    String workflowId,
  ) async {
    try {
      final response = await _api.post(
        '/v1/workflow/conversation/create',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.pat,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建工作流会话失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      final conversationId = data?['conversation_id']?.toString();
      if (conversationId == null) {
        return ApiResponse.fail('未获取到 conversation_id');
      }
      return ApiResponse.ok(conversationId);
    } catch (e) {
      return ApiResponse.fail('创建工作流会话异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 内部 API — Session 认证（CRUD、画布、调试）
  // ==========================================================================

  /// 获取工作流列表（内部 API）
  ///
  /// POST /api/workflow_api/workflow_list
  /// Body: { space_id, page, page_size, keyword? }
  Future<ApiResponse<List<CozeWorkflowSummary>>> fetchWorkflowList({
    int page = 0,
    int pageSize = 20,
    String? keyword,
  }) async {
    try {
      final body = <String, dynamic>{
        'space_id': AppConfig.cozeStudioSpaceId,
        'page_index': page,
        'page_size': pageSize,
      };
      if (keyword != null && keyword.isNotEmpty) {
        body['keyword'] = keyword;
      }

      final response = await _api.post(
        '/api/workflow_api/workflow_list',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取工作流列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final listRaw = data['workflows'] as List? ??
          data['data'] as List? ??
          data['list'] as List? ??
          [];

      final items = listRaw
          .map((e) => CozeWorkflowSummary.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();

      return ApiResponse.ok(items);
    } catch (e) {
      return ApiResponse.fail('获取工作流列表异常: ${e.toString()}');
    }
  }

  /// 获取工作流详情（内部 API，含画布信息）
  ///
  /// POST /api/workflow_api/workflow_detail
  /// Body: { workflow_id }
  Future<ApiResponse<CozeWorkflowDetail>> fetchWorkflowDetailInternal(
    String workflowId,
  ) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/workflow_detail',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取工作流详情失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final detailData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      final detail = CozeWorkflowDetail.fromJson(detailData);
      return ApiResponse.ok(detail);
    } catch (e) {
      return ApiResponse.fail('获取工作流详情异常: ${e.toString()}');
    }
  }

  /// 获取工作流画布
  ///
  /// POST /api/workflow_api/canvas
  /// Body: { workflow_id }
  Future<ApiResponse<CozeWorkflowDetail>> fetchWorkflowCanvas(
    String workflowId,
  ) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/canvas',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取画布失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final canvasData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      // 画布接口返回的可能需要合并 workflow_id
      canvasData['workflow_id'] ??= workflowId;

      final detail = CozeWorkflowDetail.fromJson(canvasData);
      return ApiResponse.ok(detail);
    } catch (e) {
      return ApiResponse.fail('获取画布异常: ${e.toString()}');
    }
  }

  /// 创建工作流
  ///
  /// POST /api/workflow_api/create
  /// Body: { name, description?, space_id }
  Future<ApiResponse<CozeWorkflowSummary>> createWorkflow({
    required String name,
    String description = '',
  }) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/create',
        body: {
          'name': name,
          'description': description,
          'space_id': AppConfig.cozeStudioSpaceId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '创建工作流失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final summaryData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      return ApiResponse.ok(CozeWorkflowSummary.fromJson(summaryData));
    } catch (e) {
      return ApiResponse.fail('创建工作流异常: ${e.toString()}');
    }
  }

  /// 保存工作流画布
  ///
  /// POST /api/workflow_api/save
  /// Body: { workflow_id, canvas: { nodes, edges, variables } }
  Future<ApiResponse<bool>> saveWorkflowCanvas({
    required String workflowId,
    required List<Map<String, dynamic>> nodes,
    required List<Map<String, dynamic>> edges,
    Map<String, dynamic>? variables,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'canvas': {
          'nodes': nodes,
          'edges': edges,
          if (variables != null) 'variables': variables,
        },
      };

      final response = await _api.post(
        '/api/workflow_api/save',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '保存画布失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('保存画布异常: ${e.toString()}');
    }
  }

  /// 更新工作流元数据
  ///
  /// POST /api/workflow_api/update_meta
  /// Body: { workflow_id, name?, description? }
  Future<ApiResponse<bool>> updateWorkflowMeta({
    required String workflowId,
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };

      final response = await _api.post(
        '/api/workflow_api/update_meta',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '更新元数据失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('更新元数据异常: ${e.toString()}');
    }
  }

  /// 删除工作流
  ///
  /// POST /api/workflow_api/delete
  /// Body: { workflow_id }
  Future<ApiResponse<bool>> deleteWorkflow(String workflowId) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/delete',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '删除工作流失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('删除工作流异常: ${e.toString()}');
    }
  }

  /// 批量删除工作流
  ///
  /// POST /api/workflow_api/batch_delete
  /// Body: { workflow_ids: [...] }
  Future<ApiResponse<bool>> batchDeleteWorkflows(
    List<String> workflowIds,
  ) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/batch_delete',
        body: {'workflow_ids': workflowIds},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '批量删除失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('批量删除异常: ${e.toString()}');
    }
  }

  /// 复制工作流
  ///
  /// POST /api/workflow_api/copy
  /// Body: { workflow_id, name? }
  Future<ApiResponse<CozeWorkflowSummary>> copyWorkflow(
    String workflowId, {
    String? newName,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        if (newName != null) 'name': newName,
      };

      final response = await _api.post(
        '/api/workflow_api/copy',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '复制工作流失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final summaryData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      return ApiResponse.ok(CozeWorkflowSummary.fromJson(summaryData));
    } catch (e) {
      return ApiResponse.fail('复制工作流异常: ${e.toString()}');
    }
  }

  /// 发布工作流
  ///
  /// POST /api/workflow_api/publish
  /// Body: { workflow_id }
  Future<ApiResponse<bool>> publishWorkflow(String workflowId) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/publish',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '发布工作流失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('发布工作流异常: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 内部 API — 调试与节点管理
  // ==========================================================================

  /// 测试运行工作流（调试模式）
  ///
  /// POST /api/workflow_api/test_run
  /// Body: { workflow_id, parameters, node_id? }
  Future<ApiResponse<CozeWorkflowRunRecord>> testRunWorkflow({
    required String workflowId,
    Map<String, dynamic> parameters = const {},
    String? nodeId,
  }) async {
    try {
      final body = <String, dynamic>{
        'workflow_id': workflowId,
        'parameters': parameters,
      };
      if (nodeId != null) body['node_id'] = nodeId;

      final response = await _api.post(
        '/api/workflow_api/test_run',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '测试运行失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final runData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      return ApiResponse.ok(CozeWorkflowRunRecord.fromJson({
        ...runData,
        'workflow_id': workflowId,
      }));
    } catch (e) {
      return ApiResponse.fail('测试运行异常: ${e.toString()}');
    }
  }

  /// 节点调试
  ///
  /// POST /api/workflow_api/nodeDebug
  /// Body: { workflow_id, node_id, input_data }
  Future<ApiResponse<Map<String, dynamic>>> debugNode({
    required String workflowId,
    required String nodeId,
    Map<String, dynamic> inputData = const {},
  }) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/nodeDebug',
        body: {
          'workflow_id': workflowId,
          'node_id': nodeId,
          'input_data': inputData,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '节点调试失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.fail('响应数据为空');

      final result = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      return ApiResponse.ok(result);
    } catch (e) {
      return ApiResponse.fail('节点调试异常: ${e.toString()}');
    }
  }

  /// 取消工作流执行
  ///
  /// POST /api/workflow_api/cancel
  /// Body: { workflow_id, run_id }
  Future<ApiResponse<bool>> cancelWorkflowRun({
    required String workflowId,
    required String runId,
  }) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/cancel',
        body: {
          'workflow_id': workflowId,
          'run_id': runId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '取消执行失败',
            statusCode: response.statusCode);
      }

      return ApiResponse.ok(true);
    } catch (e) {
      return ApiResponse.fail('取消执行异常: ${e.toString()}');
    }
  }

  /// 获取节点类型列表
  ///
  /// POST /api/workflow_api/node_type
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchNodeTypes() async {
    try {
      final response = await _api.post(
        '/api/workflow_api/node_type',
        body: {'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取节点类型失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final listRaw = data['node_types'] as List? ??
          data['data'] as List? ??
          [];

      final items = listRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      return ApiResponse.ok(items);
    } catch (e) {
      return ApiResponse.fail('获取节点类型异常: ${e.toString()}');
    }
  }

  /// 搜索节点面板
  ///
  /// POST /api/workflow_api/node_panel_search
  /// Body: { keyword, category? }
  Future<ApiResponse<List<Map<String, dynamic>>>> searchNodePanel({
    required String keyword,
    String? category,
  }) async {
    try {
      final body = <String, dynamic>{
        'keyword': keyword,
        'space_id': AppConfig.cozeStudioSpaceId,
      };
      if (category != null) body['category'] = category;

      final response = await _api.post(
        '/api/workflow_api/node_panel_search',
        body: body,
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '搜索节点面板失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final listRaw = data['nodes'] as List? ??
          data['data'] as List? ??
          [];

      return ApiResponse.ok(
          listRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      return ApiResponse.fail('搜索节点面板异常: ${e.toString()}');
    }
  }

  /// 获取执行过程追踪
  ///
  /// GET /api/workflow_api/get_process
  /// Query: workflow_id, run_id
  Future<ApiResponse<List<CozeNodeExecutionDetail>>> fetchExecutionProcess({
    required String workflowId,
    required String runId,
  }) async {
    try {
      final response = await _api.get(
        '/api/workflow_api/get_process',
        queryParams: {
          'workflow_id': workflowId,
          'run_id': runId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取执行过程失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final detailsRaw = data['details'] as List? ??
          data['data'] as List? ??
          data['node_details'] as List? ??
          [];

      final details = detailsRaw
          .map((e) =>
              CozeNodeExecutionDetail.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return ApiResponse.ok(details);
    } catch (e) {
      return ApiResponse.fail('获取执行过程异常: ${e.toString()}');
    }
  }

  /// 获取执行追踪
  ///
  /// GET /api/workflow_api/get_trace
  /// Query: workflow_id, run_id
  Future<ApiResponse<Map<String, dynamic>>> fetchExecutionTrace({
    required String workflowId,
    required String runId,
  }) async {
    try {
      final response = await _api.get(
        '/api/workflow_api/get_trace',
        queryParams: {
          'workflow_id': workflowId,
          'run_id': runId,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取追踪失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const {});

      final traceData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      return ApiResponse.ok(traceData);
    } catch (e) {
      return ApiResponse.fail('获取追踪异常: ${e.toString()}');
    }
  }

  /// 校验工作流树结构
  ///
  /// POST /api/workflow_api/validate_tree
  /// Body: { workflow_id }
  Future<ApiResponse<List<String>>> validateWorkflowTree(
    String workflowId,
  ) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/validate_tree',
        body: {'workflow_id': workflowId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '校验失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final errors = data['errors'] as List? ??
          data['data']?['errors'] as List? ??
          [];

      return ApiResponse.ok(
          errors.map((e) => e.toString()).toList());
    } catch (e) {
      return ApiResponse.fail('校验异常: ${e.toString()}');
    }
  }

  /// 获取已发布工作流列表
  ///
  /// POST /api/workflow_api/list_publish_workflow
  Future<ApiResponse<List<CozeWorkflowSummary>>> fetchPublishedWorkflows({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.post(
        '/api/workflow_api/list_publish_workflow',
        body: {
          'space_id': AppConfig.cozeStudioSpaceId,
          'page_index': page,
          'page_size': pageSize,
        },
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取已发布列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final listRaw = data['workflows'] as List? ??
          data['data'] as List? ??
          [];

      return ApiResponse.ok(listRaw
          .map((e) =>
              CozeWorkflowSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } catch (e) {
      return ApiResponse.fail('获取已发布列表异常: ${e.toString()}');
    }
  }

  /// 获取示例工作流列表
  ///
  /// POST /api/workflow_api/example_workflow_list
  Future<ApiResponse<List<CozeWorkflowSummary>>> fetchExampleWorkflows() async {
    try {
      final response = await _api.post(
        '/api/workflow_api/example_workflow_list',
        body: {'space_id': AppConfig.cozeStudioSpaceId},
        authType: CozeAuthType.session,
      );

      if (!response.success) {
        return ApiResponse.fail(response.error ?? '获取示例列表失败',
            statusCode: response.statusCode);
      }

      final data = response.data;
      if (data == null) return ApiResponse.ok(const []);

      final listRaw = data['workflows'] as List? ??
          data['data'] as List? ??
          [];

      return ApiResponse.ok(listRaw
          .map((e) =>
              CozeWorkflowSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } catch (e) {
      return ApiResponse.fail('获取示例列表异常: ${e.toString()}');
    }
  }
}

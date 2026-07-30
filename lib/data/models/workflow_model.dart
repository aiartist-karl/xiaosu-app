// ============================================================================
// 小酥APP - Coze Studio 工作流数据模型
// Phase 4: 对接 Coze Studio 工作流 API 的数据结构
// ============================================================================

import 'dart:convert';

/// Coze Studio 42 种工作流节点类型
///
/// 分类:
/// - 基础控制（4）: Entry, Exit, Comment, Lambda
/// - AI 能力（3）: LLM, Plugin, CodeRunner
/// - 逻辑控制（6）: Selector, Loop, Batch, Break, Continue, VariableAssignerWithinLoop
/// - 数据操作（4）: VariableAssigner, VariableAggregator, JsonSerialization, JsonDeserialization
/// - 知识库（3）: KnowledgeIndexer, KnowledgeRetriever, KnowledgeDeleter
/// - 数据库（5）: DatabaseQuery, DatabaseInsert, DatabaseUpdate, DatabaseDelete, DatabaseCustomSQL
/// - 对话操作（10）: CreateConversation, ConversationList, ConversationUpdate,
///     ConversationDelete, MessageList, CreateMessage, EditMessage, DeleteMessage,
///     ClearConversationHistory, ConversationHistory
/// - 网络/集成（2）: HTTPRequester, SubWorkflow
/// - 其他（5）: IntentDetector, QuestionAnswer, TextProcessor, InputReceiver, OutputEmitter
enum CozeWorkflowNodeType {
  // 基础控制（4）
  entry('Entry', '开始节点', CozeNodeCategory.control),
  exit('Exit', '结束节点', CozeNodeCategory.control),
  comment('Comment', '注释节点', CozeNodeCategory.control),
  lambda('Lambda', 'Lambda 表达式', CozeNodeCategory.control),

  // AI 能力（3）
  llm('LLM', '大模型调用', CozeNodeCategory.ai),
  plugin('Plugin', '插件调用', CozeNodeCategory.ai),
  codeRunner('CodeRunner', '代码运行', CozeNodeCategory.ai),

  // 逻辑控制（6）
  selector('Selector', '条件分支', CozeNodeCategory.logic),
  loop('Loop', '循环', CozeNodeCategory.logic),
  batch('Batch', '批处理', CozeNodeCategory.logic),
  breakNode('Break', '中断循环', CozeNodeCategory.logic),
  continueNode('Continue', '继续循环', CozeNodeCategory.logic),
  variableAssignerWithinLoop('VariableAssignerWithinLoop', '循环内变量赋值', CozeNodeCategory.logic),

  // 数据操作（4）
  variableAssigner('VariableAssigner', '变量赋值', CozeNodeCategory.data),
  variableAggregator('VariableAggregator', '变量聚合', CozeNodeCategory.data),
  jsonSerialization('JsonSerialization', 'JSON 序列化', CozeNodeCategory.data),
  jsonDeserialization('JsonDeserialization', 'JSON 反序列化', CozeNodeCategory.data),

  // 知识库（3）
  knowledgeIndexer('KnowledgeIndexer', '知识库索引构建', CozeNodeCategory.knowledge),
  knowledgeRetriever('KnowledgeRetriever', '知识库检索', CozeNodeCategory.knowledge),
  knowledgeDeleter('KnowledgeDeleter', '知识库删除', CozeNodeCategory.knowledge),

  // 数据库（5）
  databaseQuery('DatabaseQuery', '数据库查询', CozeNodeCategory.db),
  databaseInsert('DatabaseInsert', '数据库插入', CozeNodeCategory.db),
  databaseUpdate('DatabaseUpdate', '数据库更新', CozeNodeCategory.db),
  databaseDelete('DatabaseDelete', '数据库删除', CozeNodeCategory.db),
  databaseCustomSql('DatabaseCustomSQL', '自定义 SQL', CozeNodeCategory.db),

  // 对话操作（10）
  createConversation('CreateConversation', '创建对话', CozeNodeCategory.conversation),
  conversationList('ConversationList', '对话列表', CozeNodeCategory.conversation),
  conversationUpdate('ConversationUpdate', '更新对话', CozeNodeCategory.conversation),
  conversationDelete('ConversationDelete', '删除对话', CozeNodeCategory.conversation),
  messageList('MessageList', '消息列表', CozeNodeCategory.conversation),
  createMessage('CreateMessage', '创建消息', CozeNodeCategory.conversation),
  editMessage('EditMessage', '编辑消息', CozeNodeCategory.conversation),
  deleteMessage('DeleteMessage', '删除消息', CozeNodeCategory.conversation),
  clearConversationHistory('ClearConversationHistory', '清除对话历史', CozeNodeCategory.conversation),
  conversationHistory('ConversationHistory', '对话历史', CozeNodeCategory.conversation),

  // 网络/集成（2）
  httpRequester('HTTPRequester', 'HTTP 请求', CozeNodeCategory.network),
  subWorkflow('SubWorkflow', '子工作流', CozeNodeCategory.network),

  // 其他（5）
  intentDetector('IntentDetector', '意图识别', CozeNodeCategory.other),
  questionAnswer('QuestionAnswer', '问答', CozeNodeCategory.other),
  textProcessor('TextProcessor', '文本处理', CozeNodeCategory.other),
  inputReceiver('InputReceiver', '输入接收', CozeNodeCategory.other),
  outputEmitter('OutputEmitter', '输出发送', CozeNodeCategory.other);

  final String apiName;
  final String label;
  final CozeNodeCategory category;

  const CozeWorkflowNodeType(this.apiName, this.label, this.category);

  /// 从 API 返回的 type 字符串解析
  static CozeWorkflowNodeType fromApiName(String name) {
    return CozeWorkflowNodeType.values.firstWhere(
      (e) => e.apiName.toLowerCase() == name.toLowerCase(),
      orElse: () => CozeWorkflowNodeType.entry,
    );
  }

  /// 按分类获取节点类型
  static List<CozeWorkflowNodeType> byCategory(CozeNodeCategory cat) {
    return CozeWorkflowNodeType.values.where((e) => e.category == cat).toList();
  }
}

/// 节点分类
enum CozeNodeCategory {
  control('基础控制'),
  ai('AI 能力'),
  logic('逻辑控制'),
  data('数据操作'),
  knowledge('知识库'),
  db('数据库'),
  conversation('对话操作'),
  network('网络/集成'),
  other('其他');

  final String label;
  const CozeNodeCategory(this.label);
}

/// 工作流执行状态
enum CozeWorkflowRunStatus {
  success('success'),
  running('running'),
  failed('failed'),
  cancelled('cancelled'),
  paused('paused');

  final String value;
  const CozeWorkflowRunStatus(this.value);

  static CozeWorkflowRunStatus fromValue(String v) {
    return CozeWorkflowRunStatus.values.firstWhere(
      (e) => e.value == v.toLowerCase(),
      orElse: () => CozeWorkflowRunStatus.running,
    );
  }
}

/// 工作流摘要（列表用）
class CozeWorkflowSummary {
  final String id;
  final String name;
  final String description;
  final String spaceId;
  final String? version;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorUserId;

  CozeWorkflowSummary({
    required this.id,
    required this.name,
    this.description = '',
    this.spaceId = '',
    this.version,
    this.isPublished = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.creatorUserId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory CozeWorkflowSummary.fromJson(Map<String, dynamic> j) {
    return CozeWorkflowSummary(
      id: (j['workflow_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      spaceId: (j['space_id'] ?? '').toString(),
      version: j['version']?.toString(),
      isPublished: j['is_published'] == true || j['status'] == 'published',
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())
          : null,
      creatorUserId: j['creator_user_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'workflow_id': id,
        'name': name,
        'description': description,
        'space_id': spaceId,
        'version': version,
        'is_published': isPublished,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'creator_user_id': creatorUserId,
      };
}

/// Coze Studio 工作流节点
class CozeWorkflowNode {
  final String id;
  final CozeWorkflowNodeType type;
  final String name;
  final Map<String, dynamic> config;
  final double x;
  final double y;
  final List<CozeNodeInput> inputs;
  final List<CozeNodeOutput> outputs;

  CozeWorkflowNode({
    required this.id,
    required this.type,
    this.name = '',
    Map<String, dynamic>? config,
    this.x = 0,
    this.y = 0,
    List<CozeNodeInput>? inputs,
    List<CozeNodeOutput>? outputs,
  })  : config = config ?? {},
        inputs = inputs ?? [],
        outputs = outputs ?? [];

  factory CozeWorkflowNode.fromJson(Map<String, dynamic> j) {
    return CozeWorkflowNode(
      id: (j['node_id'] ?? j['id'] ?? '').toString(),
      type: CozeWorkflowNodeType.fromApiName(
          (j['node_type'] ?? j['type'] ?? 'Entry').toString()),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      config: Map<String, dynamic>.from(j['config'] ?? j['node_config'] ?? {}),
      x: (j['x'] ?? j['position']?['x'] ?? 0).toDouble(),
      y: (j['y'] ?? j['position']?['y'] ?? 0).toDouble(),
      inputs: (j['inputs'] as List?)
              ?.map((e) => CozeNodeInput.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      outputs: (j['outputs'] as List?)
              ?.map((e) => CozeNodeOutput.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': id,
        'node_type': type.apiName,
        'name': name,
        'config': config,
        'x': x,
        'y': y,
        'inputs': inputs.map((e) => e.toJson()).toList(),
        'outputs': outputs.map((e) => e.toJson()).toList(),
      };
}

/// 节点输入参数定义
class CozeNodeInput {
  final String name;
  final String type; // string/number/boolean/object/array/file
  final String? description;
  final dynamic defaultValue;
  final bool required;

  CozeNodeInput({
    required this.name,
    this.type = 'string',
    this.description,
    this.defaultValue,
    this.required = false,
  });

  factory CozeNodeInput.fromJson(Map<String, dynamic> j) => CozeNodeInput(
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'string').toString(),
        description: j['description']?.toString(),
        defaultValue: j['default_value'] ?? j['default'],
        required: j['required'] == true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'description': description,
        'default_value': defaultValue,
        'required': required,
      };
}

/// 节点输出参数定义
class CozeNodeOutput {
  final String name;
  final String type;
  final String? description;

  CozeNodeOutput({
    required this.name,
    this.type = 'string',
    this.description,
  });

  factory CozeNodeOutput.fromJson(Map<String, dynamic> j) => CozeNodeOutput(
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'string').toString(),
        description: j['description']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'description': description,
      };
}

/// 工作流连线（边）
class CozeWorkflowEdge {
  final String sourceNodeId;
  final String targetNodeId;
  final String? sourcePort;
  final String? targetPort;
  final String? condition;

  CozeWorkflowEdge({
    required this.sourceNodeId,
    required this.targetNodeId,
    this.sourcePort,
    this.targetPort,
    this.condition,
  });

  factory CozeWorkflowEdge.fromJson(Map<String, dynamic> j) => CozeWorkflowEdge(
        sourceNodeId: (j['source_node_id'] ?? j['source'] ?? '').toString(),
        targetNodeId: (j['target_node_id'] ?? j['target'] ?? '').toString(),
        sourcePort: j['source_port']?.toString(),
        targetPort: j['target_port']?.toString(),
        condition: j['condition']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'source_port': sourcePort,
        'target_port': targetPort,
        'condition': condition,
      };
}

/// 工作流完整详情（含画布）
class CozeWorkflowDetail {
  final String id;
  final String name;
  final String description;
  final String spaceId;
  final List<CozeWorkflowNode> nodes;
  final List<CozeWorkflowEdge> edges;
  final Map<String, dynamic> globalVariables;
  final String? version;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  CozeWorkflowDetail({
    required this.id,
    required this.name,
    this.description = '',
    this.spaceId = '',
    List<CozeWorkflowNode>? nodes,
    List<CozeWorkflowEdge>? edges,
    Map<String, dynamic>? globalVariables,
    this.version,
    this.isPublished = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : nodes = nodes ?? [],
        edges = edges ?? [],
        globalVariables = globalVariables ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory CozeWorkflowDetail.fromJson(Map<String, dynamic> j) {
    final canvas = j['canvas'] as Map<String, dynamic>? ?? j;
    final nodesRaw = canvas['nodes'] as List? ?? [];
    final edgesRaw = canvas['edges'] as List? ?? [];

    return CozeWorkflowDetail(
      id: (j['workflow_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      spaceId: (j['space_id'] ?? '').toString(),
      nodes: nodesRaw
          .map((e) => CozeWorkflowNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      edges: edgesRaw
          .map((e) => CozeWorkflowEdge.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      globalVariables:
          Map<String, dynamic>.from(j['global_variables'] ?? j['variables'] ?? {}),
      version: j['version']?.toString(),
      isPublished: j['is_published'] == true || j['status'] == 'published',
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'workflow_id': id,
        'name': name,
        'description': description,
        'space_id': spaceId,
        'canvas': {
          'nodes': nodes.map((n) => n.toJson()).toList(),
          'edges': edges.map((e) => e.toJson()).toList(),
        },
        'global_variables': globalVariables,
        'version': version,
        'is_published': isPublished,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// 工作流运行记录
class CozeWorkflowRunRecord {
  final String runId;
  final String workflowId;
  final CozeWorkflowRunStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final Map<String, dynamic>? output;
  final String? errorCode;
  final String? errorMessage;
  final int? tokenUsage;
  final List<CozeNodeExecutionDetail> nodeDetails;

  CozeWorkflowRunRecord({
    required this.runId,
    required this.workflowId,
    this.status = CozeWorkflowRunStatus.running,
    DateTime? startedAt,
    this.finishedAt,
    this.output,
    this.errorCode,
    this.errorMessage,
    this.tokenUsage,
    List<CozeNodeExecutionDetail>? nodeDetails,
  })  : startedAt = startedAt ?? DateTime.now(),
        nodeDetails = nodeDetails ?? [];

  factory CozeWorkflowRunRecord.fromJson(Map<String, dynamic> j) {
    final detailsRaw = j['node_execute_details'] as List? ??
        j['node_details'] as List? ??
        [];
    return CozeWorkflowRunRecord(
      runId: (j['run_id'] ?? j['id'] ?? '').toString(),
      workflowId: (j['workflow_id'] ?? '').toString(),
      status: CozeWorkflowRunStatus.fromValue(
          (j['execute_status'] ?? j['status'] ?? 'running').toString()),
      startedAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      finishedAt: j['finished_at'] != null
          ? DateTime.tryParse(j['finished_at'].toString())
          : null,
      output: j['output'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(j['output'])
          : null,
      errorCode: j['error_code']?.toString(),
      errorMessage: j['error_message']?.toString(),
      tokenUsage: j['token_usage'] is int ? j['token_usage'] : null,
      nodeDetails: detailsRaw
          .map((e) =>
              CozeNodeExecutionDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// 执行耗时
  Duration? get duration =>
      (finishedAt != null) ? finishedAt!.difference(startedAt) : null;

  /// 是否成功
  bool get isSuccess => status == CozeWorkflowRunStatus.success;

  Map<String, dynamic> toJson() => {
        'run_id': runId,
        'workflow_id': workflowId,
        'execute_status': status.value,
        'created_at': startedAt.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
        'output': output,
        'error_code': errorCode,
        'error_message': errorMessage,
        'token_usage': tokenUsage,
        'node_execute_details': nodeDetails.map((e) => e.toJson()).toList(),
      };
}

/// 节点执行详情
class CozeNodeExecutionDetail {
  final String nodeId;
  final String nodeName;
  final String nodeType;
  final CozeWorkflowRunStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Map<String, dynamic>? input;
  final Map<String, dynamic>? output;
  final String? errorMessage;
  final int? tokenUsage;

  CozeNodeExecutionDetail({
    required this.nodeId,
    this.nodeName = '',
    this.nodeType = '',
    this.status = CozeWorkflowRunStatus.running,
    this.startedAt,
    this.finishedAt,
    this.input,
    this.output,
    this.errorMessage,
    this.tokenUsage,
  });

  factory CozeNodeExecutionDetail.fromJson(Map<String, dynamic> j) {
    return CozeNodeExecutionDetail(
      nodeId: (j['node_id'] ?? j['id'] ?? '').toString(),
      nodeName: (j['name'] ?? j['node_name'] ?? '').toString(),
      nodeType: (j['node_type'] ?? j['type'] ?? '').toString(),
      status: CozeWorkflowRunStatus.fromValue(
          (j['execute_status'] ?? j['status'] ?? 'running').toString()),
      startedAt: j['started_at'] != null
          ? DateTime.tryParse(j['started_at'].toString())
          : null,
      finishedAt: j['finished_at'] != null
          ? DateTime.tryParse(j['finished_at'].toString())
          : null,
      input: j['input'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(j['input'])
          : null,
      output: j['output'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(j['output'])
          : null,
      errorMessage: j['error_message']?.toString(),
      tokenUsage: j['token_usage'] is int ? j['token_usage'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'name': nodeName,
        'node_type': nodeType,
        'execute_status': status.value,
        'started_at': startedAt?.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
        'input': input,
        'output': output,
        'error_message': errorMessage,
        'token_usage': tokenUsage,
      };
}

/// 工作流运行请求参数
class CozeWorkflowRunParams {
  final String workflowId;
  final Map<String, dynamic> parameters;
  final String? botId;
  final String? conversationId;
  final String? ext;

  CozeWorkflowRunParams({
    required this.workflowId,
    Map<String, dynamic>? parameters,
    this.botId,
    this.conversationId,
    this.ext,
  }) : parameters = parameters ?? {};

  Map<String, dynamic> toRequestBody() {
    final body = <String, dynamic>{
      'workflow_id': workflowId,
      'parameters': parameters,
    };
    if (botId != null) body['bot_id'] = botId;
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (ext != null) body['ext'] = ext;
    return body;
  }
}

/// SSE 流式事件
class CozeWorkflowStreamEvent {
  final String event; // Message / Done / Error
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CozeWorkflowStreamEvent({
    required this.event,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  })  : data = data ?? {},
        timestamp = timestamp ?? DateTime.now();

  /// 解析 SSE 行
  ///
  /// SSE 格式:
  /// event: Message
  /// data: {"content":"...","node_id":"...","node_type":"..."}
  ///
  /// event: Done
  /// data: {"workflow_id":"...","execution_id":"..."}
  ///
  /// event: Error
  /// data: {"error_code":"...","error_message":"..."}
  factory CozeWorkflowStreamEvent.fromSseLine(String line) {
    if (line.startsWith('data:')) {
      final jsonStr = line.substring(5).trim();
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final event = (data['event'] ?? 'Message').toString();
        return CozeWorkflowStreamEvent(event: event, data: data);
      } catch (_) {
        return CozeWorkflowStreamEvent(
          event: 'Raw',
          data: {'raw': jsonStr},
        );
      }
    }
    if (line.startsWith('event:')) {
      return CozeWorkflowStreamEvent(
        event: line.substring(6).trim(),
      );
    }
    return CozeWorkflowStreamEvent(event: 'Unknown', data: {'raw': line});
  }

  bool get isDone => event == 'Done' || event == 'done';
  bool get isError => event == 'Error' || event == 'error';
  bool get isMessage => event == 'Message' || event == 'message';

  /// 获取节点执行结果（Message 事件）
  String? get nodeOutput => data['content']?.toString() ?? data['output']?.toString();
  String? get nodeId => data['node_id']?.toString();
  String? get nodeType => data['node_type']?.toString();
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// ============================================================
/// Workflow Engine — 自动化工作流引擎
/// ============================================================

// ─── 枚举 ───────────────────────────────────────────────────

enum WorkflowNodeType {
  triggerManual('trigger_manual', '手动触发'),
  triggerSchedule('trigger_schedule', '定时触发'),
  triggerWebhook('trigger_webhook', 'Webhook 触发'),
  triggerEvent('trigger_event', '事件触发'),
  actionLlm('action_llm', 'LLM 调用'),
  actionSkill('action_skill', '技能调用'),
  actionApi('action_api', 'HTTP API 调用'),
  actionCode('action_code', '自定义代码'),
  actionCondition('action_condition', '条件分支'),
  actionLoop('action_loop', '循环'),
  actionParallel('action_parallel', '并行执行'),
  actionDelay('action_delay', '延时等待'),
  actionTransform('action_transform', '数据转换'),
  actionNotification('action_notification', '通知推送'),
  terminator('terminator', '结束节点');

  final String value;
  final String label;
  const WorkflowNodeType(this.value, this.label);

  static WorkflowNodeType fromValue(String v) =>
      WorkflowNodeType.values.firstWhere((e) => e.value == v,
          orElse: () => WorkflowNodeType.terminator);
}

enum WorkflowNodeCategory {
  trigger('触发器'), action('动作'), logic('逻辑'), terminator('终止');
  final String label;
  const WorkflowNodeCategory(this.label);
}

enum WorkflowVariableType {
  string('string'), number('number'), boolean('boolean'),
  array('array'), object('object'), file('file');
  final String value;
  const WorkflowVariableType(this.value);
}

enum WorkflowExecutionStatus { idle, running, paused, completed, failed, cancelled }
enum NodeExecutionStatus { pending, running, completed, failed, skipped, retrying }

// ─── 数据模型 ────────────────────────────────────────────────

class WorkflowVariable {
  final String name;
  final WorkflowVariableType type;
  final dynamic defaultValue;
  dynamic value;

  WorkflowVariable({required this.name, required this.type,
      this.defaultValue, this.value}) {
    value ??= defaultValue;
  }

  Map<String, dynamic> toJson() => {
        'name': name, 'type': type.value,
        'defaultValue': defaultValue, 'value': value,
      };

  factory WorkflowVariable.fromJson(Map<String, dynamic> j) => WorkflowVariable(
        name: j['name'] as String,
        type: WorkflowVariableType.values.firstWhere((e) => e.value == j['type']),
        defaultValue: j['defaultValue'], value: j['value'],
      );
}

class WorkflowNode {
  final String id;
  final WorkflowNodeType type;
  Map<String, dynamic> config;
  double x, y;
  final List<String> inputs, outputs;
  String? label, description;

  WorkflowNode({required this.id, required this.type,
      Map<String, dynamic>? config, this.x = 0, this.y = 0,
      List<String>? inputs, List<String>? outputs,
      this.label, this.description})
      : config = config ?? {},
        inputs = inputs ?? [],
        outputs = outputs ?? [];

  WorkflowNodeCategory get category {
    switch (type) {
      case WorkflowNodeType.triggerManual:
      case WorkflowNodeType.triggerSchedule:
      case WorkflowNodeType.triggerWebhook:
      case WorkflowNodeType.triggerEvent:
        return WorkflowNodeCategory.trigger;
      case WorkflowNodeType.terminator:
        return WorkflowNodeCategory.terminator;
      case WorkflowNodeType.actionCondition:
      case WorkflowNodeType.actionLoop:
      case WorkflowNodeType.actionParallel:
        return WorkflowNodeCategory.logic;
      default:
        return WorkflowNodeCategory.action;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.value, 'config': config,
        'x': x, 'y': y, 'inputs': inputs, 'outputs': outputs,
        'label': label, 'description': description,
      };

  factory WorkflowNode.fromJson(Map<String, dynamic> j) => WorkflowNode(
        id: j['id'] as String,
        type: WorkflowNodeType.fromValue(j['type'] as String),
        config: Map<String, dynamic>.from(j['config'] ?? {}),
        x: (j['x'] ?? 0).toDouble(), y: (j['y'] ?? 0).toDouble(),
        inputs: List<String>.from(j['inputs'] ?? []),
        outputs: List<String>.from(j['outputs'] ?? []),
        label: j['label'] as String?,
        description: j['description'] as String?,
      );
}

class WorkflowEdge {
  final String source, target;
  String? condition, label;
  WorkflowEdge({required this.source, required this.target,
      this.condition, this.label});

  Map<String, dynamic> toJson() => {
        'source': source, 'target': target,
        'condition': condition, 'label': label,
      };
  factory WorkflowEdge.fromJson(Map<String, dynamic> j) => WorkflowEdge(
        source: j['source'] as String, target: j['target'] as String,
        condition: j['condition'] as String?, label: j['label'] as String?,
      );
}

class WorkflowTrigger {
  final String id;
  final WorkflowNodeType type;
  final Map<String, dynamic> params;
  bool enabled;

  WorkflowTrigger({required this.id, required this.type,
      this.params = const {}, this.enabled = true});

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.value,
        'params': params, 'enabled': enabled,
      };
  factory WorkflowTrigger.fromJson(Map<String, dynamic> j) => WorkflowTrigger(
        id: j['id'] as String,
        type: WorkflowNodeType.fromValue(j['type'] as String),
        params: Map<String, dynamic>.from(j['params'] ?? {}),
        enabled: j['enabled'] as bool? ?? true,
      );
}

class Workflow {
  final String id;
  String name, description;
  List<WorkflowNode> nodes;
  List<WorkflowEdge> edges;
  List<WorkflowTrigger> triggers;
  List<WorkflowVariable> variables;
  Map<String, dynamic> metadata;
  DateTime createdAt, updatedAt;
  List<String> tags;

  Workflow({required this.id, required this.name,
      this.description = '', List<WorkflowNode>? nodes,
      List<WorkflowEdge>? edges, List<WorkflowTrigger>? triggers,
      List<WorkflowVariable>? variables, this.metadata = const {},
      DateTime? createdAt, DateTime? updatedAt, List<String>? tags})
      : nodes = nodes ?? [], edges = edges ?? [],
        triggers = triggers ?? [], variables = variables ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tags = tags ?? [];

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'description': description,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'triggers': triggers.map((t) => t.toJson()).toList(),
        'variables': variables.map((v) => v.toJson()).toList(),
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tags': tags,
      };

  factory Workflow.fromJson(Map<String, dynamic> j) => Workflow(
        id: j['id'] as String, name: j['name'] as String,
        description: j['description'] as String? ?? '',
        nodes: (j['nodes'] as List?)?.map((n) =>
            WorkflowNode.fromJson(n as Map<String, dynamic>)).toList() ?? [],
        edges: (j['edges'] as List?)?.map((e) =>
            WorkflowEdge.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        triggers: (j['triggers'] as List?)?.map((t) =>
            WorkflowTrigger.fromJson(t as Map<String, dynamic>)).toList() ?? [],
        variables: (j['variables'] as List?)?.map((v) =>
            WorkflowVariable.fromJson(v as Map<String, dynamic>)).toList() ?? [],
        metadata: Map<String, dynamic>.from(j['metadata'] ?? {}),
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String) : null,
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String) : null,
        tags: (j['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      );

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
  factory Workflow.importJson(String json) =>
      Workflow.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

// ─── 执行记录 ────────────────────────────────────────────────

class NodeExecutionRecord {
  final String nodeId;
  NodeExecutionStatus status;
  DateTime? startedAt, finishedAt;
  String? error;
  Map<String, dynamic> inputData, outputData;
  int retryCount;

  NodeExecutionRecord({required this.nodeId,
      this.status = NodeExecutionStatus.pending,
      this.startedAt, this.finishedAt, this.error,
      Map<String, dynamic>? inputData,
      Map<String, dynamic>? outputData, this.retryCount = 0})
      : inputData = inputData ?? {}, outputData = outputData ?? {};

  Duration? get duration =>
      (startedAt != null && finishedAt != null)
          ? finishedAt!.difference(startedAt!) : null;
}

class WorkflowExecutionRecord {
  final String id, workflowId;
  WorkflowExecutionStatus status;
  DateTime startedAt;
  DateTime? finishedAt;
  List<NodeExecutionRecord> nodeRecords;
  String? error;
  Map<String, dynamic> contextSnapshot;

  WorkflowExecutionRecord({required this.id, required this.workflowId,
      this.status = WorkflowExecutionStatus.idle,
      DateTime? startedAt, this.finishedAt,
      List<NodeExecutionRecord>? nodeRecords, this.error,
      Map<String, dynamic>? contextSnapshot})
      : startedAt = startedAt ?? DateTime.now(),
        nodeRecords = nodeRecords ?? [],
        contextSnapshot = contextSnapshot ?? {};
}

// ─── 表达式引擎 ──────────────────────────────────────────────

class ExpressionEngine {
  static final RegExp _varPattern = RegExp(r'\$\{([^}]+)\}');

  static String interpolate(String template, Map<String, dynamic> context) {
    return template.replaceAllMapped(_varPattern, (match) {
      final value = _resolvePath(match.group(1)!, context);
      return value?.toString() ?? '';
    });
  }

  static dynamic evaluate(String expr, Map<String, dynamic> ctx) {
    final t = expr.trim();
    if (t.startsWith('"') && t.endsWith('"'))
      return interpolate(t.substring(1, t.length - 1), ctx);
    final numVal = num.tryParse(t);
    if (numVal != null) return numVal;
    if (t == 'true') return true;
    if (t == 'false') return false;
    final resolved = _resolvePath(t, ctx);
    if (resolved != null) return resolved;
    // 比较表达式
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      final idx = t.indexOf(op);
      if (idx > 0) {
        final l = evaluate(t.substring(0, idx).trim(), ctx);
        final r = evaluate(t.substring(idx + op.length).trim(), ctx);
        switch (op) {
          case '==': return l == r;
          case '!=': return l != r;
          case '>':  return (l as num) > (r as num);
          case '<':  return (l as num) < (r as num);
          case '>=': return (l as num) >= (r as num);
          case '<=': return (l as num) <= (r as num);
        }
      }
    }
    return t;
  }

  static dynamic _resolvePath(String path, Map<String, dynamic> ctx) {
    dynamic cur = ctx;
    for (final p in path.split('.')) {
      cur = (cur is Map<String, dynamic>) ? cur[p] : null;
      if (cur == null) return null;
    }
    return cur;
  }

  // 日期
  static String now() => DateTime.now().toIso8601String();
  static String formatDate(DateTime d, String fmt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return fmt.replaceAll('yyyy', d.year.toString())
        .replaceAll('MM', pad(d.month)).replaceAll('dd', pad(d.day))
        .replaceAll('HH', pad(d.hour)).replaceAll('mm', pad(d.minute))
        .replaceAll('ss', pad(d.second));
  }

  // 字符串
  static String upper(String s) => s.toUpperCase();
  static String lower(String s) => s.toLowerCase();
  static String trim(String s) => s.trim();
  static String capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  static String substring(String s, int start, [int? end]) =>
      s.substring(start, end);
  static List<String> split(String s, String sep) => s.split(sep);
  static String join(List<dynamic> items, String sep) =>
      items.map((e) => e.toString()).join(sep);
  static bool contains(String s, String sub) => s.contains(sub);
  static String replace(String s, String from, String to) =>
      s.replaceAll(from, to);

  // 数学
  static double abs(double v) => v.abs();
  static double ceil(double v) => v.ceilToDouble();
  static double floor(double v) => v.floorToDouble();
  static double round(double v) => v.roundToDouble();
  static num min(num a, num b) => a < b ? a : b;
  static num max(num a, num b) => a > b ? a : b;

  // 逻辑
  static bool and(bool a, bool b) => a && b;
  static bool or(bool a, bool b) => a || b;
  static bool not(bool a) => !a;

  // 数组
  static int length(List<dynamic> list) => list.length;
  static dynamic first(List<dynamic> list) =>
      list.isNotEmpty ? list.first : null;
  static dynamic last(List<dynamic> list) =>
      list.isNotEmpty ? list.last : null;
  static List<dynamic> reverse(List<dynamic> list) =>
      list.reversed.toList();
}

// ─── Cron 解析器 ──────────────────────────────────────────────

class CronParser {
  static bool shouldRun(String cronExpr, [DateTime? now]) {
    now ??= DateTime.now();
    final parts = cronExpr.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return false;
    return _match(parts[0], now.minute) && _match(parts[1], now.hour) &&
        _match(parts[2], now.day) && _match(parts[3], now.month) &&
        _match(parts[4], now.weekday % 7);
  }

  static bool _match(String field, int value) {
    if (field == '*') return true;
    if (field.contains('/')) return value % int.parse(field.split('/')[1]) == 0;
    if (field.contains(','))
      return field.split(',').map(int.parse).contains(value);
    if (field.contains('-')) {
      final r = field.split('-').map(int.parse).toList();
      return value >= r[0] && value <= r[1];
    }
    return int.tryParse(field) == value;
  }

  static String describe(String cronExpr) {
    final parts = cronExpr.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return '无效的 cron 表达式';
    if (parts[0] == '0' && parts[1] == '0') return '每天午夜';
    if (parts[0] == '0' && parts[1] != '*') return '每天 ${parts[1]}:00';
    if (parts[0] != '*' && parts[1] == '*') return '每小时的第 ${parts[0]} 分钟';
    if (parts[0] == '*' && parts[1] == '*') return '每分钟';
    return '${parts[1]}:${parts[0]}';
  }
}

// ─── 节点执行器 ──────────────────────────────────────────────

abstract class NodeExecutor {
  WorkflowNodeType get type;
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> context);
}

class ManualTriggerExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.triggerManual;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async =>
      {'triggered': true, 'trigger_type': 'manual',
       'timestamp': DateTime.now().toIso8601String()};
}

class ScheduleTriggerExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.triggerSchedule;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final cron = node.config['cron'] as String? ?? '* * * * *';
    return {'cron': cron, 'shouldRun': CronParser.shouldRun(cron),
            'trigger_type': 'schedule',
            'timestamp': DateTime.now().toIso8601String()};
  }
}

class WebhookTriggerExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.triggerWebhook;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async =>
      {'body': ctx['webhook_body'] ?? {}, 'headers': ctx['webhook_headers'] ?? {},
       'received': true, 'trigger_type': 'webhook'};
}

class EventTriggerExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.triggerEvent;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async =>
      {'event': node.config['event_name'] ?? '',
       'payload': ctx['event_payload'] ?? {}, 'trigger_type': 'event'};
}

class LlmExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionLlm;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final prompt = ExpressionEngine.interpolate(
        node.config['prompt'] as String? ?? '', ctx);
    final model = node.config['model'] as String? ?? 'gpt-4';
    final temp = (node.config['temperature'] ?? 0.7).toDouble();
    final maxTok = (node.config['max_tokens'] ?? 2048) as int;
    await Future.delayed(const Duration(milliseconds: 100));
    return {'llm_result': 'LLM[$model] 已处理 prompt（${prompt.length} 字符）',
            'llm_output': '【AI 生成内容】基于提示词的前 $maxTok token 输出',
            'model': model, 'temperature': temp,
            'tokens_used': prompt.length * 2 < maxTok ? prompt.length * 2 : maxTok};
  }
}

class SkillExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionSkill;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final name = node.config['skill_name'] as String? ?? 'unknown';
    final params = Map<String, dynamic>.from(node.config['params'] ?? {});
    final resolved = <String, dynamic>{};
    params.forEach((k, v) => resolved[k] = v is String
        ? ExpressionEngine.interpolate(v, ctx) : v);
    await Future.delayed(const Duration(milliseconds: 50));
    return {'skill_result': '技能 $name 已执行', 'skill_name': name,
            'params': resolved, 'success': true};
  }
}

class ApiExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionApi;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final url = ExpressionEngine.interpolate(
        node.config['url'] as String? ?? '', ctx);
    final method = (node.config['method'] as String? ?? 'GET').toUpperCase();
    final headers = Map<String, String>.from(node.config['headers'] ?? {});
    final bodyCfg = node.config['body'];
    final timeout = (node.config['timeout_ms'] ?? 30000) as int;
    dynamic body = bodyCfg;
    if (bodyCfg is String) body = ExpressionEngine.interpolate(bodyCfg, ctx);
    await Future.delayed(const Duration(milliseconds: 80));
    return {'api_result': '$method $url 已请求', 'method': method,
            'url': url, 'status_code': 200,
            'response_body': {'success': true, 'data': null},
            'headers_sent': headers, 'body_sent': body, 'timeout_ms': timeout};
  }
}

class CodeExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionCode;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final code = node.config['code'] as String? ?? '';
    await Future.delayed(const Duration(milliseconds: 30));
    return {'code_result': '代码已执行（${code.length} 字符）',
            'language': node.config['language'] ?? 'javascript', 'success': true};
  }
}

class ConditionExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionCondition;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final cond = node.config['condition'] as String? ?? 'true';
    final result = ExpressionEngine.evaluate(cond, ctx);
    final bool r = result == true || result == 'true' ||
        (result is num && result != 0) || (result is String && result.isNotEmpty);
    return {'condition_result': r, 'condition_expr': cond,
            'branch': r ? 'then' : 'else'};
  }
}

class LoopExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionLoop;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final path = node.config['collection'] as String? ?? '';
    final resolved = _resolveCtx(path, ctx);
    final items = resolved is List ? resolved : <dynamic>[];
    final maxIt = (node.config['max_iterations'] ?? 1000) as int;
    return {'loop_items': items,
            'loop_count': items.length < maxIt ? items.length : maxIt,
            'current_index': 0, 'max_iterations': maxIt};
  }
  static dynamic _resolveCtx(String path, Map<String, dynamic> ctx) {
    dynamic cur = ctx;
    for (final p in path.split('.')) {
      cur = (cur is Map<String, dynamic>) ? cur[p] : null;
      if (cur == null) return null;
    }
    return cur;
  }
}

class ParallelExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionParallel;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final branches = List<String>.from(node.config['branches'] ?? []);
    return {'parallel_branches': branches, 'branch_count': branches.length,
            'max_concurrency': node.config['max_concurrency'] ?? 5,
            'all_started': true};
  }
}

class DelayExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionDelay;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final ms = ((node.config['delay_ms'] ?? 1000) as int).clamp(0, 5000);
    await Future.delayed(Duration(milliseconds: ms));
    return {'delay_ms': ms, 'completed': true};
  }
}

class TransformExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionTransform;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final mappings = Map<String, String>.from(node.config['mappings'] ?? {});
    final result = <String, dynamic>{};
    mappings.forEach((k, v) => result[k] = ExpressionEngine.interpolate(v, ctx));
    return {'transform_result': result, 'mapping_count': mappings.length};
  }
}

class NotificationExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.actionNotification;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async {
    final channel = node.config['channel'] as String? ?? 'default';
    final title = ExpressionEngine.interpolate(
        node.config['title'] as String? ?? '', ctx);
    final body = ExpressionEngine.interpolate(
        node.config['body'] as String? ?? '', ctx);
    await Future.delayed(const Duration(milliseconds: 30));
    return {'notification_sent': true, 'channel': channel,
            'title': title, 'body': body,
            'recipients': List<String>.from(node.config['recipients'] ?? []),
            'sent_at': DateTime.now().toIso8601String()};
  }
}

class TerminatorExecutor extends NodeExecutor {
  @override
  WorkflowNodeType get type => WorkflowNodeType.terminator;
  @override
  Future<Map<String, dynamic>> execute(
      WorkflowNode node, Map<String, dynamic> ctx) async =>
      {'terminated': true,
       'final_context': Map<String, dynamic>.from(ctx)
         ..removeWhere((k, _) => k.startsWith('_'))};
}

// ─── 执行器注册表 ────────────────────────────────────────────

class ExecutorRegistry {
  final Map<WorkflowNodeType, NodeExecutor> _executors = {};
  ExecutorRegistry() { _registerAll(); }

  void _registerAll() {
    [ManualTriggerExecutor(), ScheduleTriggerExecutor(),
     WebhookTriggerExecutor(), EventTriggerExecutor(),
     LlmExecutor(), SkillExecutor(), ApiExecutor(), CodeExecutor(),
     ConditionExecutor(), LoopExecutor(), ParallelExecutor(),
     DelayExecutor(), TransformExecutor(), NotificationExecutor(),
     TerminatorExecutor()].forEach(register);
  }

  void register(NodeExecutor e) => _executors[e.type] = e;
  NodeExecutor? get(WorkflowNodeType type) => _executors[type];
  bool has(WorkflowNodeType type) => _executors.containsKey(type);
  List<WorkflowNodeType> get registeredTypes => _executors.keys.toList();
}

// ─── DAG 拓扑排序 ────────────────────────────────────────────

class DagSorter {
  static List<String> sort(
      List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
    final inDeg = <String, int>{};
    final adj = <String, List<String>>{};
    final ids = nodes.map((n) => n.id).toSet();
    for (final id in ids) { inDeg[id] = 0; adj[id] = []; }
    for (final e in edges) {
      if (!ids.contains(e.source) || !ids.contains(e.target)) continue;
      adj[e.source]!.add(e.target);
      inDeg[e.target] = (inDeg[e.target] ?? 0) + 1;
    }
    final queue = <String>[];
    inDeg.forEach((k, v) { if (v == 0) queue.add(k); });
    final sorted = <String>[];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      sorted.add(cur);
      for (final nb in adj[cur]!) {
        inDeg[nb] = (inDeg[nb] ?? 1) - 1;
        if (inDeg[nb] == 0) queue.add(nb);
      }
    }
    if (sorted.length != ids.length)
      throw StateError('工作流存在环路，无法完成拓扑排序');
    return sorted;
  }

  static List<String> findStartNodes(
      List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
    final hasIn = edges.map((e) => e.target).toSet();
    return nodes.where((n) => !hasIn.contains(n.id)).map((n) => n.id).toList();
  }

  static List<String> findEndNodes(
      List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
    final hasOut = edges.map((e) => e.source).toSet();
    return nodes.where((n) => !hasOut.contains(n.id)).map((n) => n.id).toList();
  }
}

// ─── 断点信息 ────────────────────────────────────────────────

class BreakpointInfo {
  final String nodeId;
  bool enabled;
  String? condition;
  BreakpointInfo({required this.nodeId, this.enabled = true, this.condition});
}

// ─── 工作流引擎 ──────────────────────────────────────────────

class WorkflowEngine {
  final Map<String, Workflow> _workflows = {};
  final Map<String, WorkflowExecutionRecord> _executions = {};
  final Map<String, List<BreakpointInfo>> _breakpoints = {};
  final ExecutorRegistry _registry = ExecutorRegistry();
  final Random _random = Random();

  void Function(String nodeId, NodeExecutionStatus status)? onNodeStatusChanged;
  void Function(WorkflowExecutionRecord record)? onExecutionChanged;
  void Function(String message)? onLog;

  // ═══ CRUD ═══════════════════════════════════════════════════

  Workflow createWorkflow(Workflow wf) {
    _workflows[wf.id] = wf;
    _log('工作流已创建: ${wf.name}');
    return wf;
  }

  Workflow? getWorkflow(String id) => _workflows[id];
  List<Workflow> listWorkflows() => _workflows.values.toList();

  List<Workflow> searchWorkflows(String keyword) {
    final k = keyword.toLowerCase();
    return _workflows.values.where((w) =>
        w.name.toLowerCase().contains(k) ||
        w.description.toLowerCase().contains(k) ||
        w.tags.any((t) => t.toLowerCase().contains(k))).toList();
  }

  Workflow updateWorkflow(Workflow wf) {
    if (!_workflows.containsKey(wf.id))
      throw StateError('工作流不存在: ${wf.id}');
    wf.updatedAt = DateTime.now();
    _workflows[wf.id] = wf;
    _log('工作流已更新: ${wf.name}');
    return wf;
  }

  void deleteWorkflow(String id) {
    final r = _workflows.remove(id);
    if (r != null) _log('工作流已删除: ${r.name}');
  }

  Workflow copyWorkflow(String id, {String? newName}) {
    final src = _workflows[id];
    if (src == null) throw StateError('工作流不存在: $id');
    final j = src.toJson();
    j['id'] = _genId('wf');
    j['name'] = newName ?? '${src.name} (副本)';
    final cp = Workflow.fromJson(j);
    _workflows[cp.id] = cp;
    _log('工作流已复制: ${src.name} -> ${cp.name}');
    return cp;
  }

  bool workflowExists(String id) => _workflows.containsKey(id);

  // ═══ 导入 / 导出 ═══════════════════════════════════════════

  String exportWorkflow(String id) {
    final wf = _workflows[id];
    if (wf == null) throw StateError('工作流不存在: $id');
    return wf.exportJson();
  }

  Workflow importWorkflow(String json) {
    final wf = Workflow.importJson(json);
    _workflows[wf.id] = wf;
    _log('工作流已导入: ${wf.name}');
    return wf;
  }

  String exportAll() {
    final all = _workflows.values.map((w) => w.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({'workflows': all});
  }

  void importAll(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final list = data['workflows'] as List? ?? [];
    for (final item in list)
      _workflows[(item as Map<String, dynamic>)['id'] as String] =
          Workflow.fromJson(item);
    _log('批量导入 ${list.length} 个工作流');
  }

  // ═══ 断点 ═══════════════════════════════════════════════════

  void setBreakpoint(String wfId, String nodeId, {String? condition}) {
    _breakpoints.putIfAbsent(wfId, () => []);
    _breakpoints[wfId]!.add(BreakpointInfo(nodeId: nodeId, condition: condition));
    _log('断点已设置: $wfId / $nodeId');
  }

  void removeBreakpoint(String wfId, String nodeId) =>
      _breakpoints[wfId]?.removeWhere((b) => b.nodeId == nodeId);

  void clearBreakpoints(String wfId) => _breakpoints.remove(wfId);
  List<BreakpointInfo> getBreakpoints(String wfId) =>
      _breakpoints[wfId] ?? [];

  // ═══ 执行引擎 ═══════════════════════════════════════════════

  Future<WorkflowExecutionRecord> executeWorkflow(
    String workflowId, {
    Map<String, dynamic>? initialContext,
    bool debugMode = false,
  }) async {
    final wf = _workflows[workflowId];
    if (wf == null) throw StateError('工作流不存在: $workflowId');

    final execId = _genId('exec');
    final record = WorkflowExecutionRecord(
      id: execId, workflowId: workflowId,
      status: WorkflowExecutionStatus.running,
      contextSnapshot: Map<String, dynamic>.from(initialContext ?? {}),
    );
    _executions[execId] = record;
    onExecutionChanged?.call(record);
    _log('开始执行工作流: ${wf.name} ($execId)');

    final ctx = <String, dynamic>{
      '_workflow_id': workflowId, '_execution_id': execId,
    };
    for (final v in wf.variables) ctx[v.name] = v.value ?? v.defaultValue;
    if (initialContext != null) ctx.addAll(initialContext);

    try {
      final sortedIds = DagSorter.sort(wf.nodes, wf.edges);
      final nodeMap = {for (final n in wf.nodes) n.id: n};
      final outgoing = <String, List<WorkflowEdge>>{};
      for (final e in wf.edges)
        outgoing.putIfAbsent(e.source, () => []).add(e);

      for (final nodeId in sortedIds) {
        final node = nodeMap[nodeId]!;
        final nr = NodeExecutionRecord(nodeId: nodeId);
        record.nodeRecords.add(nr);

        if (debugMode) {
          final bps = _breakpoints[workflowId] ?? [];
          if (bps.any((b) => b.nodeId == nodeId && b.enabled)) {
            _log('[断点] 在节点 $nodeId 暂停');
            record.status = WorkflowExecutionStatus.paused;
            onNodeStatusChanged?.call(nodeId, NodeExecutionStatus.pending);
            onExecutionChanged?.call(record);
            record.status = WorkflowExecutionStatus.running;
          }
        }

        nr.status = NodeExecutionStatus.running;
        nr.startedAt = DateTime.now();
        nr.inputData = Map<String, dynamic>.from(ctx);
        onNodeStatusChanged?.call(nodeId, NodeExecutionStatus.running);

        final exec = _registry.get(node.type);
        if (exec == null) {
          nr.status = NodeExecutionStatus.failed;
          nr.error = '未找到执行器: ${node.type.label}';
          nr.finishedAt = DateTime.now();
          onNodeStatusChanged?.call(nodeId, NodeExecutionStatus.failed);
          throw StateError(nr.error!);
        }

        final maxRetries = (node.config['max_retries'] ?? 0) as int;
        final retryDelay = (node.config['retry_delay_ms'] ?? 1000) as int;
        bool ok = false;

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            nr.retryCount = attempt;
            if (attempt > 0) {
              nr.status = NodeExecutionStatus.retrying;
              onNodeStatusChanged?.call(nodeId, NodeExecutionStatus.retrying);
              _log('[重试] 节点 $nodeId 第 $attempt 次');
              await Future.delayed(Duration(milliseconds: retryDelay));
            }
            final result = await exec.execute(node, ctx);
            ctx.addAll(result);
            nr.outputData = Map<String, dynamic>.from(result);
            nr.status = NodeExecutionStatus.completed;
            ok = true;
            break;
          } catch (e) {
            if (attempt == maxRetries) {
              nr.status = NodeExecutionStatus.failed;
              nr.error = e.toString();
              onNodeStatusChanged?.call(nodeId, NodeExecutionStatus.failed);
              _log('[错误] 节点 $nodeId: $e');
            }
          }
        }

        nr.finishedAt = DateTime.now();
        onNodeStatusChanged?.call(nodeId,
            ok ? NodeExecutionStatus.completed : NodeExecutionStatus.failed);

        if (node.type == WorkflowNodeType.actionCondition) {
          final branch = ctx['branch'] == 'then' ? 'then' : 'else';
          for (final edge in outgoing[nodeId] ?? []) {
            if (edge.condition != null && edge.condition != branch)
              _log('[条件] 走 $branch 分支，跳过 ${edge.target}');
          }
        }

        if (node.type == WorkflowNodeType.terminator) {
          _log('[终止] 工作流在节点 $nodeId 结束');
          break;
        }
      }

      record.status = WorkflowExecutionStatus.completed;
      record.finishedAt = DateTime.now();
      record.contextSnapshot = Map<String, dynamic>.from(ctx);
      _log('工作流执行完成: ${wf.name}');
    } catch (e) {
      record.status = WorkflowExecutionStatus.failed;
      record.error = e.toString();
      record.finishedAt = DateTime.now();
      _log('工作流执行失败: ${wf.name} — $e');
    }

    onExecutionChanged?.call(record);
    return record;
  }

  void stopExecution(String execId) {
    final r = _executions[execId];
    if (r != null && r.status == WorkflowExecutionStatus.running) {
      r.status = WorkflowExecutionStatus.cancelled;
      r.finishedAt = DateTime.now();
      onExecutionChanged?.call(r);
      _log('执行已取消: $execId');
    }
  }

  List<WorkflowExecutionRecord> getExecutionHistory(String wfId) =>
      (_executions.values.where((e) => e.workflowId == wfId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  WorkflowExecutionRecord? getExecution(String execId) => _executions[execId];
  List<WorkflowExecutionRecord> listAllExecutions() =>
      (_executions.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  // ═══ 触发器调度 ═════════════════════════════════════════════

  Stream<WorkflowExecutionRecord> watchScheduleTriggers(
      Duration pollInterval) async* {
    while (true) {
      await Future.delayed(pollInterval);
      final now = DateTime.now();
      for (final wf in _workflows.values) {
        for (final t in wf.triggers) {
          if (!t.enabled) continue;
          if (t.type == WorkflowNodeType.triggerSchedule) {
            final cron = t.params['cron'] as String? ?? '';
            if (cron.isNotEmpty && CronParser.shouldRun(cron, now)) {
              _log('[调度] 触发工作流: ${wf.name}');
              yield await executeWorkflow(wf.id);
            }
          }
        }
      }
    }
  }

  Future<WorkflowExecutionRecord?> triggerWebhook(
      String wfId, Map<String, dynamic> body) async {
    final wf = _workflows[wfId];
    if (wf == null) return null;
    if (!wf.triggers.any((t) =>
        t.enabled && t.type == WorkflowNodeType.triggerWebhook)) return null;
    return executeWorkflow(wfId, initialContext: {'webhook_body': body});
  }

  Future<WorkflowExecutionRecord?> triggerEvent(
      String wfId, String eventName, Map<String, dynamic> payload) async {
    final wf = _workflows[wfId];
    if (wf == null) return null;
    if (!wf.triggers.any((t) => t.enabled &&
        t.type == WorkflowNodeType.triggerEvent &&
        t.params['event_name'] == eventName)) return null;
    return executeWorkflow(wfId, initialContext: {
      'event_name': eventName, 'event_payload': payload});
  }

  // ═══ 校验与工具 ═════════════════════════════════════════════

  List<String> validateWorkflow(String wfId) {
    final errs = <String>[];
    final wf = _workflows[wfId];
    if (wf == null) return ['工作流不存在'];
    if (wf.nodes.isEmpty) errs.add('工作流没有任何节点');
    if (!wf.nodes.any((n) => n.category == WorkflowNodeCategory.trigger))
      errs.add('缺少触发器节点');
    if (!wf.nodes.any((n) => n.type == WorkflowNodeType.terminator))
      errs.add('缺少终止节点');
    final connected = <String>{};
    for (final e in wf.edges) { connected.add(e.source); connected.add(e.target); }
    for (final n in wf.nodes)
      if (!connected.contains(n.id) && wf.nodes.length > 1)
        errs.add('节点 ${n.id} 未连接任何边');
    try { DagSorter.sort(wf.nodes, wf.edges); }
    catch (e) { errs.add(e.toString()); }
    return errs;
  }

  Map<WorkflowNodeType, int> nodeStats(String wfId) {
    final wf = _workflows[wfId];
    if (wf == null) return {};
    final s = <WorkflowNodeType, int>{};
    for (final n in wf.nodes) s[n.type] = (s[n.type] ?? 0) + 1;
    return s;
  }

  int get workflowCount => _workflows.length;
  int get executionCount => _executions.length;

  String _genId(String p) =>
      '${p}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
  void _log(String msg) => onLog?.call(msg);
}

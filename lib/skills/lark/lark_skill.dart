// ============================================================================
// 小酥 AI 助手 - 飞书集成技能
// ============================================================================
// 提供飞书 Open API 完整封装
// 支持云文档、电子表格、多维表格、即时通讯、任务、日历、审批等
// ============================================================================

import 'dart:async';
import 'dart:convert';

import '../../core/skill/skill.dart';

// ============================================================================
// 飞书认证模型
// ============================================================================

/// 飞书认证类型
enum LarkAuthType {
  /// 租户访问凭证（应用身份）
  tenantAccess('tenant_access_token'),

  /// 用户访问凭证（用户身份）
  userAccess('user_access_token');

  final String value;
  const LarkAuthType(this.value);
}

/// 飞书认证信息
class LarkAuth {
  /// 认证类型
  final LarkAuthType type;

  /// 访问令牌
  final String token;

  /// 过期时间
  final DateTime expiresAt;

  /// 刷新令牌（user_access_token 时可用）
  final String? refreshToken;

  LarkAuth({
    required this.type,
    required this.token,
    required this.expiresAt,
    this.refreshToken,
  });

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 是否需要刷新（提前 5 分钟）
  bool get needsRefresh {
    final buffer = DateTime.now().add(const Duration(minutes: 5));
    return buffer.isAfter(expiresAt);
  }

  /// Authorization header 值
  String get authHeader => '${type.value} $token';
}

/// 飞书应用凭证
class LarkAppCredential {
  /// App ID
  final String appId;

  /// App Secret
  final String appSecret;

  /// Verification Token（事件订阅验证用）
  final String? verificationToken;

  /// Encrypt Key（事件订阅加密用）
  final String? encryptKey;

  const LarkAppCredential({
    required this.appId,
    required this.appSecret,
    this.verificationToken,
    this.encryptKey,
  });
}

// ============================================================================
// 飞书 API 响应模型
// ============================================================================

/// 飞书 API 通用响应
class LarkApiResponse {
  final int code;
  final String msg;
  final Map<String, dynamic>? data;

  LarkApiResponse({
    required this.code,
    required this.msg,
    this.data,
  });

  bool get isSuccess => code == 0;

  factory LarkApiResponse.fromJson(Map<String, dynamic> json) {
    return LarkApiResponse(
      code: json['code'] as int? ?? 0,
      msg: json['msg'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// 飞书文档信息
class LarkDocument {
  final String documentId;
  final String title;
  final String documentType;
  final String? revisionId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final String? ownerUserId;
  final String? url;

  LarkDocument({
    required this.documentId,
    required this.title,
    required this.documentType,
    this.revisionId,
    this.createTime,
    this.updateTime,
    this.ownerUserId,
    this.url,
  });

  factory LarkDocument.fromJson(Map<String, dynamic> json) {
    return LarkDocument(
      documentId: json['document_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'docx',
      revisionId: json['revision_id'] as String?,
      createTime: json['create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['create_time'] as num).toInt() * 1000)
          : null,
      updateTime: json['update_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['update_time'] as num).toInt() * 1000)
          : null,
      ownerUserId: json['owner_id'] as String?,
      url: json['url'] as String?,
    );
  }
}

/// 飞书表格数据
class LarkSheetData {
  final String spreadsheetToken;
  final String sheetId;
  final String range;
  final List<List<dynamic>> values;

  LarkSheetData({
    required this.spreadsheetToken,
    required this.sheetId,
    required this.range,
    required this.values,
  });

  int get rowCount => values.length;
  int get colCount => values.isNotEmpty ? values.first.length : 0;
}

/// 多维表格记录
class BitableRecord {
  final String recordId;
  final Map<String, dynamic> fields;
  final DateTime? createTime;
  final DateTime? updateTime;

  BitableRecord({
    required this.recordId,
    required this.fields,
    this.createTime,
    this.updateTime,
  });

  factory BitableRecord.fromJson(Map<String, dynamic> json) {
    return BitableRecord(
      recordId: json['record_id'] as String? ?? '',
      fields: json['fields'] as Map<String, dynamic>? ?? {},
      createTime: json['created_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['created_time'] as num).toInt() * 1000)
          : null,
      updateTime: json['last_modified_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['last_modified_time'] as num).toInt() * 1000)
          : null,
    );
  }
}

/// 飞书消息类型
enum LarkMessageType {
  text('text'),
  post('post'),
  interactive('interactive'),
  image('image'),
  file('file'),
  audio('audio'),
  media('media'),
  sticker('sticker'),
  shareChat('share_chat'),
  shareUser('share_user');

  final String value;
  const LarkMessageType(this.value);
}

/// 消息接收者类型
enum LarkReceiveIdType {
  openId('open_id'),
  userId('user_id'),
  unionId('union_id'),
  email('email'),
  chatId('chat_id');

  final String value;
  const LarkReceiveIdType(this.value);
}

// ============================================================================
// 飞书集成技能
// ============================================================================

/// 飞书集成技能
/// 提供 create_doc, read_doc, update_doc, create_sheet 等 15 个工具
class LarkSkill extends Skill {
  /// 技能配置
  final LarkSkillConfig _config;

  /// 当前认证信息
  LarkAuth? _currentAuth;

  /// 应用凭证
  final LarkAppCredential? _credential;

  /// Token 缓存
  final Map<String, LarkAuth> _tokenCache = {};

  /// API 请求频率限制器
  int _requestCount = 0;
  DateTime _rateLimitReset = DateTime.now();
  static const int _maxRequestsPerMinute = 100;

  LarkSkill({
    LarkSkillConfig? config,
    LarkAppCredential? credential,
  })  : _config = config ?? const LarkSkillConfig(),
        _credential = credential;

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'lark',
        name: '飞书集成',
        description: '与飞书平台深度集成。支持创建和编辑云文档、操作电子表格、'
            '管理多维表格、发送消息、创建任务、管理日历、提交审批流、'
            '管理知识库 Wiki、上传下载文件等。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.localStorage,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _createDocTool,
        _readDocTool,
        _updateDocTool,
        _createSheetTool,
        _readSheetTool,
        _updateSheetTool,
        _createBitableTool,
        _queryBitableTool,
        _sendMessageTool,
        _createTaskTool,
        _createCalendarEventTool,
        _uploadFileTool,
        _searchDocsTool,
        _createWikiTool,
        _sendApprovalTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  late final SkillTool _createDocTool = SkillTool(
    name: 'create_doc',
    description: '在飞书中创建新文档。支持创建云文档（docx）并写入初始内容。'
        '可指定文件夹位置。',
    parameters: [
      ToolParameter(name: 'title', description: '文档标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'content', description: '文档初始内容（富文本 JSON 或 Markdown）', type: ToolParameterType.stringType),
      ToolParameter(name: 'folder_token', description: '父文件夹 token（不传则创建在根目录）', type: ToolParameterType.stringType),
      ToolParameter(name: 'format', description: '内容格式', type: ToolParameterType.stringType, enumValues: ['markdown', 'rich_text'], defaultValue: 'markdown'),
    ],
    timeoutMs: 30000,
    execute: _executeCreateDoc,
  );

  late final SkillTool _readDocTool = SkillTool(
    name: 'read_doc',
    description: '读取飞书文档内容。返回文档的完整文本或富文本结构。',
    parameters: [
      ToolParameter(name: 'document_id', description: '文档 ID 或 URL', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'format', description: '返回格式', type: ToolParameterType.stringType, enumValues: ['text', 'markdown', 'rich_text'], defaultValue: 'markdown'),
      ToolParameter(name: 'include_comments', description: '是否包含评论/批注', type: ToolParameterType.boolType, defaultValue: false),
    ],
    timeoutMs: 20000,
    execute: _executeReadDoc,
  );

  late final SkillTool _updateDocTool = SkillTool(
    name: 'update_doc',
    description: '更新飞书文档内容。支持追加内容、替换指定区块、插入富文本等。',
    parameters: [
      ToolParameter(name: 'document_id', description: '文档 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'content', description: '要写入的内容', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'mode', description: '更新模式', type: ToolParameterType.stringType, enumValues: ['append', 'replace', 'insert_before', 'insert_after'], defaultValue: 'append'),
      ToolParameter(name: 'block_id', description: '目标区块 ID（replace/insert 模式时必填）', type: ToolParameterType.stringType),
      ToolParameter(name: 'format', description: '内容格式', type: ToolParameterType.stringType, enumValues: ['markdown', 'rich_text'], defaultValue: 'markdown'),
    ],
    timeoutMs: 20000,
    execute: _executeUpdateDoc,
  );

  late final SkillTool _createSheetTool = SkillTool(
    name: 'create_sheet',
    description: '在飞书中创建电子表格或在工作簿中新建工作表。',
    parameters: [
      ToolParameter(name: 'title', description: '表格标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'spreadsheet_token', description: '已有工作簿 token（在此工作簿中新建 sheet）', type: ToolParameterType.stringType),
      ToolParameter(name: 'headers', description: '表头列名列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'data', description: '初始数据（二维数组）', type: ToolParameterType.arrayType),
      ToolParameter(name: 'folder_token', description: '父文件夹 token', type: ToolParameterType.stringType),
    ],
    timeoutMs: 30000,
    execute: _executeCreateSheet,
  );

  late final SkillTool _readSheetTool = SkillTool(
    name: 'read_sheet',
    description: '读取飞书电子表格中的数据。支持指定范围读取。',
    parameters: [
      ToolParameter(name: 'spreadsheet_token', description: '电子表格 token', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'sheet_id', description: '工作表 ID', type: ToolParameterType.stringType),
      ToolParameter(name: 'range', description: '读取范围，如 A1:D10', type: ToolParameterType.stringType),
      ToolParameter(name: 'has_header', description: '首行是否为表头', type: ToolParameterType.boolType, defaultValue: true),
    ],
    timeoutMs: 20000,
    execute: _executeReadSheet,
  );

  late final SkillTool _updateSheetTool = SkillTool(
    name: 'update_sheet',
    description: '更新飞书电子表格中的数据。支持写入单元格、设置公式、格式化。',
    parameters: [
      ToolParameter(name: 'spreadsheet_token', description: '电子表格 token', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'sheet_id', description: '工作表 ID', type: ToolParameterType.stringType),
      ToolParameter(name: 'range', description: '写入范围，如 A1:D10', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'values', description: '写入数据（二维数组）', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'format', description: '是否同时设置格式', type: ToolParameterType.boolType, defaultValue: false),
    ],
    timeoutMs: 20000,
    execute: _executeUpdateSheet,
  );

  late final SkillTool _createBitableTool = SkillTool(
    name: 'create_bitable',
    description: '创建飞书多维表格（Bitable）。可配置字段定义和初始数据。',
    parameters: [
      ToolParameter(name: 'name', description: '多维表格名称', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'fields', description: '字段定义列表，每项包含 name 和 type', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'records', description: '初始记录数据', type: ToolParameterType.arrayType),
      ToolParameter(name: 'folder_token', description: '父文件夹 token', type: ToolParameterType.stringType),
    ],
    timeoutMs: 30000,
    execute: _executeCreateBitable,
  );

  late final SkillTool _queryBitableTool = SkillTool(
    name: 'query_bitable',
    description: '查询飞书多维表格数据。支持条件过滤、排序、分页。',
    parameters: [
      ToolParameter(name: 'app_token', description: '多维表格 app_token', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'table_id', description: '数据表 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'filter', description: '过滤条件（飞书 filter 表达式）', type: ToolParameterType.stringType),
      ToolParameter(name: 'sort', description: '排序字段列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'page_size', description: '每页记录数', type: ToolParameterType.intType, minValue: 1, maxValue: 500, defaultValue: 20),
      ToolParameter(name: 'page_token', description: '分页 token', type: ToolParameterType.stringType),
      ToolParameter(name: 'view_id', description: '视图 ID', type: ToolParameterType.stringType),
    ],
    timeoutMs: 20000,
    execute: _executeQueryBitable,
  );

  late final SkillTool _sendMessageTool = SkillTool(
    name: 'send_message',
    description: '通过飞书发送消息。支持文本、富文本、消息卡片等格式。'
        '可发送给个人、群聊。',
    parameters: [
      ToolParameter(name: 'receive_id', description: '接收者 ID（open_id / user_id / email / chat_id）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'receive_id_type', description: '接收者 ID 类型', type: ToolParameterType.stringType, enumValues: ['open_id', 'user_id', 'email', 'chat_id'], defaultValue: 'open_id'),
      ToolParameter(name: 'msg_type', description: '消息类型', type: ToolParameterType.stringType, enumValues: ['text', 'post', 'interactive'], defaultValue: 'text'),
      ToolParameter(name: 'content', description: '消息内容（JSON 字符串）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'reply_message_id', description: '回复的消息 ID（可选）', type: ToolParameterType.stringType),
    ],
    timeoutMs: 15000,
    execute: _executeSendMessage,
  );

  late final SkillTool _createTaskTool = SkillTool(
    name: 'create_task',
    description: '在飞书中创建任务。可指定负责人、截止时间、描述等。',
    parameters: [
      ToolParameter(name: 'title', description: '任务标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'description', description: '任务描述', type: ToolParameterType.stringType),
      ToolParameter(name: 'due_date', description: '截止时间（ISO 8601 格式）', type: ToolParameterType.stringType),
      ToolParameter(name: 'assignee_ids', description: '负责人 open_id 列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'priority', description: '优先级', type: ToolParameterType.stringType, enumValues: ['none', 'low', 'medium', 'high', 'urgent'], defaultValue: 'medium'),
    ],
    timeoutMs: 15000,
    execute: _executeCreateTask,
  );

  late final SkillTool _createCalendarEventTool = SkillTool(
    name: 'create_calendar_event',
    description: '在飞书日历中创建日程。支持设置时间、参与人、会议室、提醒等。',
    parameters: [
      ToolParameter(name: 'summary', description: '日程标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'start_time', description: '开始时间（ISO 8601）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'end_time', description: '结束时间（ISO 8601）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'description', description: '日程描述', type: ToolParameterType.stringType),
      ToolParameter(name: 'attendee_ids', description: '参与人 open_id 列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'visibility', description: '可见性', type: ToolParameterType.stringType, enumValues: ['default', 'public', 'private'], defaultValue: 'default'),
      ToolParameter(name: 'reminders', description: '提醒时间（分钟），如 [15, 5] 表示提前15分钟和5分钟', type: ToolParameterType.arrayType),
      ToolParameter(name: 'color', description: '日程颜色', type: ToolParameterType.intType, minValue: 0, maxValue: 11),
    ],
    timeoutMs: 15000,
    execute: _executeCreateCalendarEvent,
  );

  late final SkillTool _uploadFileTool = SkillTool(
    name: 'upload_file',
    description: '上传文件到飞书云空间。支持上传到指定文件夹。',
    parameters: [
      ToolParameter(name: 'file_path', description: '本地文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'file_name', description: '文件名', type: ToolParameterType.stringType),
      ToolParameter(name: 'folder_token', description: '目标文件夹 token', type: ToolParameterType.stringType),
      ToolParameter(name: 'file_type', description: '文件类型', type: ToolParameterType.stringType, enumValues: ['opus', 'mp4', 'pdf', 'doc', 'xls', 'ppt', 'other'], defaultValue: 'other'),
    ],
    timeoutMs: 60000,
    execute: _executeUploadFile,
  );

  late final SkillTool _searchDocsTool = SkillTool(
    name: 'search_docs',
    description: '搜索飞书云空间中的文档。支持按关键词、类型、时间等搜索。',
    parameters: [
      ToolParameter(name: 'query', description: '搜索关键词', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'doc_types', description: '文档类型过滤', type: ToolParameterType.arrayType),
      ToolParameter(name: 'count', description: '返回数量', type: ToolParameterType.intType, minValue: 1, maxValue: 50, defaultValue: 10),
      ToolParameter(name: 'owner_ids', description: '创建者 ID 过滤', type: ToolParameterType.arrayType),
    ],
    timeoutMs: 15000,
    execute: _executeSearchDocs,
  );

  late final SkillTool _createWikiTool = SkillTool(
    name: 'create_wiki',
    description: '在飞书知识库中创建 Wiki 节点。支持创建知识空间、添加节点。',
    parameters: [
      ToolParameter(name: 'space_id', description: '知识空间 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'title', description: '节点标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'parent_node_token', description: '父节点 token', type: ToolParameterType.stringType),
      ToolParameter(name: 'content', description: '节点内容（Markdown）', type: ToolParameterType.stringType),
      ToolParameter(name: 'node_type', description: '节点类型', type: ToolParameterType.stringType, enumValues: ['doc', 'sheet', 'bitable', 'dir'], defaultValue: 'doc'),
    ],
    timeoutMs: 30000,
    execute: _executeCreateWiki,
  );

  late final SkillTool _sendApprovalTool = SkillTool(
    name: 'send_approval',
    description: '发起飞书审批流程。指定审批定义和表单数据。',
    parameters: [
      ToolParameter(name: 'approval_code', description: '审批定义 code', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'form_data', description: '审批表单数据（JSON）', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'user_id', description: '发起人 open_id', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'department_id', description: '发起人部门 ID', type: ToolParameterType.stringType),
    ],
    timeoutMs: 15000,
    execute: _executeSendApproval,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('飞书集成技能初始化');

    // 尝试加载已保存的认证信息
    final savedToken = await context.storage.get('lark_auth_token');
    final savedExpires = await context.storage.get('lark_auth_expires');
    final savedType = await context.storage.get('lark_auth_type');

    if (savedToken != null && savedExpires != null) {
      final expires = DateTime.tryParse(savedExpires);
      if (expires != null && expires.isAfter(DateTime.now())) {
        _currentAuth = LarkAuth(
          type: savedType == 'user' ? LarkAuthType.userAccess : LarkAuthType.tenantAccess,
          token: savedToken,
          expiresAt: expires,
        );
        context.logger.info('已恢复飞书认证信息');
      }
    }

    // 自动获取 tenant_access_token
    if (_currentAuth == null && _credential != null) {
      await _refreshTenantToken(context);
    }
  }

  @override
  Future<void> onDispose() async {
    _tokenCache.clear();
    _currentAuth = null;
  }

  // ============================================================================
  // 认证管理
  // ============================================================================

  /// 获取 tenant_access_token
  Future<void> _refreshTenantToken(SkillContext context) async {
    if (_credential == null) return;

    try {
      final response = await context.http.post(
        '${_config.apiBase}/auth/v3/tenant_access_token/internal',
        headers: {'Content-Type': 'application/json'},
        body: {
          'app_id': _credential!.appId,
          'app_secret': _credential!.appSecret,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final code = data['code'] as int? ?? -1;
      if (code != 0) {
        context.logger.error('获取 tenant token 失败: ${data['msg']}');
        return;
      }

      final token = data['tenant_access_token'] as String;
      final expire = data['expire'] as int? ?? 7200;

      _currentAuth = LarkAuth(
        type: LarkAuthType.tenantAccess,
        token: token,
        expiresAt: DateTime.now().add(Duration(seconds: expire)),
      );

      // 持久化
      await context.storage.set('lark_auth_token', token);
      await context.storage.set('lark_auth_expires', _currentAuth!.expiresAt.toIso8601String());
      await context.storage.set('lark_auth_type', 'tenant');

      context.logger.info('tenant_access_token 已刷新 (有效期: ${expire}s)');
    } catch (e) {
      context.logger.error('刷新 token 异常', e);
    }
  }

  /// 确保认证有效
  Future<bool> _ensureAuth(SkillContext context) async {
    if (_currentAuth == null) {
      if (_credential != null) {
        await _refreshTenantToken(context);
      }
      if (_currentAuth == null) {
        return false;
      }
    }
    if (_currentAuth!.needsRefresh && _credential != null) {
      await _refreshTenantToken(context);
    }
    return _currentAuth != null && !_currentAuth!.isExpired;
  }

  /// 构建请求头
  Map<String, String> _buildHeaders() {
    _requestCount++;
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${_currentAuth!.token}',
    };
  }

  /// 频率限制检查
  bool _checkRateLimit() {
    final now = DateTime.now();
    if (now.isAfter(_rateLimitReset)) {
      _requestCount = 0;
      _rateLimitReset = now.add(const Duration(minutes: 1));
    }
    return _requestCount < _maxRequestsPerMinute;
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  Future<ToolResult> _executeCreateDoc(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败，请检查应用凭证', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final title = args['title'] as String;
    final content = args['content'] as String?;
    final folderToken = args['folder_token'] as String?;
    final format = args['format'] as String? ?? 'markdown';

    context.logger.info('创建文档: $title');

    try {
      final body = <String, dynamic>{
        'title': title,
        if (folderToken != null) 'folder_token': folderToken,
      };

      final createResp = await context.http.post(
        '${_config.apiBase}/docx/v1/documents',
        headers: _buildHeaders(),
        body: body,
      );

      final apiResp = LarkApiResponse.fromJson(jsonDecode(createResp) as Map<String, dynamic>);
      if (!apiResp.isSuccess) {
        return ToolResult.failure(error: '创建文档失败: ${apiResp.msg}', errorCode: 'API_ERROR');
      }

      final docId = apiResp.data?['document']?['document_id'] as String? ?? '';
      final revisionId = apiResp.data?['document']?['revision_id']?.toString() ?? '';

      // 如果有初始内容，写入文档
      if (content != null && content.isNotEmpty && docId.isNotEmpty) {
        final blocks = _convertContentToBlocks(content, format);
        await context.http.post(
          '${_config.apiBase}/docx/v1/documents/$docId/blocks/${docId}/children',
          headers: _buildHeaders(),
          body: {'children': blocks, 'index': 0},
        );
      }

      final docUrl = 'https://xiaoshu.feishu.cn/docx/$docId';

      return ToolResult.success(
        content: '文档已创建: $title\n文档 ID: $docId\n链接: $docUrl',
        data: {
          'document_id': docId,
          'title': title,
          'revision_id': revisionId,
          'url': docUrl,
        },
      );
    } catch (e) {
      context.logger.error('创建文档失败', e);
      return ToolResult.failure(error: '创建文档异常: $e', errorCode: 'CREATE_DOC_ERROR');
    }
  }

  Future<ToolResult> _executeReadDoc(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final documentId = _extractDocumentId(args['document_id'] as String);
    final format = args['format'] as String? ?? 'markdown';
    final includeComments = args['include_comments'] as bool? ?? false;

    context.logger.info('读取文档: $documentId');

    try {
      // 获取文档基本信息
      final rawInfo = await context.http.get(
        '${_config.apiBase}/docx/v1/documents/$documentId',
        headers: _buildHeaders(),
      );
      final infoResp = LarkApiResponse.fromJson(jsonDecode(rawInfo) as Map<String, dynamic>);
      if (!infoResp.isSuccess) {
        return ToolResult.failure(error: '获取文档失败: ${infoResp.msg}', errorCode: 'API_ERROR');
      }

      // 获取文档内容（所有 blocks）
      final rawContent = await context.http.get(
        '${_config.apiBase}/docx/v1/documents/$documentId/blocks',
        headers: _buildHeaders(),
      );
      final contentResp = LarkApiResponse.fromJson(jsonDecode(rawContent) as Map<String, dynamic>);
      if (!contentResp.isSuccess) {
        return ToolResult.failure(error: '获取文档内容失败: ${contentResp.msg}', errorCode: 'API_ERROR');
      }

      final blocks = contentResp.data?['items'] as List? ?? [];
      final title = infoResp.data?['document']?['title'] as String? ?? '';

      // 将 blocks 转换为文本/markdown
      final textContent = _blocksToText(blocks, format);

      final result = StringBuffer();
      result.writeln('# $title');
      result.writeln();
      result.write(textContent);

      // 获取评论
      if (includeComments) {
        try {
          final rawComments = await context.http.get(
            '${_config.apiBase}/drive/v1/files/$documentId/comments',
            headers: _buildHeaders(),
          );
          final commentsResp = LarkApiResponse.fromJson(jsonDecode(rawComments) as Map<String, dynamic>);
          if (commentsResp.isSuccess) {
            final comments = commentsResp.data?['items'] as List? ?? [];
            if (comments.isNotEmpty) {
              result.writeln();
              result.writeln('## 评论 (${comments.length})');
              for (final comment in comments) {
                final cMap = comment as Map<String, dynamic>;
                result.writeln('- ${cMap['content'] ?? '无内容'}');
              }
            }
          }
        } catch (_) {
          // 评论获取失败不影响主流程
        }
      }

      return ToolResult.success(
        content: result.toString().trim(),
        data: {
          'document_id': documentId,
          'title': title,
          'block_count': blocks.length,
          'format': format,
        },
      );
    } catch (e) {
      context.logger.error('读取文档失败', e);
      return ToolResult.failure(error: '读取文档异常: $e', errorCode: 'READ_DOC_ERROR');
    }
  }

  Future<ToolResult> _executeUpdateDoc(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final documentId = _extractDocumentId(args['document_id'] as String);
    final content = args['content'] as String;
    final mode = args['mode'] as String? ?? 'append';
    final blockId = args['block_id'] as String?;
    final format = args['format'] as String? ?? 'markdown';

    context.logger.info('更新文档: $documentId (模式: $mode)');

    try {
      final blocks = _convertContentToBlocks(content, format);

      String endpoint;
      final body = <String, dynamic>{'children': blocks};

      switch (mode) {
        case 'append':
          endpoint = '${_config.apiBase}/docx/v1/documents/$documentId/blocks/$documentId/children';
          break;
        case 'replace':
          if (blockId == null) {
            return ToolResult.failure(error: 'replace 模式需要 block_id', errorCode: 'MISSING_PARAM');
          }
          endpoint = '${_config.apiBase}/docx/v1/documents/$documentId/blocks/$blockId/children/batch_update';
          body['update_fields'] = blocks;
          break;
        case 'insert_before':
        case 'insert_after':
          if (blockId == null) {
            return ToolResult.failure(error: '$mode 模式需要 block_id', errorCode: 'MISSING_PARAM');
          }
          endpoint = '${_config.apiBase}/docx/v1/documents/$documentId/blocks/$documentId/children';
          body['index'] = mode == 'insert_before' ? 0 : -1;
          break;
        default:
          endpoint = '${_config.apiBase}/docx/v1/documents/$documentId/blocks/$documentId/children';
      }

      await context.http.post(
        endpoint,
        headers: _buildHeaders(),
        body: body,
      );

      return ToolResult.success(
        content: '文档已更新: $documentId (模式: $mode)',
        data: {'document_id': documentId, 'mode': mode, 'block_count': blocks.length},
      );
    } catch (e) {
      context.logger.error('更新文档失败', e);
      return ToolResult.failure(error: '更新文档异常: $e', errorCode: 'UPDATE_DOC_ERROR');
    }
  }

  Future<ToolResult> _executeCreateSheet(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final title = args['title'] as String;
    final spreadsheetToken = args['spreadsheet_token'] as String?;
    final headers = args['headers'] as List?;
    final data = args['data'] as List?;
    final folderToken = args['folder_token'] as String?;

    context.logger.info('创建电子表格: $title');

    try {
      String token;
      String sheetId;

      if (spreadsheetToken != null) {
        // 在已有工作簿中新建 sheet
        token = spreadsheetToken;
        final addResp = await context.http.post(
          '${_config.apiBase}/sheets/v3/spreadsheets/$token/sheets/query',
          headers: _buildHeaders(),
          body: {'title': title},
        );
        final resp = LarkApiResponse.fromJson(jsonDecode(addResp) as Map<String, dynamic>);
        sheetId = resp.data?['sheets']?[0]?['sheet_id'] as String? ?? '';
      } else {
        // 创建新的电子表格
        final createBody = <String, dynamic>{
          'title': title,
          if (folderToken != null) 'folder_token': folderToken,
        };
        final createResp = await context.http.post(
          '${_config.apiBase}/sheets/v3/spreadsheets',
          headers: _buildHeaders(),
          body: createBody,
        );
        final resp = LarkApiResponse.fromJson(jsonDecode(createResp) as Map<String, dynamic>);
        if (!resp.isSuccess) {
          return ToolResult.failure(error: '创建表格失败: ${resp.msg}', errorCode: 'API_ERROR');
        }
        token = resp.data?['spreadsheet']?['spreadsheet_token'] as String? ?? '';
        sheetId = resp.data?['spreadsheet']?['default_sheet_id'] as String? ?? '';
      }

      // 写入表头和初始数据
      if ((headers != null && headers.isNotEmpty) || (data != null && data.isNotEmpty)) {
        final allRows = <List<dynamic>>[];
        if (headers != null && headers.isNotEmpty) {
          allRows.add(headers.cast<dynamic>());
        }
        if (data != null) {
          for (final row in data) {
            allRows.add((row as List).cast<dynamic>());
          }
        }

        final rangeStr = 'A1:${_colLetter(allRows.first.length)}${allRows.length}';
        await context.http.post(
          '${_config.apiBase}/sheets/v2/spreadsheets/$token/values',
          headers: _buildHeaders(),
          body: {
            'valueRange': {
              'range': '$sheetId!$rangeStr',
              'values': allRows,
            },
          },
        );
      }

      final sheetUrl = 'https://xiaoshu.feishu.cn/sheets/$token';

      return ToolResult.success(
        content: '电子表格已创建: $title\nToken: $token\n链接: $sheetUrl',
        data: {'spreadsheet_token': token, 'sheet_id': sheetId, 'title': title, 'url': sheetUrl},
      );
    } catch (e) {
      context.logger.error('创建表格失败', e);
      return ToolResult.failure(error: '创建表格异常: $e', errorCode: 'CREATE_SHEET_ERROR');
    }
  }

  Future<ToolResult> _executeReadSheet(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final token = args['spreadsheet_token'] as String;
    final sheetId = args['sheet_id'] as String?;
    final range = args['range'] as String?;
    final hasHeader = args['has_header'] as bool? ?? true;

    context.logger.info('读取表格: $token');

    try {
      final rangeStr = range != null
          ? (sheetId != null ? '$sheetId!$range' : range)
          : (sheetId != null ? sheetId : '');

      final raw = await context.http.get(
        '${_config.apiBase}/sheets/v2/spreadsheets/$token/values/${Uri.encodeComponent(rangeStr)}',
        headers: _buildHeaders(),
      );
      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '读取表格失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final values = resp.data?['valueRange']?['values'] as List? ?? [];
      if (values.isEmpty) {
        return ToolResult.success(content: '表格数据为空', data: {'row_count': 0});
      }

      final buffer = StringBuffer();
      if (hasHeader && values.isNotEmpty) {
        final headerRow = values.first as List;
        buffer.writeln('| ${headerRow.join(" | ")} |');
        buffer.writeln('| ${headerRow.map((_) => '---').join(" | ")} |');
        for (int i = 1; i < values.length; i++) {
          final row = values[i] as List;
          buffer.writeln('| ${row.join(" | ")} |');
        }
      } else {
        for (final row in values) {
          buffer.writeln('| ${(row as List).join(" | ")} |');
        }
      }

      return ToolResult.success(
        content: buffer.toString().trim(),
        data: {
          'spreadsheet_token': token,
          'row_count': values.length,
          'col_count': values.isNotEmpty ? (values.first as List).length : 0,
        },
      );
    } catch (e) {
      context.logger.error('读取表格失败', e);
      return ToolResult.failure(error: '读取表格异常: $e', errorCode: 'READ_SHEET_ERROR');
    }
  }

  Future<ToolResult> _executeUpdateSheet(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final token = args['spreadsheet_token'] as String;
    final sheetId = args['sheet_id'] as String?;
    final range = args['range'] as String;
    final values = args['values'] as List;

    context.logger.info('更新表格: $token range=$range');

    try {
      final fullRange = sheetId != null ? '$sheetId!$range' : range;

      await context.http.post(
        '${_config.apiBase}/sheets/v2/spreadsheets/$token/values',
        headers: _buildHeaders(),
        body: {
          'valueRange': {
            'range': fullRange,
            'values': values,
          },
        },
      );

      return ToolResult.success(
        content: '表格已更新: $range',
        data: {'spreadsheet_token': token, 'range': range, 'row_count': values.length},
      );
    } catch (e) {
      context.logger.error('更新表格失败', e);
      return ToolResult.failure(error: '更新表格异常: $e', errorCode: 'UPDATE_SHEET_ERROR');
    }
  }

  Future<ToolResult> _executeCreateBitable(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final name = args['name'] as String;
    final fields = args['fields'] as List;
    final records = args['records'] as List?;
    final folderToken = args['folder_token'] as String?;

    context.logger.info('创建多维表格: $name');

    try {
      // 创建多维表格应用
      final createBody = <String, dynamic>{
        'name': name,
        if (folderToken != null) 'folder_token': folderToken,
      };
      final createResp = await context.http.post(
        '${_config.apiBase}/bitable/v1/apps',
        headers: _buildHeaders(),
        body: createBody,
      );
      final resp = LarkApiResponse.fromJson(jsonDecode(createResp) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '创建多维表格失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final appToken = resp.data?['app']?['app_token'] as String? ?? '';
      final defaultTableId = resp.data?['app']?['default_table_id'] as String? ?? '';

      // 配置字段
      for (final field in fields) {
        final fieldMap = field as Map<String, dynamic>;
        await context.http.post(
          '${_config.apiBase}/bitable/v1/apps/$appToken/tables/$defaultTableId/fields',
          headers: _buildHeaders(),
          body: {
            'field_name': fieldMap['name'],
            'type': _mapBitableFieldType(fieldMap['type'] as String? ?? 'text'),
          },
        );
      }

      // 写入初始数据
      if (records != null && records.isNotEmpty) {
        final recordList = records.map((r) => {'fields': r}).toList();
        await context.http.post(
          '${_config.apiBase}/bitable/v1/apps/$appToken/tables/$defaultTableId/records/batch_create',
          headers: _buildHeaders(),
          body: {'records': recordList},
        );
      }

      return ToolResult.success(
        content: '多维表格已创建: $name\nApp Token: $appToken\nTable ID: $defaultTableId',
        data: {
          'app_token': appToken,
          'table_id': defaultTableId,
          'name': name,
          'field_count': fields.length,
          'record_count': records?.length ?? 0,
        },
      );
    } catch (e) {
      context.logger.error('创建多维表格失败', e);
      return ToolResult.failure(error: '创建多维表格异常: $e', errorCode: 'CREATE_BITABLE_ERROR');
    }
  }

  Future<ToolResult> _executeQueryBitable(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final appToken = args['app_token'] as String;
    final tableId = args['table_id'] as String;
    final filter = args['filter'] as String?;
    final sort = args['sort'] as List?;
    final pageSize = args['page_size'] as int? ?? 20;
    final pageToken = args['page_token'] as String?;
    final viewId = args['view_id'] as String?;

    context.logger.info('查询多维表格: $appToken / $tableId');

    try {
      final queryParams = <String, String>{
        'page_size': pageSize.toString(),
        if (pageToken != null) 'page_token': pageToken,
        if (viewId != null) 'view_id': viewId,
      };

      final queryStr = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      final url = '${_config.apiBase}/bitable/v1/apps/$appToken/tables/$tableId/records'
          '${queryStr.isNotEmpty ? "?$queryStr" : ""}';

      final body = <String, dynamic>{};
      if (filter != null) body['filter'] = filter;
      if (sort != null) body['sort'] = sort;

      final raw = filter != null || sort != null
          ? await context.http.post(url, headers: _buildHeaders(), body: body)
          : await context.http.get(url, headers: _buildHeaders());

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '查询失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final items = resp.data?['items'] as List? ?? [];
      final hasMore = resp.data?['has_more'] as bool? ?? false;
      final nextPageToken = resp.data?['page_token'] as String?;

      if (items.isEmpty) {
        return ToolResult.success(content: '未查询到记录', data: {'total': 0, 'has_more': false});
      }

      // 格式化为表格输出
      final records = items.map((r) => BitableRecord.fromJson(r as Map<String, dynamic>)).toList();
      final allFieldNames = <String>{};
      for (final r in records) {
        allFieldNames.addAll(r.fields.keys);
      }
      final fieldList = allFieldNames.toList();

      final buffer = StringBuffer();
      buffer.writeln('| ${fieldList.join(" | ")} |');
      buffer.writeln('| ${fieldList.map((_) => '---').join(" | ")} |');
      for (final r in records) {
        final row = fieldList.map((f) => r.fields[f]?.toString() ?? '').toList();
        buffer.writeln('| ${row.join(" | ")} |');
      }

      return ToolResult.success(
        content: buffer.toString().trim(),
        data: {
          'app_token': appToken,
          'table_id': tableId,
          'record_count': records.length,
          'has_more': hasMore,
          if (nextPageToken != null) 'next_page_token': nextPageToken,
        },
      );
    } catch (e) {
      context.logger.error('查询多维表格失败', e);
      return ToolResult.failure(error: '查询异常: $e', errorCode: 'QUERY_BITABLE_ERROR');
    }
  }

  Future<ToolResult> _executeSendMessage(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final receiveId = args['receive_id'] as String;
    final receiveIdType = args['receive_id_type'] as String? ?? 'open_id';
    final msgType = args['msg_type'] as String? ?? 'text';
    final content = args['content'] as String;
    final replyMessageId = args['reply_message_id'] as String?;

    context.logger.info('发送消息: -> $receiveId ($msgType)');

    try {
      final body = <String, dynamic>{
        'receive_id': receiveId,
        'msg_type': msgType,
        'content': content,
      };

      final endpoint = replyMessageId != null
          ? '${_config.apiBase}/im/v1/messages/$replyMessageId/reply'
          : '${_config.apiBase}/im/v1/messages?receive_id_type=$receiveIdType';

      final raw = await context.http.post(
        endpoint,
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '发送消息失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final messageId = resp.data?['message_id'] as String? ?? '';

      return ToolResult.success(
        content: '消息已发送 -> $receiveId (类型: $msgType)',
        data: {'message_id': messageId, 'receive_id': receiveId, 'msg_type': msgType},
      );
    } catch (e) {
      context.logger.error('发送消息失败', e);
      return ToolResult.failure(error: '发送消息异常: $e', errorCode: 'SEND_MSG_ERROR');
    }
  }

  Future<ToolResult> _executeCreateTask(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final title = args['title'] as String;
    final description = args['description'] as String?;
    final dueDate = args['due_date'] as String?;
    final assigneeIds = args['assignee_ids'] as List?;
    final priority = args['priority'] as String? ?? 'medium';

    context.logger.info('创建任务: $title');

    try {
      final priorityMap = {'none': 0, 'low': 1, 'medium': 2, 'high': 3, 'urgent': 4};
      final body = <String, dynamic>{
        'summary': title,
        if (description != null) 'description': description,
        if (dueDate != null) 'due': {'timestamp': (DateTime.parse(dueDate).millisecondsSinceEpoch ~/ 1000).toString()},
        'priority': priorityMap[priority] ?? 2,
      };

      final raw = await context.http.post(
        '${_config.apiBase}/task/v2/tasks',
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '创建任务失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final taskId = resp.data?['task']?['guid'] as String? ?? '';

      // 添加负责人
      if (assigneeIds != null && assigneeIds.isNotEmpty) {
        for (final uid in assigneeIds) {
          await context.http.post(
            '${_config.apiBase}/task/v2/tasks/$taskId/collaborators',
            headers: _buildHeaders(),
            body: {'collaborator_id': uid},
          );
        }
      }

      return ToolResult.success(
        content: '任务已创建: $title (ID: $taskId)',
        data: {'task_id': taskId, 'title': title, 'priority': priority},
      );
    } catch (e) {
      context.logger.error('创建任务失败', e);
      return ToolResult.failure(error: '创建任务异常: $e', errorCode: 'CREATE_TASK_ERROR');
    }
  }

  Future<ToolResult> _executeCreateCalendarEvent(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final summary = args['summary'] as String;
    final startTime = args['start_time'] as String;
    final endTime = args['end_time'] as String;
    final description = args['description'] as String?;
    final attendeeIds = args['attendee_ids'] as List?;
    final visibility = args['visibility'] as String? ?? 'default';
    final reminders = args['reminders'] as List?;
    final color = args['color'] as int?;

    context.logger.info('创建日程: $summary');

    try {
      final body = <String, dynamic>{
        'summary': summary,
        'start_time': {'timestamp': (DateTime.parse(startTime).millisecondsSinceEpoch ~/ 1000).toString()},
        'end_time': {'timestamp': (DateTime.parse(endTime).millisecondsSinceEpoch ~/ 1000).toString()},
        if (description != null) 'description': description,
        'visibility': visibility,
        if (color != null) 'color': color,
        if (reminders != null)
          'reminders': (reminders).map((m) => {'minutes': m}).toList(),
      };

      final raw = await context.http.post(
        '${_config.apiBase}/calendar/v4/calendars/primary/events',
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '创建日程失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final eventId = resp.data?['event']?['event_id'] as String? ?? '';

      // 添加参与人
      if (attendeeIds != null && attendeeIds.isNotEmpty) {
        await context.http.post(
          '${_config.apiBase}/calendar/v4/calendars/primary/events/$eventId/attendees/batch_create',
          headers: _buildHeaders(),
          body: {
            'attendees': attendeeIds.map((id) => {'type': 'user', 'user_id': id}).toList(),
          },
        );
      }

      return ToolResult.success(
        content: '日程已创建: $summary\n时间: $startTime ~ $endTime\nEvent ID: $eventId',
        data: {
          'event_id': eventId,
          'summary': summary,
          'start_time': startTime,
          'end_time': endTime,
        },
      );
    } catch (e) {
      context.logger.error('创建日程失败', e);
      return ToolResult.failure(error: '创建日程异常: $e', errorCode: 'CREATE_EVENT_ERROR');
    }
  }

  Future<ToolResult> _executeUploadFile(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }

    final filePath = args['file_path'] as String;
    final fileName = args['file_name'] as String?;
    final folderToken = args['folder_token'] as String?;
    final fileType = args['file_type'] as String? ?? 'other';

    context.logger.info('上传文件: $filePath');

    try {
      final name = fileName ?? filePath.split('/').last;

      final raw = await context.http.post(
        '${_config.apiBase}/drive/v1/files/upload_all',
        headers: {
          'Authorization': 'Bearer ${_currentAuth!.token}',
        },
        body: {
          'file_name': name,
          'parent_type': 'explorer',
          if (folderToken != null) 'parent_node': folderToken,
          'size': 0,
          'file': filePath,
        },
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '上传失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final fileToken = resp.data?['file_token'] as String? ?? '';

      return ToolResult.success(
        content: '文件已上传: $name (Token: $fileToken)',
        data: {'file_token': fileToken, 'file_name': name, 'file_type': fileType},
      );
    } catch (e) {
      context.logger.error('上传文件失败', e);
      return ToolResult.failure(error: '上传文件异常: $e', errorCode: 'UPLOAD_ERROR');
    }
  }

  Future<ToolResult> _executeSearchDocs(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final query = args['query'] as String;
    final docTypes = args['doc_types'] as List?;
    final count = args['count'] as int? ?? 10;

    context.logger.info('搜索文档: $query');

    try {
      final body = <String, dynamic>{
        'search_key': query,
        'count': count,
        if (docTypes != null) 'docs_types': docTypes,
      };

      final raw = await context.http.post(
        '${_config.apiBase}/suite/docs-api/search/object/search',
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '搜索失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final docs = resp.data?['docs_entities'] as List? ?? [];
      if (docs.isEmpty) {
        return ToolResult.success(content: '未找到相关文档', data: {'count': 0});
      }

      final buffer = StringBuffer();
      buffer.writeln('找到 ${docs.length} 个相关文档:');
      buffer.writeln();
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i] as Map<String, dynamic>;
        buffer.writeln('**${i + 1}. ${doc['title'] ?? '无标题'}**');
        if (doc['url'] != null) buffer.writeln('   链接: ${doc['url']}');
        if (doc['docs_type'] != null) buffer.writeln('   类型: ${doc['docs_type']}');
        buffer.writeln();
      }

      return ToolResult.success(
        content: buffer.toString().trim(),
        data: {'count': docs.length, 'query': query},
      );
    } catch (e) {
      context.logger.error('搜索文档失败', e);
      return ToolResult.failure(error: '搜索异常: $e', errorCode: 'SEARCH_ERROR');
    }
  }

  Future<ToolResult> _executeCreateWiki(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final spaceId = args['space_id'] as String;
    final title = args['title'] as String;
    final parentNodeToken = args['parent_node_token'] as String?;
    final content = args['content'] as String?;
    final nodeType = args['node_type'] as String? ?? 'doc';

    context.logger.info('创建 Wiki 节点: $title (空间: $spaceId)');

    try {
      final body = <String, dynamic>{
        'obj_type': nodeType,
        'parent_node_token': parentNodeToken,
        'node_type': 'origin',
        'title': title,
      };

      final raw = await context.http.post(
        '${_config.apiBase}/wiki/v2/spaces/$spaceId/nodes',
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '创建 Wiki 节点失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final nodeToken = resp.data?['node']?['node_token'] as String? ?? '';
      final objToken = resp.data?['node']?['obj_token'] as String? ?? '';

      // 如果有内容，写入文档
      if (content != null && content.isNotEmpty && nodeType == 'doc') {
        final blocks = _convertContentToBlocks(content, 'markdown');
        await context.http.post(
          '${_config.apiBase}/docx/v1/documents/$objToken/blocks/$objToken/children',
          headers: _buildHeaders(),
          body: {'children': blocks, 'index': 0},
        );
      }

      return ToolResult.success(
        content: 'Wiki 节点已创建: $title\nNode Token: $nodeToken\nObj Token: $objToken',
        data: {
          'space_id': spaceId,
          'node_token': nodeToken,
          'obj_token': objToken,
          'title': title,
          'node_type': nodeType,
        },
      );
    } catch (e) {
      context.logger.error('创建 Wiki 节点失败', e);
      return ToolResult.failure(error: '创建 Wiki 异常: $e', errorCode: 'CREATE_WIKI_ERROR');
    }
  }

  Future<ToolResult> _executeSendApproval(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    if (!await _ensureAuth(context)) {
      return ToolResult.failure(error: '飞书认证失败', errorCode: 'AUTH_FAILED');
    }
    if (!_checkRateLimit()) {
      return ToolResult.failure(error: 'API 请求频率超限', errorCode: 'RATE_LIMIT');
    }

    final approvalCode = args['approval_code'] as String;
    final formData = args['form_data'] as String;
    final userId = args['user_id'] as String;
    final departmentId = args['department_id'] as String?;

    context.logger.info('发起审批: $approvalCode (用户: $userId)');

    try {
      Map<String, dynamic> formValues;
      try {
        formValues = jsonDecode(formData) as Map<String, dynamic>;
      } catch (_) {
        return ToolResult.failure(error: 'form_data 格式错误，需要合法 JSON', errorCode: 'INVALID_JSON');
      }

      final formList = formValues.entries.map((e) => {
        'id': e.key,
        'type': 'input',
        'value': e.value.toString(),
      }).toList();

      final body = <String, dynamic>{
        'approval_code': approvalCode,
        'user_id': userId,
        if (departmentId != null) 'department_id': departmentId,
        'form': formList,
      };

      final raw = await context.http.post(
        '${_config.apiBase}/approval/v4/instances',
        headers: _buildHeaders(),
        body: body,
      );

      final resp = LarkApiResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!resp.isSuccess) {
        return ToolResult.failure(error: '发起审批失败: ${resp.msg}', errorCode: 'API_ERROR');
      }

      final instanceCode = resp.data?['instance_code'] as String? ?? '';

      return ToolResult.success(
        content: '审批已发起: $approvalCode\nInstance Code: $instanceCode',
        data: {
          'approval_code': approvalCode,
          'instance_code': instanceCode,
          'user_id': userId,
        },
      );
    } catch (e) {
      context.logger.error('发起审批失败', e);
      return ToolResult.failure(error: '发起审批异常: $e', errorCode: 'APPROVAL_ERROR');
    }
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 从 URL 中提取 document_id
  String _extractDocumentId(String input) {
    if (input.startsWith('http')) {
      final uri = Uri.parse(input);
      final segments = uri.pathSegments;
      for (int i = 0; i < segments.length; i++) {
        if (segments[i] == 'docx' && i + 1 < segments.length) {
          return segments[i + 1];
        }
      }
      return segments.last;
    }
    return input;
  }

  /// 将 Markdown 或富文本转换为飞书 Block 结构
  List<Map<String, dynamic>> _convertContentToBlocks(String content, String format) {
    if (format == 'rich_text') {
      try {
        return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
      } catch (_) {
        return [_createTextBlock(content)];
      }
    }

    // 简单的 Markdown 到 Block 转换
    final blocks = <Map<String, dynamic>>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('### ')) {
        blocks.add({'block_type': 4, 'heading3': _textElement(trimmed.substring(4))});
      } else if (trimmed.startsWith('## ')) {
        blocks.add({'block_type': 3, 'heading2': _textElement(trimmed.substring(3))});
      } else if (trimmed.startsWith('# ')) {
        blocks.add({'block_type': 2, 'heading1': _textElement(trimmed.substring(2))});
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add({'block_type': 15, 'bullet': _textElement(trimmed.substring(2))});
      } else if (trimmed.startsWith('> ')) {
        blocks.add({'block_type': 27, 'quote': _textElement(trimmed.substring(2))});
      } else if (trimmed.startsWith('```')) {
        // 代码块标记，跳过
        continue;
      } else {
        blocks.add(_createTextBlock(trimmed));
      }
    }

    if (blocks.isEmpty) {
      blocks.add(_createTextBlock(content));
    }

    return blocks;
  }

  Map<String, dynamic> _createTextBlock(String text) {
    return {
      'block_type': 1,
      'text': _textElement(text),
    };
  }

  Map<String, dynamic> _textElement(String text) {
    return {
      'elements': [
        {
          'text_run': {
            'content': text,
          },
        },
      ],
    };
  }

  /// 将 blocks 转换为文本
  String _blocksToText(List<dynamic> blocks, String format) {
    final buffer = StringBuffer();

    for (final block in blocks) {
      final b = block as Map<String, dynamic>;
      final blockType = b['block_type'] as int? ?? 0;

      switch (blockType) {
        case 1: // text
          final text = _extractBlockText(b['text']);
          buffer.writeln(text);
        case 2: // heading1
          final text = _extractBlockText(b['heading1']);
          buffer.writeln('# $text');
        case 3: // heading2
          final text = _extractBlockText(b['heading2']);
          buffer.writeln('## $text');
        case 4: // heading3
          final text = _extractBlockText(b['heading3']);
          buffer.writeln('### $text');
        case 15: // bullet
          final text = _extractBlockText(b['bullet']);
          buffer.writeln('- $text');
        case 16: // ordered
          final text = _extractBlockText(b['ordered']);
          buffer.writeln('1. $text');
        case 27: // quote
          final text = _extractBlockText(b['quote']);
          buffer.writeln('> $text');
        default:
          // 尝试提取其他类型的文本
          for (final key in b.keys) {
            if (b[key] is Map<String, dynamic>) {
              final text = _extractBlockText(b[key] as Map<String, dynamic>);
              if (text.isNotEmpty) {
                buffer.writeln(text);
                break;
              }
            }
          }
      }
    }

    return buffer.toString();
  }

  String _extractBlockText(Map<String, dynamic>? blockData) {
    if (blockData == null) return '';
    final elements = blockData['elements'] as List? ?? [];
    return elements.map((e) {
      final el = e as Map<String, dynamic>;
      return el['text_run']?['content'] as String? ?? '';
    }).join();
  }

  /// 列号转字母 (1->A, 26->Z, 27->AA)
  String _colLetter(int col) {
    final buffer = StringBuffer();
    while (col > 0) {
      col--;
      buffer.writeCharCode(65 + (col % 26));
      col ~/= 26;
    }
    return buffer.toString();
  }

  /// 映射多维表格字段类型
  int _mapBitableFieldType(String type) {
    return switch (type) {
      'text' => 1,
      'number' => 2,
      'select' => 3,
      'multi_select' => 4,
      'date' => 5,
      'checkbox' => 7,
      'person' => 11,
      'url' => 15,
      'attachment' => 17,
      'link' => 20,
      'created_time' => 1001,
      'modified_time' => 1002,
      _ => 1,
    };
  }
}

// ============================================================================
// 配置
// ============================================================================

/// 飞书技能配置
class LarkSkillConfig {
  /// API 基础 URL
  final String apiBase;

  /// 默认应用 App ID
  final String defaultAppId;

  /// 默认应用 App Secret
  final String defaultAppSecret;

  /// Token 自动刷新间隔（秒）
  final int tokenRefreshIntervalSec;

  /// 请求重试次数
  final int maxRetries;

  /// 请求超时（毫秒）
  final int requestTimeoutMs;

  const LarkSkillConfig({
    this.apiBase = 'https://open.feishu.cn/open-apis',
    this.defaultAppId = '',
    this.defaultAppSecret = '',
    this.tokenRefreshIntervalSec = 6000,
    this.maxRetries = 3,
    this.requestTimeoutMs = 30000,
  });
}

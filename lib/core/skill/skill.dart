// ============================================================================
// 小酥 AI 助手 - 技能抽象接口
// ============================================================================
// 定义技能系统的基础抽象类和接口
// 所有技能必须实现 Skill 基类，遵循统一的生命周期和工具调用规范
// ============================================================================

import 'dart:async';

// ============================================================================
// 技能状态枚举
// ============================================================================

/// 技能运行状态
enum SkillStatus {
  /// 未初始化
  uninitialized('uninitialized'),

  /// 初始化中
  initializing('initializing'),

  /// 就绪（可用）
  ready('ready'),

  /// 运行中（正在执行工具）
  running('running'),

  /// 已暂停
  paused('paused'),

  /// 错误状态
  error('error'),

  /// 已销毁
  disposed('disposed');

  final String value;
  const SkillStatus(this.value);

  /// 是否可以执行工具
  bool get canExecute => this == SkillStatus.ready;

  /// 是否处于活跃状态
  bool get isActive =>
      this == SkillStatus.ready || this == SkillStatus.running;
}

// ============================================================================
// 技能权限模型
// ============================================================================

/// 技能权限类型
/// 控制技能可以访问的系统资源
enum SkillPermission {
  /// 网络访问权限
  networkAccess('network_access'),

  /// 文件系统读取权限
  fileRead('file_read'),

  /// 文件系统写入权限
  fileWrite('file_write'),

  /// 剪贴板访问权限
  clipboardAccess('clipboard_access'),

  /// 通知发送权限
  sendNotification('send_notification'),

  /// 本地存储权限
  localStorage('local_storage'),

  /// 代码执行权限（沙箱）
  codeExecution('code_execution'),

  /// 系统设置读取权限
  systemSettingsRead('system_settings_read'),

  /// 支付权限（需要用户确认）
  paymentAccess('payment_access'),

  /// 摄像头/麦克风权限
  mediaAccess('media_access');

  final String value;
  const SkillPermission(this.value);

  /// 获取权限的中文描述
  String get displayName {
    return switch (this) {
      SkillPermission.networkAccess => '网络访问',
      SkillPermission.fileRead => '文件读取',
      SkillPermission.fileWrite => '文件写入',
      SkillPermission.clipboardAccess => '剪贴板访问',
      SkillPermission.sendNotification => '发送通知',
      SkillPermission.localStorage => '本地存储',
      SkillPermission.codeExecution => '代码执行',
      SkillPermission.systemSettingsRead => '系统设置读取',
      SkillPermission.paymentAccess => '支付',
      SkillPermission.mediaAccess => '摄像头/麦克风',
    };
  }
}

// ============================================================================
// 技能工具定义
// ============================================================================

/// 工具参数类型
enum ToolParameterType {
  stringType('string'),
  intType('integer'),
  doubleType('number'),
  boolType('boolean'),
  arrayType('array'),
  objectType('object');

  final String value;
  const ToolParameterType(this.value);
}

/// 工具参数定义
class ToolParameter {
  /// 参数名称
  final String name;

  /// 参数描述
  final String description;

  /// 参数类型
  final ToolParameterType type;

  /// 是否必填
  final bool required;

  /// 默认值
  final dynamic defaultValue;

  /// 枚举值列表（如果参数有固定选项）
  final List<String>? enumValues;

  /// 最小值（数字类型）
  final num? minValue;

  /// 最大值（数字类型）
  final num? maxValue;

  const ToolParameter({
    required this.name,
    required this.description,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.enumValues,
    this.minValue,
    this.maxValue,
  });

  /// 转换为 JSON Schema 格式（用于 LLM 工具描述）
  Map<String, dynamic> toJsonSchema() {
    final schema = <String, dynamic>{
      'type': type.value,
      'description': description,
    };

    if (enumValues != null) schema['enum'] = enumValues;
    if (minValue != null) schema['minimum'] = minValue;
    if (maxValue != null) schema['maximum'] = maxValue;
    if (defaultValue != null) schema['default'] = defaultValue;

    return schema;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'type': type.value,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
        if (enumValues != null) 'enum': enumValues,
      };
}

/// 工具定义
/// 描述技能提供的每个工具的名称、参数和执行逻辑
class SkillTool {
  /// 工具名称（全局唯一）
  final String name;

  /// 工具描述（用于 LLM 理解工具用途）
  final String description;

  /// 工具参数列表
  final List<ToolParameter> parameters;

  /// 是否异步执行
  final bool isAsync;

  /// 超时时间（毫秒）
  final int timeoutMs;

  /// 工具执行函数
  final Future<ToolResult> Function(Map<String, dynamic> args, SkillContext context) execute;

  const SkillTool({
    required this.name,
    required this.description,
    required this.parameters,
    this.isAsync = false,
    this.timeoutMs = 30000,
    required this.execute,
  });

  /// 生成 JSON Schema 格式的工具描述（用于 LLM）
  Map<String, dynamic> toFunctionDef() {
    final properties = <String, dynamic>{};
    final requiredParams = <String>[];

    for (final param in parameters) {
      properties[param.name] = param.toJsonSchema();
      if (param.required) requiredParams.add(param.name);
    }

    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (requiredParams.isNotEmpty) 'required': requiredParams,
        },
      },
    };
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'is_async': isAsync,
        'timeout_ms': timeoutMs,
      };
}

// ============================================================================
// 工具执行结果
// ============================================================================

/// 工具执行结果
class ToolResult {
  /// 是否成功
  final bool success;

  /// 结果内容（成功时）
  final String? content;

  /// 错误信息（失败时）
  final String? error;

  /// 错误码
  final String? errorCode;

  /// 结构化数据（可选）
  final Map<String, dynamic>? data;

  /// 执行耗时（毫秒）
  final int durationMs;

  /// 附件列表（如生成的图片、文件等）
  final List<ToolAttachment>? attachments;

  const ToolResult({
    required this.success,
    this.content,
    this.error,
    this.errorCode,
    this.data,
    this.durationMs = 0,
    this.attachments,
  });

  /// 创建成功结果
  factory ToolResult.success({
    required String content,
    Map<String, dynamic>? data,
    int durationMs = 0,
    List<ToolAttachment>? attachments,
  }) {
    return ToolResult(
      success: true,
      content: content,
      data: data,
      durationMs: durationMs,
      attachments: attachments,
    );
  }

  /// 创建失败结果
  factory ToolResult.failure({
    required String error,
    String? errorCode,
    int durationMs = 0,
  }) {
    return ToolResult(
      success: false,
      error: error,
      errorCode: errorCode,
      durationMs: durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (content != null) 'content': content,
        if (error != null) 'error': error,
        if (errorCode != null) 'error_code': errorCode,
        if (data != null) 'data': data,
        'duration_ms': durationMs,
        if (attachments != null)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
      };
}

/// 工具附件
class ToolAttachment {
  /// 附件类型
  final AttachmentType type;

  /// 附件 URL 或文件路径
  final String uri;

  /// 附件描述
  final String? description;

  /// 文件大小（字节）
  final int? size;

  /// MIME 类型
  final String? mimeType;

  const ToolAttachment({
    required this.type,
    required this.uri,
    this.description,
    this.size,
    this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'uri': uri,
        if (description != null) 'description': description,
        if (size != null) 'size': size,
        if (mimeType != null) 'mime_type': mimeType,
      };
}

/// 附件类型
enum AttachmentType {
  image('image'),
  file('file'),
  audio('audio'),
  video('video'),
  code('code');

  final String value;
  const AttachmentType(this.value);
}

// ============================================================================
// 技能上下文
// ============================================================================

/// 技能执行上下文
/// 提供技能执行时需要的各种服务
class SkillContext {
  /// 技能专属存储（KV 键值对）
  final SkillStorage storage;

  /// HTTP 客户端
  final SkillHttpClient http;

  /// 日志器
  final SkillLogger logger;

  /// 当前会话 ID
  final int? sessionId;

  /// 当前用户 ID
  final String? userId;

  /// 取消令牌（用于取消长时间运行的任务）
  final CancelToken? cancelToken;

  /// 进度回调
  final void Function(double progress, String message)? onProgress;

  const SkillContext({
    required this.storage,
    required this.http,
    required this.logger,
    this.sessionId,
    this.userId,
    this.cancelToken,
    this.onProgress,
  });
}

/// 技能存储接口
/// 提供技能专属的 KV 存储
abstract class SkillStorage {
  /// 获取值
  Future<String?> get(String key);

  /// 设置值
  Future<void> set(String key, String value);

  /// 删除值
  Future<void> remove(String key);

  /// 获取所有键
  Future<List<String>> keys();

  /// 清空存储
  Future<void> clear();
}

/// HTTP 客户端接口
abstract class SkillHttpClient {
  /// GET 请求
  Future<String> get(String url, {Map<String, String>? headers});

  /// POST 请求
  Future<String> post(String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  });

  /// 下载文件
  Future<String> download(String url, String savePath, {
    Map<String, String>? headers,
  });
}

/// 技能日志器
class SkillLogger {
  /// 技能名称（日志前缀）
  final String skillName;

  const SkillLogger(this.skillName);

  void info(String message) {
    // TODO: 集成真实日志系统
    print('[INFO] [$skillName] $message');
  }

  void warning(String message) {
    print('[WARN] [$skillName] $message');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] [$skillName] $message: $error');
  }

  void debug(String message) {
    // TODO: 根据日志级别控制输出
    print('[DEBUG] [$skillName] $message');
  }
}

/// 取消令牌
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw SkillCancelledException('任务已被取消');
    }
  }
}

/// 技能被取消异常
class SkillCancelledException implements Exception {
  final String message;
  const SkillCancelledException(this.message);

  @override
  String toString() => 'SkillCancelledException: $message';
}

// ============================================================================
// 技能清单
// ============================================================================

/// 技能清单（元数据）
/// 描述技能的基本信息、能力和加载策略
class SkillManifest {
  /// 技能唯一标识
  final String id;

  /// 技能名称
  final String name;

  /// 技能描述
  final String description;

  /// 技能版本
  final String version;

  /// 作者
  final String? author;

  /// 技能图标 URL
  final String? iconUrl;

  /// 所需权限列表
  final List<SkillPermission> permissions;

  /// 加载策略
  final SkillLoadStrategy loadStrategy;

  /// 加载优先级（数字越小优先级越高）
  final int priority;

  /// 依赖的其他技能 ID 列表
  final List<String> dependencies;

  /// 支持的运行平台
  final List<String> platforms;

  /// 配置模式（JSON Schema 格式）
  final Map<String, dynamic>? configSchema;

  const SkillManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    this.author,
    this.iconUrl,
    this.permissions = const [],
    this.loadStrategy = SkillLoadStrategy.lazy,
    this.priority = 100,
    this.dependencies = const [],
    this.platforms = const ['android', 'ios', 'web'],
    this.configSchema,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        if (author != null) 'author': author,
        if (iconUrl != null) 'icon_url': iconUrl,
        'permissions': permissions.map((p) => p.value).toList(),
        'load_strategy': loadStrategy.value,
        'priority': priority,
        'dependencies': dependencies,
        'platforms': platforms,
        if (configSchema != null) 'config_schema': configSchema,
      };
}

/// 技能加载策略
enum SkillLoadStrategy {
  /// 应用启动时立即加载
  eager('eager'),

  /// 首次使用时懒加载
  lazy('lazy'),

  /// 后台异步加载
  background('background');

  final String value;
  const SkillLoadStrategy(this.value);
}

// ============================================================================
// 技能基类
// ============================================================================

/// 技能基类
/// 所有技能必须继承此抽象类
abstract class Skill {
  /// 技能清单
  SkillManifest get manifest;

  /// 技能提供的工具列表
  List<SkillTool> get tools;

  /// 当前状态
  SkillStatus _status = SkillStatus.uninitialized;
  SkillStatus get status => _status;

  /// 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 初始化技能
  /// 在技能首次使用前调用，用于加载资源、建立连接等
  ///
  /// [context] 技能上下文
  Future<void> initialize(SkillContext context) async {
    _status = SkillStatus.initializing;
    try {
      await onInitialize(context);
      _status = SkillStatus.ready;
    } catch (e) {
      _status = SkillStatus.error;
      _errorMessage = e.toString();
      rethrow;
    }
  }

  /// 子类实现的初始化逻辑
  Future<void> onInitialize(SkillContext context);

  /// 销毁技能
  /// 在技能被卸载或应用关闭时调用，用于释放资源
  Future<void> dispose() async {
    _status = SkillStatus.disposed;
    await onDispose();
  }

  /// 子类实现的销毁逻辑
  Future<void> onDispose();

  /// 执行工具
  /// 根据工具名称路由到对应的执行函数
  ///
  /// [toolName] 工具名称
  /// [arguments] 工具参数
  /// [context] 技能上下文
  Future<ToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments,
    SkillContext context,
  ) async {
    // 检查状态
    if (!_status.canExecute) {
      return ToolResult.failure(
        error: '技能当前状态不可执行: $_status',
        errorCode: 'SKILL_NOT_READY',
      );
    }

    // 查找工具
    final tool = tools.where((t) => t.name == toolName).firstOrNull;
    if (tool == null) {
      return ToolResult.failure(
        error: '未找到工具: $toolName',
        errorCode: 'TOOL_NOT_FOUND',
      );
    }

    // 验证必填参数
    for (final param in tool.parameters) {
      if (param.required && !arguments.containsKey(param.name)) {
        return ToolResult.failure(
          error: '缺少必填参数: ${param.name}',
          errorCode: 'MISSING_PARAMETER',
        );
      }
    }

    // 执行工具
    _status = SkillStatus.running;
    final stopwatch = Stopwatch()..start();

    try {
      // 检查是否已取消
      context.cancelToken?.throwIfCancelled();

      // 带超时的工具执行
      final result = await tool.execute(arguments, context)
          .timeout(Duration(milliseconds: tool.timeoutMs));

      stopwatch.stop();
      _status = SkillStatus.ready;

      return ToolResult(
        success: result.success,
        content: result.content,
        error: result.error,
        errorCode: result.errorCode,
        data: result.data,
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: result.attachments,
      );
    } on TimeoutException {
      stopwatch.stop();
      _status = SkillStatus.ready;
      return ToolResult.failure(
        error: '工具执行超时 (${tool.timeoutMs}ms)',
        errorCode: 'TOOL_TIMEOUT',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on SkillCancelledException {
      stopwatch.stop();
      _status = SkillStatus.ready;
      return ToolResult.failure(
        error: '工具执行被取消',
        errorCode: 'TOOL_CANCELLED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      _status = SkillStatus.error;
      _errorMessage = e.toString();
      return ToolResult.failure(
        error: '工具执行异常: $e',
        errorCode: 'TOOL_ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 获取技能的摘要信息
  Map<String, dynamic> toSummary() => {
        'id': manifest.id,
        'name': manifest.name,
        'description': manifest.description,
        'version': manifest.version,
        'status': _status.value,
        'tools': tools.map((t) => t.toJson()).toList(),
      };

  @override
  String toString() => 'Skill(${manifest.name} v${manifest.version}, '
      'status: $_status, tools: ${tools.length})';
}

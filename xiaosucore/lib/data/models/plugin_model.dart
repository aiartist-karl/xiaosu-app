// ============================================================================
// 小酥 v2 - 插件数据模型
// Phase 5: 插件系统对接 Coze Studio 插件 API
// ============================================================================

/// 插件来源类型
enum PluginSourceType {
  builtIn,   // 本地内置插件
  coze,      // Coze Studio 插件
  custom,    // 自定义插件
}

/// 插件执行参数校验规则
class PluginParamRule {
  final String name;
  final String type; // string / number / boolean / object / array
  final bool required;
  final String? description;
  final dynamic defaultValue;
  final List<dynamic>? enumValues;
  final Map<String, dynamic>? schema; // JSON Schema for complex types

  const PluginParamRule({
    required this.name,
    this.type = 'string',
    this.required = false,
    this.description,
    this.defaultValue,
    this.enumValues,
    this.schema,
  });

  factory PluginParamRule.fromJson(Map<String, dynamic> json) {
    return PluginParamRule(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'string',
      required: json['required'] == true || json['is_required'] == true,
      description: json['description']?.toString(),
      defaultValue: json['default'] ?? json['default_value'],
      enumValues: json['enum'] is List ? json['enum'] as List : null,
      schema: json['schema'] is Map<String, dynamic>
          ? json['schema'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'required': required,
    if (description != null) 'description': description,
    if (defaultValue != null) 'default': defaultValue,
    if (enumValues != null) 'enum': enumValues,
    if (schema != null) 'schema': schema,
  };

  /// 校验单个参数值
  PluginParamValidationError? validate(dynamic value) {
    // 必填检查
    if (required && (value == null || (value is String && value.isEmpty))) {
      return PluginParamValidationError(
        paramName: name,
        message: '参数 "$name" 为必填项',
      );
    }

    // 值不存在则跳过后续校验
    if (value == null) return null;

    // 类型检查
    switch (type) {
      case 'string':
        if (value is! String) {
          return PluginParamValidationError(
            paramName: name,
            message: '参数 "$name" 应为字符串类型',
          );
        }
        break;
      case 'number':
      case 'integer':
        if (value is! num) {
          return PluginParamValidationError(
            paramName: name,
            message: '参数 "$name" 应为数字类型',
          );
        }
        break;
      case 'boolean':
        if (value is! bool) {
          return PluginParamValidationError(
            paramName: name,
            message: '参数 "$name" 应为布尔类型',
          );
        }
        break;
      case 'array':
        if (value is! List) {
          return PluginParamValidationError(
            paramName: name,
            message: '参数 "$name" 应为数组类型',
          );
        }
        break;
      case 'object':
        if (value is! Map) {
          return PluginParamValidationError(
            paramName: name,
            message: '参数 "$name" 应为对象类型',
          );
        }
        break;
    }

    // 枚举值检查
    if (enumValues != null && !enumValues!.contains(value)) {
      return PluginParamValidationError(
        paramName: name,
        message: '参数 "$name" 的值不在允许范围内: $enumValues',
      );
    }

    return null;
  }
}

/// 参数校验错误
class PluginParamValidationError {
  final String paramName;
  final String message;

  const PluginParamValidationError({
    required this.paramName,
    required this.message,
  });
}

/// 插件工具 - 插件下的具体能力单元
class PluginTool {
  final String id;
  final String name;
  final String description;
  final List<PluginParamRule> parameters;
  final Map<String, dynamic>? inputSchema; // 完整 JSON Schema
  final Map<String, dynamic>? outputSchema;

  const PluginTool({
    required this.id,
    required this.name,
    this.description = '',
    this.parameters = const [],
    this.inputSchema,
    this.outputSchema,
  });

  /// 从 Coze Studio 内部 API 响应创建
  factory PluginTool.fromCozeApi(Map<String, dynamic> json) {
    final params = <PluginParamRule>[];
    final properties = json['parameters'];
    if (properties is Map<String, dynamic>) {
      // OpenAPI style: { "properties": { "key": { "type": "string", ... } }, "required": [...] }
      final props = properties['properties'] as Map<String, dynamic>? ?? properties;
      final requiredList = properties['required'] is List
          ? (properties['required'] as List).map((e) => e.toString()).toSet()
          : <String>{};

      props.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          params.add(PluginParamRule(
            name: key,
            type: value['type']?.toString() ?? 'string',
            required: requiredList.contains(key),
            description: value['description']?.toString(),
            defaultValue: value['default'],
            enumValues: value['enum'] is List ? value['enum'] as List : null,
            schema: value,
          ));
        }
      });
    } else if (properties is List) {
      // Coze 列表风格: [{ "name": "key", "type": "string", ... }]
      for (final p in properties) {
        if (p is Map<String, dynamic>) {
          params.add(PluginParamRule.fromJson(p));
        }
      }
    }

    return PluginTool(
      id: json['tool_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      parameters: params,
      inputSchema: json['input_schema'] is Map<String, dynamic>
          ? json['input_schema'] as Map<String, dynamic>
          : json['parameters'] is Map<String, dynamic>
              ? json['parameters'] as Map<String, dynamic>
              : null,
      outputSchema: json['output_schema'] is Map<String, dynamic>
          ? json['output_schema'] as Map<String, dynamic>
          : null,
    );
  }

  /// 校验调用参数
  List<PluginParamValidationError> validateParams(Map<String, dynamic> params) {
    final errors = <PluginParamValidationError>[];
    for (final rule in parameters) {
      final error = rule.validate(params[rule.name]);
      if (error != null) {
        errors.add(error);
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    if (parameters.isNotEmpty)
      'parameters': parameters.map((p) => p.toJson()).toList(),
    if (inputSchema != null) 'input_schema': inputSchema,
    if (outputSchema != null) 'output_schema': outputSchema,
  };
}

/// Coze Studio 插件模型
class PluginModel {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final String version;
  final String author;
  final String category;
  final PluginSourceType sourceType;
  final List<PluginTool> tools;
  final bool isInstalled;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int callCount;
  final Map<String, dynamic>? extra;

  const PluginModel({
    required this.id,
    required this.name,
    this.description = '',
    this.iconUrl,
    this.version = '1.0.0',
    this.author = '',
    this.category = '通用',
    this.sourceType = PluginSourceType.coze,
    this.tools = const [],
    this.isInstalled = false,
    this.isPublished = false,
    this.createdAt,
    this.updatedAt,
    this.callCount = 0,
    this.extra,
  });

  /// 从 Coze Studio 内部插件 API 响应创建
  factory PluginModel.fromCozeApi(Map<String, dynamic> json) {
    final tools = <PluginTool>[];
    final toolList = json['tool_list'] ?? json['tools'];
    if (toolList is List) {
      for (final t in toolList) {
        if (t is Map<String, dynamic>) {
          tools.add(PluginTool.fromCozeApi(t));
        }
      }
    }

    return PluginModel(
      id: json['plugin_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUrl: json['icon_url']?.toString() ?? json['icon']?.toString(),
      version: json['version']?.toString() ?? '1.0.0',
      author: json['author']?.toString() ?? json['author_name']?.toString() ?? '',
      category: json['category']?.toString() ?? json['category_name']?.toString() ?? '通用',
      sourceType: json['is_custom'] == true || json['source'] == 'custom'
          ? PluginSourceType.custom
          : PluginSourceType.coze,
      tools: tools,
      isInstalled: json['is_installed'] == true || json['installed'] == true,
      isPublished: json['publish_status'] == 1 || json['is_published'] == true,
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      callCount: json['call_count'] is int ? json['call_count'] as int : 0,
      extra: json,
    );
  }

  /// 从插件市场 service 响应创建
  factory PluginModel.fromMarketplace(Map<String, dynamic> json) {
    final tools = <PluginTool>[];
    final toolList = json['tool_list'] ?? json['tools'];
    if (toolList is List) {
      for (final t in toolList) {
        if (t is Map<String, dynamic>) {
          tools.add(PluginTool.fromCozeApi(t));
        }
      }
    }

    return PluginModel(
      id: json['plugin_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUrl: json['icon_url']?.toString() ?? json['icon']?.toString(),
      version: json['version']?.toString() ?? json['latest_version']?.toString() ?? '1.0.0',
      author: json['author']?.toString() ?? json['author_name']?.toString() ?? '',
      category: json['category']?.toString() ?? json['category_name']?.toString() ?? '通用',
      sourceType: PluginSourceType.coze,
      tools: tools,
      isPublished: json['status'] == 'published' || json['is_published'] == true,
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
    );
  }

  /// 转为创建插件请求体
  Map<String, dynamic> toCreateBody({required String spaceId}) => {
    'space_id': spaceId,
    'name': name,
    'description': description,
    if (iconUrl != null) 'icon_url': iconUrl,
    if (category.isNotEmpty) 'category': category,
  };

  /// 获取指定名称的工具
  PluginTool? findTool(String toolName) {
    try {
      return tools.firstWhere(
        (t) => t.name == toolName || t.id == toolName,
      );
    } catch (_) {
      return null;
    }
  }

  /// 校验并获取工具调用参数
  PluginInvokeResult prepareInvoke(String toolName, Map<String, dynamic> params) {
    final tool = findTool(toolName);
    if (tool == null) {
      return PluginInvokeResult.error('工具 "$toolName" 不存在于插件 "$name" 中');
    }

    final errors = tool.validateParams(params);
    if (errors.isNotEmpty) {
      final messages = errors.map((e) => e.message).join('; ');
      return PluginInvokeResult.error('参数校验失败: $messages');
    }

    return PluginInvokeResult.ready(
      pluginId: id,
      toolName: tool.name,
      params: params,
    );
  }

  PluginModel copyWith({
    String? name,
    String? description,
    String? iconUrl,
    List<PluginTool>? tools,
    bool? isInstalled,
    bool? isPublished,
  }) => PluginModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconUrl: iconUrl ?? this.iconUrl,
    version: version,
    author: author,
    category: category,
    sourceType: sourceType,
    tools: tools ?? this.tools,
    isInstalled: isInstalled ?? this.isInstalled,
    isPublished: isPublished ?? this.isPublished,
    createdAt: createdAt,
    updatedAt: updatedAt,
    callCount: callCount,
    extra: extra,
  );

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return value > 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  String toString() => 'PluginModel(id: $id, name: $name, tools: ${tools.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 插件调用结果
class PluginInvokeResult {
  final bool isSuccess;
  final bool isReady;
  final String? error;
  final String? pluginId;
  final String? toolName;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? result;

  const PluginInvokeResult._({
    required this.isSuccess,
    this.isReady = false,
    this.error,
    this.pluginId,
    this.toolName,
    this.params,
    this.result,
  });

  factory PluginInvokeResult.ready({
    required String pluginId,
    required String toolName,
    required Map<String, dynamic> params,
  }) => PluginInvokeResult._(
    isSuccess: true,
    isReady: true,
    pluginId: pluginId,
    toolName: toolName,
    params: params,
  );

  factory PluginInvokeResult.success(Map<String, dynamic> result) =>
    PluginInvokeResult._(isSuccess: true, result: result);

  factory PluginInvokeResult.error(String error) =>
    PluginInvokeResult._(isSuccess: false, error: error);
}

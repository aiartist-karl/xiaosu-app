// ============================================================================
// 小酥 (XiaoSu) - 技能注册表（SkillRegistry）
//
// 职责：
// 1. 注册所有可用技能（Function Calling 工具）
// 2. 提供技能查询接口（供 ChatEngine 获取可用工具列表）
// 3. 提供技能处理器（供 ChatEngine 执行技能调用）
// 4. 管理内置技能与用户自定义技能
// ============================================================================

import 'dart:async';

import 'package:logger/logger.dart';

import 'package:xiaosu_core/main.dart' show appLogger;
import 'package:xiaosu_core/models/skill_definition.dart';

/// ============================================================================
/// 技能注册表 —— 管理所有 Function Calling 工具
/// ============================================================================
class SkillRegistry {
  SkillRegistry._internal();
  static final SkillRegistry instance = SkillRegistry._internal();

  /// ─── 日志器 ─────────────────────────────────────────────────
  final Logger _logger = appLogger;

  /// ─── 技能定义存储（name → SkillDefinition）────────────────
  final Map<String, SkillDefinition> _definitions = {};

  /// ─── 技能处理器存储（name → SkillHandler）─────────────────
  final Map<String, SkillHandler> _handlers = {};

  /// ─── 已注册技能数量 ─────────────────────────────────────────
  int get skillCount => _definitions.length;

  // ==========================================================================
  // 注册技能
  // ==========================================================================

  /// 注册内置技能
  void registerBuiltinSkills() {
    // ─── 网络搜索 ───────────────────────────────────────────
    _register(
      definition: const SkillDefinition(
        name: 'web_search',
        displayName: '网络搜索',
        description: '搜索互联网获取最新信息。当用户询问最新新闻、实时数据、产品信息等需要联网查询的内容时使用。',
        parameters: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '搜索关键词',
            },
            'max_results': {
              'type': 'integer',
              'description': '最大返回结果数',
              'default': 5,
            },
          },
          'required': ['query'],
        },
        category: '信息获取',
      ),
      handler: _WebSearchHandler(),
    );

    // ─── 计算器 ─────────────────────────────────────────────
    _register(
      definition: const SkillDefinition(
        name: 'calculator',
        displayName: '计算器',
        description: '执行数学计算。当用户提出需要精确计算的问题时使用，支持四则运算、幂运算、三角函数等。',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': '数学表达式，如 "2 + 3 * 4" 或 "sin(30)"',
            },
          },
          'required': ['expression'],
        },
        category: '工具',
      ),
      handler: _CalculatorHandler(),
    );

    // ─── 天气查询 ───────────────────────────────────────────
    _register(
      definition: const SkillDefinition(
        name: 'get_weather',
        displayName: '天气查询',
        description: '查询指定城市的天气信息。当用户询问天气、气温、是否下雨等问题时使用。',
        parameters: {
          'type': 'object',
          'properties': {
            'city': {
              'type': 'string',
              'description': '城市名称，如 "北京"、"上海"',
            },
          },
          'required': ['city'],
        },
        category: '生活服务',
      ),
      handler: _WeatherHandler(),
    );

    // ─── 日程提醒 ───────────────────────────────────────────
    _register(
      definition: const SkillDefinition(
        name: 'create_reminder',
        displayName: '创建提醒',
        description: '创建定时提醒。当用户要求"X点后提醒我"、"明天早上通知我"时使用。',
        parameters: {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': '提醒标题',
            },
            'time': {
              'type': 'string',
              'description': '提醒时间，ISO 8601 格式',
            },
            'message': {
              'type': 'string',
              'description': '提醒内容',
            },
          },
          'required': ['title', 'time'],
        },
        category: '效率工具',
        requiresConfirmation: false,
      ),
      handler: _ReminderHandler(),
    );

    _logger.i('🛠️ 已注册 ${_definitions.length} 个内置技能');
  }

  /// 注册单个技能
  void register({
    required SkillDefinition definition,
    required SkillHandler handler,
  }) {
    _register(definition: definition, handler: handler);
  }

  /// 内部注册方法
  void _register({
    required SkillDefinition definition,
    required SkillHandler handler,
  }) {
    _definitions[definition.name] = definition;
    _handlers[definition.name] = handler;
    _logger.d('📝 注册技能: ${definition.name} (${definition.displayName})');
  }

  // ==========================================================================
  // 查询技能
  // ==========================================================================

  /// 获取所有已注册技能定义
  List<SkillDefinition> getAllSkills() {
    return _definitions.values.toList();
  }

  /// 获取 OpenAI Function Calling 工具定义列表
  List<Map<String, dynamic>> getToolDefinitions() {
    return _definitions.values.map((d) => d.toToolDefinition()).toList();
  }

  /// 获取指定名称的技能处理器
  SkillHandler? getHandler(String skillName) {
    return _handlers[skillName];
  }

  /// 获取指定名称的技能定义
  SkillDefinition? getDefinition(String skillName) {
    return _definitions[skillName];
  }

  /// 检查技能是否存在
  bool hasSkill(String skillName) {
    return _definitions.containsKey(skillName);
  }

  /// 按分类获取技能
  List<SkillDefinition> getSkillsByCategory(String category) {
    return _definitions.values
        .where((d) => d.category == category)
        .toList();
  }

  // ==========================================================================
  // 移除技能
  // ==========================================================================

  /// 移除技能
  void removeSkill(String skillName) {
    _definitions.remove(skillName);
    _handlers.remove(skillName);
    _logger.d('🗑️ 移除技能: $skillName');
  }
}

// ============================================================================
/// 技能处理器基类
/// 所有技能的具体执行逻辑都需要继承此类
/// ============================================================================
abstract class SkillHandler {
  /// 执行技能
  ///
  /// [params] 技能参数（由 LLM 生成）
  /// 返回执行结果
  Future<Map<String, dynamic>> execute(Map<String, dynamic> params);
}

// ============================================================================
/// 内置技能处理器实现（占位 —— 实际功能后续完善）
/// ============================================================================

/// 网络搜索处理器
class _WebSearchHandler extends SkillHandler {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String;
    // TODO: 接入真实搜索 API
    return {
      'status': 'success',
      'query': query,
      'results': [],
      'message': '搜索功能待接入真实 API',
    };
  }
}

/// 计算器处理器
class _CalculatorHandler extends SkillHandler {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> params) async {
    final expression = params['expression'] as String;
    // TODO: 实现安全的数学表达式解析
    return {
      'status': 'success',
      'expression': expression,
      'result': '计算功能待完善',
    };
  }
}

/// 天气查询处理器
class _WeatherHandler extends SkillHandler {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> params) async {
    final city = params['city'] as String;
    // TODO: 接入天气 API
    return {
      'status': 'success',
      'city': city,
      'temperature': '功能待接入',
    };
  }
}

/// 提醒处理器
class _ReminderHandler extends SkillHandler {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> params) async {
    final title = params['title'] as String;
    final time = params['time'] as String;
    // TODO: 集成 TaskScheduler 创建提醒
    return {
      'status': 'success',
      'title': title,
      'time': time,
      'message': '提醒已创建',
    };
  }
}

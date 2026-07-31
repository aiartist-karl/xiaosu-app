// ============================================================================
// 小酥 - 技能基础类
// ============================================================================

/// 技能执行结果
class SkillResult {
  final bool success;
  final String output;
  final Map<String, dynamic>? data;
  final String? error;

  const SkillResult({
    required this.success,
    this.output = '',
    this.data,
    this.error,
  });

  factory SkillResult.ok(String output, {Map<String, dynamic>? data}) =>
      SkillResult(success: true, output: output, data: data);
  factory SkillResult.fail(String error) =>
      SkillResult(success: false, error: error);
}

/// 技能执行上下文
class SkillContext {
  final String userId;
  final String conversationId;
  final Map<String, dynamic> parameters;

  const SkillContext({
    required this.userId,
    required this.conversationId,
    this.parameters = const {},
  });
}

/// 技能基础类
abstract class BaseSkill {
  /// 技能ID
  String get skillId;

  /// 技能名称
  String get name;

  /// 技能描述
  String get description;

  /// 是否启用
  bool enabled = true;

  /// 执行技能
  Future<SkillResult> execute(SkillContext context);

  /// 获取技能参数定义
  Map<String, dynamic> get parameters => {};

  /// 技能初始化
  Future<void> initialize() async {}

  /// 技能释放
  Future<void> dispose() async {}
}

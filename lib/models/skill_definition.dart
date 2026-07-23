// ============================================================================
// 小酥 (XiaoSu) - 技能定义模型
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'skill_definition.g.dart';

/// 技能定义 —— 描述一个可被 Function Calling 调用的工具
@JsonSerializable()
class SkillDefinition {
  /// 技能唯一标识（如 "web_search", "send_email"）
  final String name;

  /// 技能中文名称
  final String displayName;

  /// 技能描述（告诉 LLM 什么时候该调用这个技能）
  final String description;

  /// 参数定义（JSON Schema 格式）
  final Map<String, dynamic> parameters;

  /// 技能分类
  @Default('')
  final String category;

  /// 是否需要确认才能执行（高权限操作）
  @Default(false)
  final bool requiresConfirmation;

  const SkillDefinition({
    required this.name,
    required this.displayName,
    required this.description,
    required this.parameters,
    this.category = '',
    this.requiresConfirmation = false,
  });

  factory SkillDefinition.fromJson(Map<String, dynamic> json) =>
      _$SkillDefinitionFromJson(json);

  Map<String, dynamic> toJson() => _$SkillDefinitionToJson(this);

  /// 转换为 OpenAI Function Calling 格式
  Map<String, dynamic> toToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }
}

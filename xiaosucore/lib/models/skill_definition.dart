// ============================================================================
// 小酥 - 技能定义模型
// ============================================================================

import 'package:equatable/equatable.dart';

/// 技能类别
enum SkillCategory {
  imageGen,       // 图片生成
  tts,            // 语音合成
  webSearch,      // 网络搜索
  email,          // 邮件
  lark,           // 飞书
  social,         // 社交媒体
  video,          // 视频生成
  podcast,        // 播客
  proDomain,      // 专业领域
  forbiddenWord,  // 违禁词检测
  cloudSync,      // 云同步
  tracking,       // 话题追踪
  browser,        // 浏览器
  chart,          // 图表
  docGen,         // 文档生成
  codeSandbox,    // 代码沙箱
  custom,         // 自定义
}

/// 技能状态
enum SkillStatus {
  enabled,   // 已启用
  disabled,  // 已禁用
  error,     // 错误
}

/// 技能定义模型
class SkillDefinition extends Equatable {
  final String id;
  final String name;
  final String description;
  final SkillCategory category;
  final SkillStatus status;
  final String version;
  final String? author;
  final String? icon;
  final Map<String, dynamic> parameters; // 技能参数定义
  final List<String> capabilities;       // 技能能力列表
  final Map<String, dynamic>? config;    // 运行时配置
  final DateTime createdAt;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.category = SkillCategory.custom,
    this.status = SkillStatus.enabled,
    this.version = '1.0.0',
    this.author,
    this.icon,
    this.parameters = const {},
    this.capabilities = const [],
    this.config,
    required this.createdAt,
  });

  factory SkillDefinition.fromJson(Map<String, dynamic> json) {
    return SkillDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: SkillCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => SkillCategory.custom,
      ),
      status: SkillStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SkillStatus.enabled,
      ),
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String?,
      icon: json['icon'] as String?,
      parameters: (json['parameters'] as Map<String, dynamic>?) ?? {},
      capabilities: (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? [],
      config: json['config'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'category': category.name, 'status': status.name,
    'version': version, 'author': author, 'icon': icon,
    'parameters': parameters, 'capabilities': capabilities,
    'config': config, 'createdAt': createdAt.toIso8601String(),
  };

  SkillDefinition copyWith({
    String? id, String? name, String? description, SkillCategory? category,
    SkillStatus? status, String? version, String? author, String? icon,
    Map<String, dynamic>? parameters, List<String>? capabilities,
    Map<String, dynamic>? config, DateTime? createdAt,
  }) {
    return SkillDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      version: version ?? this.version,
      author: author ?? this.author,
      icon: icon ?? this.icon,
      parameters: parameters ?? this.parameters,
      capabilities: capabilities ?? this.capabilities,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, category, status];
}

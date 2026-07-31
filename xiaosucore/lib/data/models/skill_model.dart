// ============================================================================
// 小酥 - Coze Studio 技能模型
// Phase 6: 对接 Coze Studio 技能市场 API
// ============================================================================

/// 技能状态
enum CozeSkillStatus {
  available,  // 可安装
  installed,  // 已安装
  updating,   // 更新中
}

/// Coze Studio 技能模型
class CozeSkill {
  final String id;
  final String name;
  final String description;
  final String version;
  final String? author;
  final String? icon;
  final CozeSkillStatus status;
  final List<String> capabilities;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CozeSkill({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author,
    this.icon,
    this.status = CozeSkillStatus.available,
    this.capabilities = const [],
    this.parameters = const {},
    required this.createdAt,
    this.updatedAt,
  });

  factory CozeSkill.fromJson(Map<String, dynamic> json) {
    return CozeSkill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String?,
      icon: json['icon'] as String?,
      status: CozeSkillStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CozeSkillStatus.available,
      ),
      capabilities:
          (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? [],
      parameters: (json['parameters'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'author': author,
        'icon': icon,
        'status': status.name,
        'capabilities': capabilities,
        'parameters': parameters,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  CozeSkill copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    String? icon,
    CozeSkillStatus? status,
    List<String>? capabilities,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CozeSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      parameters: parameters ?? this.parameters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

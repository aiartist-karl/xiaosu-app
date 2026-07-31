// ============================================================================
// 小酥 - Coze Studio 用户信息模型
// Phase 6: 对接 Coze Studio 用户信息 API
// ============================================================================

/// Coze Studio 用户信息模型
class CozeUserInfo {
  final String userId;
  final String name;
  final String? avatar;
  final String? email;
  final DateTime? createdAt;

  const CozeUserInfo({
    required this.userId,
    required this.name,
    this.avatar,
    this.email,
    this.createdAt,
  });

  factory CozeUserInfo.fromJson(Map<String, dynamic> json) {
    return CozeUserInfo(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'avatar': avatar,
        'email': email,
        'created_at': createdAt?.toIso8601String(),
      };

  CozeUserInfo copyWith({
    String? userId,
    String? name,
    String? avatar,
    String? email,
    DateTime? createdAt,
  }) {
    return CozeUserInfo(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Coze Studio 工作空间模型
class CozeWorkspace {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String role;
  final DateTime? createdAt;

  const CozeWorkspace({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.role = 'member',
    this.createdAt,
  });

  factory CozeWorkspace.fromJson(Map<String, dynamic> json) {
    return CozeWorkspace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      role: json['role'] as String? ?? 'member',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon_url': iconUrl,
        'role': role,
        'created_at': createdAt?.toIso8601String(),
      };

  CozeWorkspace copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? role,
    DateTime? createdAt,
  }) {
    return CozeWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

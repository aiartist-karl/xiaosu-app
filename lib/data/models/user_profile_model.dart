// ============================================================================
// 小酥 - 用户资料模型
// ============================================================================

/// 用户资料数据库模型
class UserProfileModel {
  final String id;
  final String nickname;
  final String avatar;
  final String email;
  final String bio;
  final String preferredModel;
  final String themeMode;    // light / dark / system
  final String language;     // zh / en
  final bool enableMemory;   // 是否启用记忆
  final bool enableVoice;    // 是否启用语音
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileModel({
    required this.id,
    this.nickname = '用户',
    this.avatar = '',
    this.email = '',
    this.bio = '',
    this.preferredModel = 'deepseek-chat',
    this.themeMode = 'system',
    this.language = 'zh',
    this.enableMemory = true,
    this.enableVoice = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'] as String? ?? 'default',
      nickname: map['nickname'] as String? ?? '用户',
      avatar: map['avatar'] as String? ?? '',
      email: map['email'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      preferredModel: map['preferredModel'] as String? ?? 'deepseek-chat',
      themeMode: map['themeMode'] as String? ?? 'system',
      language: map['language'] as String? ?? 'zh',
      enableMemory: (map['enableMemory'] as int? ?? 1) == 1,
      enableVoice: (map['enableVoice'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nickname': nickname,
    'avatar': avatar,
    'email': email,
    'bio': bio,
    'preferredModel': preferredModel,
    'themeMode': themeMode,
    'language': language,
    'enableMemory': enableMemory ? 1 : 0,
    'enableVoice': enableVoice ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserProfileModel copyWith({
    String? id, String? nickname, String? avatar, String? email,
    String? bio, String? preferredModel, String? themeMode, String? language,
    bool? enableMemory, bool? enableVoice,
    DateTime? createdAt, DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      preferredModel: preferredModel ?? this.preferredModel,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      enableMemory: enableMemory ?? this.enableMemory,
      enableVoice: enableVoice ?? this.enableVoice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

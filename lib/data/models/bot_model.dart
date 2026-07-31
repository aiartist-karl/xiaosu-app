// ============================================================================
// 小酥 v2 - Bot 数据模型
// Phase 2: Bot 管理对接 Coze Studio Bot API
// ============================================================================

/// Bot 状态枚举
enum BotStatus {
  draft,      // 草稿
  published,  // 已发布
  unknown;    // 未知

  static BotStatus fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'draft':
      case '0':
        return BotStatus.draft;
      case 'published':
      case '1':
      case 'online':
        return BotStatus.published;
      default:
        return BotStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case BotStatus.draft:
        return '草稿';
      case BotStatus.published:
        return '已发布';
      default:
        return '未知';
    }
  }
}

/// Bot 模型 - 对应 Coze Studio Bot 数据结构
class BotModel {
  final String id;
  final String name;
  final String description;
  final String? iconUri;
  final String? prompt;
  final BotStatus status;
  final Map<String, dynamic>? modelInfo;
  final List<String> pluginIds;
  final List<String> knowledgeIds;
  final String? onboardingPrompt;
  final List<String> suggestedQuestions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? versionId;
  final String? spaceId;

  // 商店扩展字段（bot-store-service）
  final String? category;
  final double? rating;
  final int? usageCount;
  final bool isOwned;
  final bool isPreset;

  const BotModel({
    required this.id,
    required this.name,
    this.description = '',
    this.iconUri,
    this.prompt,
    this.status = BotStatus.draft,
    this.modelInfo,
    this.pluginIds = const [],
    this.knowledgeIds = const [],
    this.onboardingPrompt,
    this.suggestedQuestions = const [],
    this.createdAt,
    this.updatedAt,
    this.versionId,
    this.spaceId,
    this.category,
    this.rating,
    this.usageCount,
    this.isOwned = false,
    this.isPreset = false,
  });

  /// 从 OpenAPI v1 响应创建 BotModel
  factory BotModel.fromV1List(Map<String, dynamic> json) {
    return BotModel(
      id: json['bot_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUri: json['icon_url']?.toString() ?? json['avatar_url']?.toString(),
      prompt: json['prompt_info']?['prompt']?.toString() ?? json['prompt']?.toString(),
      status: BotStatus.fromString(json['publish_status']?.toString() ?? json['status']?.toString()),
      modelInfo: json['model_info'] as Map<String, dynamic>?,
      spaceId: json['space_id']?.toString(),
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      isOwned: true,
    );
  }

  /// 从 OpenAPI v1 /v1/bots/:bot_id 详情响应创建
  factory BotModel.fromV1Detail(Map<String, dynamic> json) {
    final pluginIds = <String>[];
    final pluginInfo = json['plugin_info_list'];
    if (pluginInfo is List) {
      for (final p in pluginInfo) {
        if (p is Map<String, dynamic> && p['plugin_id'] != null) {
          pluginIds.add(p['plugin_id'].toString());
        }
      }
    }

    final knowledgeIds = <String>[];
    final knowledgeInfo = json['knowledge_info_list'];
    if (knowledgeInfo is List) {
      for (final k in knowledgeInfo) {
        if (k is Map<String, dynamic> && k['dataset_id'] != null) {
          knowledgeIds.add(k['dataset_id'].toString());
        }
      }
    }

    final suggestedQuestions = <String>[];
    final onboarding = json['onboarding_info'];
    if (onboarding is Map<String, dynamic>) {
      final questions = onboarding['suggested_questions'];
      if (questions is List) {
        for (final q in questions) {
          suggestedQuestions.add(q.toString());
        }
      }
    }

    return BotModel(
      id: json['bot_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUri: json['icon_url']?.toString() ?? json['avatar_url']?.toString(),
      prompt: json['prompt_info']?['prompt']?.toString() ?? json['prompt']?.toString(),
      status: BotStatus.fromString(json['publish_status']?.toString()),
      modelInfo: json['model_info'] as Map<String, dynamic>?,
      pluginIds: pluginIds,
      knowledgeIds: knowledgeIds,
      onboardingPrompt: onboarding is Map ? onboarding['prologue']?.toString() : null,
      suggestedQuestions: suggestedQuestions,
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      versionId: json['version_id']?.toString(),
      spaceId: json['space_id']?.toString(),
      isOwned: true,
    );
  }

  /// 从内部 API /api/draftbot 响应创建
  factory BotModel.fromDraftBot(Map<String, dynamic> json) {
    return BotModel(
      id: json['agent_id']?.toString() ?? json['bot_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUri: json['avatar_url']?.toString() ?? json['icon_url']?.toString(),
      prompt: json['prompt']?.toString() ?? json['system_prompt']?.toString(),
      status: BotStatus.fromString(json['publish_status']?.toString() ?? json['status']?.toString()),
      modelInfo: json['model_info'] as Map<String, dynamic>?,
      createdAt: _parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedAt: _parseTimestamp(json['updated_at'] ?? json['update_time']),
      spaceId: json['space_id']?.toString(),
      isOwned: true,
    );
  }

  /// 从 bot-store-service 响应创建
  factory BotModel.fromBotStore(Map<String, dynamic> json) {
    return BotModel(
      id: json['agent_id']?.toString() ?? json['bot_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUri: json['avatar_url']?.toString() ?? json['icon_url']?.toString(),
      prompt: json['prompt']?.toString(),
      status: BotStatus.fromString(json['status']?.toString()),
      category: json['category']?.toString() ?? json['category_name']?.toString(),
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : null,
      usageCount: json['usage_count'] is int
          ? json['usage_count'] as int
          : (json['usage_count'] is String ? int.tryParse(json['usage_count']) : null),
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      isPreset: json['is_preset'] == true || json['is_official'] == true,
    );
  }

  /// 转为创建 Bot 的请求体（OpenAPI v1）
  Map<String, dynamic> toCreateBody({required String spaceId}) {
    return {
      'space_id': spaceId,
      'name': name,
      'description': description,
      if (iconUri != null) 'icon_url': iconUri,
      if (prompt != null) 'prompt_info': {'prompt': prompt},
      if (modelInfo != null) 'model_info': modelInfo,
      if (pluginIds.isNotEmpty)
        'plugin_info_list': pluginIds.map((id) => {'plugin_id': id}).toList(),
      if (knowledgeIds.isNotEmpty)
        'knowledge_info_list': knowledgeIds.map((id) => {'dataset_id': id}).toList(),
    };
  }

  /// 转为更新 Bot 的请求体（OpenAPI v1）
  Map<String, dynamic> toUpdateBody() {
    return {
      'bot_id': id,
      if (name.isNotEmpty) 'name': name,
      if (description.isNotEmpty) 'description': description,
      if (iconUri != null) 'icon_url': iconUri,
      if (prompt != null) 'prompt_info': {'prompt': prompt},
      if (modelInfo != null) 'model_info': modelInfo,
    };
  }

  /// 转为发布 Bot 的请求体（OpenAPI v1）
  Map<String, dynamic> toPublishBody({required String spaceId, String? versionDesc}) {
    return {
      'bot_id': id,
      'space_id': spaceId,
      if (versionDesc != null) 'version_desc': versionDesc,
    };
  }

  /// 创建副本并修改部分字段
  BotModel copyWith({
    String? name,
    String? description,
    String? iconUri,
    String? prompt,
    BotStatus? status,
    Map<String, dynamic>? modelInfo,
    List<String>? pluginIds,
    List<String>? knowledgeIds,
    String? onboardingPrompt,
    List<String>? suggestedQuestions,
    String? versionId,
    String? category,
    double? rating,
    int? usageCount,
    bool? isOwned,
  }) {
    return BotModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUri: iconUri ?? this.iconUri,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      modelInfo: modelInfo ?? this.modelInfo,
      pluginIds: pluginIds ?? this.pluginIds,
      knowledgeIds: knowledgeIds ?? this.knowledgeIds,
      onboardingPrompt: onboardingPrompt ?? this.onboardingPrompt,
      suggestedQuestions: suggestedQuestions ?? this.suggestedQuestions,
      createdAt: createdAt,
      updatedAt: updatedAt,
      versionId: versionId ?? this.versionId,
      spaceId: spaceId,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      usageCount: usageCount ?? this.usageCount,
      isOwned: isOwned ?? this.isOwned,
      isPreset: isPreset,
    );
  }

  /// 解析时间戳（支持秒级/毫秒级 Unix 时间戳及 ISO 字符串）
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      // 秒级时间戳（Coze 常用）
      if (value > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  String toString() => 'BotModel(id: $id, name: $name, status: ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BotModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

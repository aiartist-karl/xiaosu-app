// ============================================================================
// 小酥 AI 助手 - 用户画像模型
// ============================================================================
// 定义用户画像数据结构，支持置信度加权合并策略
// 画像信息从对话中提取，用于个性化 AI 回复
// ============================================================================

import 'dart:convert';
import 'dart:math';

// ============================================================================
// 画像来源枚举
// ============================================================================

/// 画像信息来源
/// 标识画像是从什么渠道获取的
enum ProfileSource {
  /// 从对话中自动提取
  conversation('conversation'),

  /// 用户主动设置
  userInput('user_input'),

  /// 从外部导入
  imported('imported'),

  /// 系统推断（行为分析等）
  inferred('inferred');

  final String value;
  const ProfileSource(this.value);

  static ProfileSource fromString(String source) {
    return ProfileSource.values.firstWhere(
      (s) => s.value == source.toLowerCase(),
      orElse: () => ProfileSource.conversation,
    );
  }
}

// ============================================================================
// 画像类别枚举
// ============================================================================

/// 画像分类
/// 将画像按维度分类管理
enum ProfileCategory {
  /// 基本信息（姓名、年龄、职业等）
  basicInfo('basic_info'),

  /// 偏好设置（语言、主题、交互风格等）
  preferences('preferences'),

  /// 工作相关（工作日程、项目信息等）
  work('work'),

  /// 兴趣爱好
  interests('interests'),

  /// 技能水平
  skills('skills'),

  /// 社交关系
  social('social'),

  /// 地理位置
  location('location'),

  /// 其他
  other('other');

  final String value;
  const ProfileCategory(this.value);

  static ProfileCategory fromString(String category) {
    return ProfileCategory.values.firstWhere(
      (c) => c.value == category.toLowerCase(),
      orElse: () => ProfileCategory.other,
    );
  }

  /// 获取类别的中文名称
  String get displayName {
    return switch (this) {
      ProfileCategory.basicInfo => '基本信息',
      ProfileCategory.preferences => '偏好设置',
      ProfileCategory.work => '工作',
      ProfileCategory.interests => '兴趣爱好',
      ProfileCategory.skills => '技能水平',
      ProfileCategory.social => '社交关系',
      ProfileCategory.location => '地理位置',
      ProfileCategory.other => '其他',
    };
  }
}

// ============================================================================
// 画像条目模型
// ============================================================================

/// 单条画像信息
/// 画像系统的最小数据单元
class ProfileEntry {
  /// 画像键名（唯一标识）
  final String key;

  /// 画像值
  final String value;

  /// 置信度（0.0 - 1.0）
  /// 表示该信息的可靠程度
  final double confidence;

  /// 画像来源
  final ProfileSource source;

  /// 画像类别
  final ProfileCategory category;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 来源会话 ID 列表
  final List<int> sourceSessions;

  /// 创建时间
  final DateTime createdAt;

  /// 更新次数
  final int updateCount;

  const ProfileEntry({
    required this.key,
    required this.value,
    this.confidence = 0.8,
    this.source = ProfileSource.conversation,
    this.category = ProfileCategory.other,
    required this.updatedAt,
    this.sourceSessions = const [],
    required this.createdAt,
    this.updateCount = 0,
  });

  /// 从 JSON 反序列化
  factory ProfileEntry.fromJson(Map<String, dynamic> json) {
    return ProfileEntry(
      key: json['key'] as String,
      value: json['value'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      source: ProfileSource.fromString(json['source'] as String? ?? 'conversation'),
      category: ProfileCategory.fromString(json['category'] as String? ?? 'other'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updated_at'] as int),
      sourceSessions: json['source_sessions'] != null
          ? List<int>.from(json['source_sessions'] as List)
          : const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['created_at'] as int),
      updateCount: json['update_count'] as int? ?? 0,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'confidence': confidence,
      'source': source.value,
      'category': category.value,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'source_sessions': sourceSessions,
      'created_at': createdAt.millisecondsSinceEpoch,
      'update_count': updateCount,
    };
  }

  /// 复制并修改
  ProfileEntry copyWith({
    String? key,
    String? value,
    double? confidence,
    ProfileSource? source,
    ProfileCategory? category,
    DateTime? updatedAt,
    List<int>? sourceSessions,
    DateTime? createdAt,
    int? updateCount,
  }) {
    return ProfileEntry(
      key: key ?? this.key,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      category: category ?? this.category,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceSessions: sourceSessions ?? this.sourceSessions,
      createdAt: createdAt ?? this.createdAt,
      updateCount: updateCount ?? this.updateCount,
    );
  }

  /// 是否过期（超过指定天数未更新）
  bool isExpired({int maxDays = 30}) {
    final now = DateTime.now();
    return now.difference(updatedAt).inDays > maxDays;
  }

  @override
  String toString() {
    return 'ProfileEntry($key: $value, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileEntry && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

// ============================================================================
// 画像合并策略
// ============================================================================

/// 画像合并策略
/// 当检测到冲突的画像信息时，使用合并策略决定保留哪条
class ProfileMerger {
  /// 合并两条画像信息
  /// 使用置信度加权策略，置信度高的信息更可能被保留
  ///
  /// [existing] 已有的画像信息
  /// [incoming] 新检测到的画像信息
  /// [timeDecayFactor] 时间衰减因子，越旧的信息置信度衰减越多
  static ProfileEntry merge(
    ProfileEntry existing,
    ProfileEntry incoming, {
    double timeDecayFactor = 0.95,
  }) {
    // 计算时间衰减后的置信度
    final now = DateTime.now();
    final existingAge = now.difference(existing.updatedAt).inDays;
    final incomingAge = now.difference(incoming.updatedAt).inDays;

    final existingEffectiveConfidence =
        existing.confidence * pow(timeDecayFactor, existingAge).toDouble();
    final incomingEffectiveConfidence =
        incoming.confidence * pow(timeDecayFactor, incomingAge).toDouble();

    // 如果新信息的值与已有值相同，只更新置信度和时间
    if (existing.value.trim().toLowerCase() ==
        incoming.value.trim().toLowerCase()) {
      // 值相同：提高置信度（多次确认），取平均值
      final newConfidence = min(
        1.0,
        (existingEffectiveConfidence + incomingEffectiveConfidence) / 2 * 1.1,
      );

      // 合并来源会话
      final mergedSessions = {
        ...existing.sourceSessions,
        ...incoming.sourceSessions,
      }.toList()
        ..sort();

      return existing.copyWith(
        confidence: newConfidence,
        updatedAt: max(existing.updatedAt, incoming.updatedAt),
        sourceSessions: mergedSessions,
        updateCount: existing.updateCount + 1,
      );
    }

    // 值不同：使用置信度加权决策
    if (incomingEffectiveConfidence > existingEffectiveConfidence) {
      // 新信息更可信：替换，但保留部分历史置信度
      final newConfidence = min(
        1.0,
        incomingEffectiveConfidence * 0.9 + existingEffectiveConfidence * 0.1,
      );

      // 合并来源会话
      final mergedSessions = {
        ...existing.sourceSessions,
        ...incoming.sourceSessions,
      }.toList()
        ..sort();

      return incoming.copyWith(
        confidence: newConfidence,
        sourceSessions: mergedSessions,
        updateCount: existing.updateCount + 1,
      );
    } else {
      // 已有信息更可信：保留已有信息，略微提高置信度
      return existing.copyWith(
        confidence: min(1.0, existingEffectiveConfidence * 1.02),
        updatedAt: now,
      );
    }
  }

  /// 批量合并画像列表
  /// 将新的画像信息合并到已有画像中
  static List<ProfileEntry> mergeAll(
    List<ProfileEntry> existing,
    List<ProfileEntry> incoming, {
    double timeDecayFactor = 0.95,
  }) {
    // 创建已有画像的映射表
    final map = <String, ProfileEntry>{};
    for (final entry in existing) {
      map[entry.key] = entry;
    }

    // 逐条合并新画像
    for (final incomingEntry in incoming) {
      if (map.containsKey(incomingEntry.key)) {
        map[incomingEntry.key] = merge(
          map[incomingEntry.key]!,
          incomingEntry,
          timeDecayFactor: timeDecayFactor,
        );
      } else {
        map[incomingEntry.key] = incomingEntry;
      }
    }

    return map.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }
}

// ============================================================================
// 完整用户画像模型
// ============================================================================

/// 用户画像模型
/// 包含从对话中提取的所有用户信息
class UserProfile {
  /// 画像条目列表
  final List<ProfileEntry> entries;

  /// 画像更新时间
  final DateTime lastUpdated;

  /// 画像版本
  final int version;

  const UserProfile({
    required this.entries,
    required this.lastUpdated,
    this.version = 1,
  });

  /// 空画像
  static const empty = UserProfile(
    entries: [],
    lastUpdated: DateTime(2000),
  );

  /// 获取指定 key 的画像值
  String? getValue(String key) {
    try {
      return entries.firstWhere((e) => e.key == key).value;
    } catch (_) {
      return null;
    }
  }

  /// 获取指定类别的所有画像
  List<ProfileEntry> getByCategory(ProfileCategory category) {
    return entries.where((e) => e.category == category).toList();
  }

  /// 获取高置信度画像（>= 指定阈值）
  List<ProfileEntry> getHighConfidence({double threshold = 0.7}) {
    return entries.where((e) => e.confidence >= threshold).toList();
  }

  /// 按类别分组的画像
  Map<ProfileCategory, List<ProfileEntry>> get groupedByCategory {
    final grouped = <ProfileCategory, List<ProfileEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }
    return grouped;
  }

  /// 画像条目数量
  int get length => entries.length;

  /// 是否为空
  bool get isEmpty => entries.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => entries.isNotEmpty;

  /// 平均置信度
  double get averageConfidence {
    if (entries.isEmpty) return 0.0;
    return entries.map((e) => e.confidence).reduce((a, b) => a + b) /
        entries.length;
  }

  /// 从 JSON 反序列化
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      entries: (json['entries'] as List)
          .map((e) => ProfileEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          json['last_updated'] as int),
      version: json['version'] as int? ?? 1,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((e) => e.toJson()).toList(),
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'version': version,
    };
  }

  /// 序列化为 JSON 字符串（格式化）
  String toFormattedJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  /// 从 JSON 字符串解析
  factory UserProfile.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  /// 复制并修改
  UserProfile copyWith({
    List<ProfileEntry>? entries,
    DateTime? lastUpdated,
    int? version,
  }) {
    return UserProfile(
      entries: entries ?? this.entries,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
    );
  }

  /// 生成画像摘要（用于系统提示）
  String toSystemPrompt() {
    if (isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('## 用户画像');
    buffer.writeln();

    final grouped = groupedByCategory;
    for (final entry in grouped.entries) {
      buffer.writeln('### ${entry.key.displayName}');
      for (final item in entry.value) {
        buffer.writeln('- ${item.key}: ${item.value}');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  @override
  String toString() {
    return 'UserProfile(entries: ${entries.length}, '
        'avgConfidence: ${averageConfidence.toStringAsFixed(2)})';
  }
}

// ============================================================================
// 画像提取请求/响应
// ============================================================================

/// 画像提取请求
/// 从对话中提取画像信息时使用的请求模型
class ProfileExtractionRequest {
  /// 对话消息列表
  final List<Map<String, String>> messages;

  /// 现有画像（用于增量更新）
  final UserProfile? existingProfile;

  /// 提取的会话 ID
  final int sessionId;

  const ProfileExtractionRequest({
    required this.messages,
    this.existingProfile,
    required this.sessionId,
  });
}

/// 画像提取响应
/// LLM 提取画像后的返回结果
class ProfileExtractionResponse {
  /// 提取到的画像条目列表
  final List<ProfileEntry> extractedEntries;

  /// 提取使用的 token 数
  final int tokensUsed;

  /// 提取耗时（毫秒）
  final int durationMs;

  const ProfileExtractionResponse({
    required this.extractedEntries,
    this.tokensUsed = 0,
    this.durationMs = 0,
  });
}

// ============================================================================
// 小酥 AI 助手 - 记忆仓库
// ============================================================================
// 封装用户画像和记忆数据的管理
// 支持记忆的存储、检索、合并、清理和归档
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/user_profile_model.dart';

/// 记忆仓库
/// 负责用户画像和记忆数据的存取管理
class MemoryRepository {
  /// 数据库实例
  final AppDatabase _db;

  /// 记忆缓存（避免频繁查库）
  UserProfile? _cachedProfile;

  /// 缓存有效期
  DateTime? _cacheExpiry;

  /// 缓存过期时间（分钟）
  static const int _cacheExpiryMinutes = 5;

  /// 构造函数
  MemoryRepository(this._db);

  // ============================================================================
  // 用户画像管理
  // ============================================================================

  /// 获取完整的用户画像
  /// 优先从缓存读取，缓存过期后从数据库加载
  ///
  /// [forceRefresh] 是否强制刷新缓存
  Future<UserProfile> getUserProfile({bool forceRefresh = false}) async {
    // 检查缓存是否有效
    if (!forceRefresh &&
        _cachedProfile != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedProfile!;
    }

    // 从数据库加载
    final entries = await _db.getAllUserProfiles();
    final profileEntries = entries.map(_toProfileEntry).toList();

    final profile = UserProfile(
      entries: profileEntries,
      lastUpdated: DateTime.now(),
    );

    // 更新缓存
    _cachedProfile = profile;
    _cacheExpiry = DateTime.now().add(
      const Duration(minutes: _cacheExpiryMinutes),
    );

    return profile;
  }

  /// 保存单条画像信息
  /// 如果 key 已存在，使用合并策略更新
  ///
  /// [entry] 要保存的画像条目
  Future<void> saveProfileEntry(ProfileEntry entry) async {
    // 检查是否已存在
    final existing = await _db.getUserProfileByKey(entry.key);

    if (existing != null) {
      // 已存在：使用合并策略
      final existingEntry = _toProfileEntry(existing);
      final merged = ProfileMerger.merge(existingEntry, entry);
      await _saveProfileEntry(merged);
    } else {
      // 不存在：直接插入
      await _saveProfileEntry(entry);
    }

    // 清除缓存，强制下次重新加载
    _invalidateCache();
  }

  /// 批量保存画像信息
  ///
  /// [entries] 要保存的画像条目列表
  /// [mergeStrategy] 合并策略：merge（智能合并）或 replace（直接替换）
  Future<void> saveProfileEntries(
    List<ProfileEntry> entries, {
    MergeStrategy mergeStrategy = MergeStrategy.merge,
  }) async {
    if (mergeStrategy == MergeStrategy.replace) {
      // 替换策略：直接写入（覆盖已有值）
      for (final entry in entries) {
        await _saveProfileEntry(entry);
      }
    } else {
      // 合并策略：智能合并
      final existing = await getUserProfile();
      final merged = ProfileMerger.mergeAll(existing.entries, entries);

      for (final entry in merged) {
        await _saveProfileEntry(entry);
      }
    }

    _invalidateCache();
  }

  /// 从对话中提取并保存画像
  ///
  /// [sessionId] 会话 ID
  /// [extractedEntries] 从 LLM 提取的画像条目
  Future<void> saveExtractedProfile({
    required int sessionId,
    required List<ProfileEntry> extractedEntries,
  }) async {
    // 为每个条目补充来源会话信息
    final entriesWithSource = extractedEntries.map((entry) {
      return entry.copyWith(
        sourceSessions: [...entry.sourceSessions, sessionId],
      );
    }).toList();

    await saveProfileEntries(entriesWithSource);
  }

  /// 删除指定画像
  Future<bool> deleteProfileEntry(String key) async {
    final result = await _db.deleteUserProfile(key);
    if (result) _invalidateCache();
    return result;
  }

  /// 按类别获取画像
  Future<List<ProfileEntry>> getProfilesByCategory(
      ProfileCategory category) async {
    final profile = await getUserProfile();
    return profile.getByCategory(category);
  }

  /// 获取高置信度画像
  Future<List<ProfileEntry>> getHighConfidenceProfiles({
    double threshold = 0.7,
  }) async {
    final profile = await getUserProfile();
    return profile.getHighConfidence(threshold: threshold);
  }

  /// 获取画像值（快捷方法）
  Future<String?> getProfileValue(String key) async {
    final profile = await getUserProfile();
    return profile.getValue(key);
  }

  // ============================================================================
  // 记忆清理与归档
  // ============================================================================

  /// 清理低置信度画像
  ///
  /// [threshold] 置信度阈值，低于此值的画像将被清理
  Future<int> cleanLowConfidenceProfiles({double threshold = 0.3}) async {
    final count = await _db.cleanUpLowConfidenceProfiles(threshold);
    _invalidateCache();
    return count;
  }

  /// 清理过期画像
  /// 删除超过指定天数未更新的画像
  ///
  /// [maxDays] 最大保留天数
  Future<int> cleanExpiredProfiles({int maxDays = 30}) async {
    final profile = await getUserProfile();
    final expiredKeys = profile.entries
        .where((e) => e.isExpired(maxDays: maxDays))
        .map((e) => e.key)
        .toList();

    int count = 0;
    for (final key in expiredKeys) {
      final deleted = await _db.deleteUserProfile(key);
      if (deleted) count++;
    }

    if (count > 0) _invalidateCache();
    return count;
  }

  /// 归档旧画像
  /// 将画像导出为 JSON 并从数据库中删除
  ///
  /// [maxDays] 超过多少天的画像需要归档
  Future<MemoryArchive> archiveOldProfiles({int maxDays = 90}) async {
    final profile = await getUserProfile();
    final now = DateTime.now();

    final toArchive = <ProfileEntry>[];
    final toKeep = <ProfileEntry>[];

    for (final entry in profile.entries) {
      if (now.difference(entry.updatedAt).inDays > maxDays) {
        toArchive.add(entry);
      } else {
        toKeep.add(entry);
      }
    }

    // 导出为 JSON
    final archiveData = {
      'archived_at': now.millisecondsSinceEpoch,
      'count': toArchive.length,
      'entries': toArchive.map((e) => e.toJson()).toList(),
    };

    // 从数据库中删除已归档的画像
    for (final entry in toArchive) {
      await _db.deleteUserProfile(entry.key);
    }

    _invalidateCache();

    return MemoryArchive(
      archivedAt: now,
      count: toArchive.length,
      data: archiveData,
      archivedEntries: toArchive,
      remainingEntries: toKeep,
    );
  }

  /// 重置所有画像数据
  /// ⚠️ 危险操作：将清除所有用户画像
  Future<void> resetAllProfiles() async {
    // 先获取所有画像用于备份
    final allProfiles = await _db.getAllUserProfiles();
    for (final profile in allProfiles) {
      // 遍历删除（drift 不支持批量删除所有记录的条件语句）
      await _db.deleteUserProfile(profile.key);
    }
    _invalidateCache();
  }

  // ============================================================================
  // 画像搜索
  // ============================================================================

  /// 搜索画像
  /// 在画像的 key 和 value 中搜索关键词
  ///
  /// [keyword] 搜索关键词
  Future<List<ProfileEntry>> searchProfiles(String keyword) async {
    final profile = await getUserProfile();
    final lowerKeyword = keyword.toLowerCase();

    return profile.entries.where((entry) {
      return entry.key.toLowerCase().contains(lowerKeyword) ||
          entry.value.toLowerCase().contains(lowerKeyword);
    }).toList();
  }

  // ============================================================================
  // 画像生成系统提示
  // ============================================================================

  /// 生成用于系统提示的用户画像摘要
  /// 只包含高置信度的画像信息
  Future<String> generateSystemPrompt({double minConfidence = 0.5}) async {
    final profile = await getUserProfile();
    final highConfidence = profile.getHighConfidence(threshold: minConfidence);

    if (highConfidence.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('以下是关于用户的信息（基于之前的对话）：');
    buffer.writeln();

    // 按类别分组
    final grouped = <ProfileCategory, List<ProfileEntry>>{};
    for (final entry in highConfidence) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    for (final entry in grouped.entries) {
      for (final item in entry.value) {
        buffer.writeln('- ${item.key}: ${item.value}');
      }
    }

    return buffer.toString().trim();
  }

  // ============================================================================
  // 统计信息
  // ============================================================================

  /// 获取记忆统计信息
  Future<MemoryStats> getMemoryStats() async {
    final profile = await getUserProfile();

    final now = DateTime.now();
    int activeCount = 0;
    int expiredCount = 0;

    for (final entry in profile.entries) {
      if (entry.isExpired()) {
        expiredCount++;
      } else {
        activeCount++;
      }
    }

    return MemoryStats(
      totalEntries: profile.length,
      activeEntries: activeCount,
      expiredEntries: expiredCount,
      averageConfidence: profile.averageConfidence,
      categories: profile.groupedByCategory.map(
        (k, v) => MapEntry(k.displayName, v.length),
      ),
    );
  }

  // ============================================================================
  // 内部方法
  // ============================================================================

  /// 将数据库记录转换为 ProfileEntry
  ProfileEntry _toProfileEntry(UserProfile entry) {
    List<int> sourceSessions = [];
    try {
      final sessions = jsonDecode(entry.sourceSessions) as List;
      sourceSessions = sessions.map((s) => s as int).toList();
    } catch (_) {
      // 解析失败使用空列表
    }

    return ProfileEntry(
      key: entry.key,
      value: entry.value,
      confidence: entry.confidence,
      updatedAt: entry.updatedAt,
      sourceSessions: sourceSessions,
      createdAt: entry.updatedAt, // drift 表没有单独的 createdAt
    );
  }

  /// 保存 ProfileEntry 到数据库
  Future<void> _saveProfileEntry(ProfileEntry entry) async {
    await _db.upsertUserProfile(
      UserProfilesCompanion(
        key: Value(entry.key),
        value: Value(entry.value),
        confidence: Value(entry.confidence),
        updatedAt: Value(DateTime.now()),
        sourceSessions: Value(jsonEncode(entry.sourceSessions)),
      ),
    );
  }

  /// 清除缓存
  void _invalidateCache() {
    _cachedProfile = null;
    _cacheExpiry = null;
  }
}

// ============================================================================
// 辅助模型
// ============================================================================

/// 合并策略
enum MergeStrategy {
  /// 智能合并（基于置信度加权）
  merge,

  /// 直接替换
  replace,
}

/// 记忆归档结果
class MemoryArchive {
  /// 归档时间
  final DateTime archivedAt;

  /// 归档数量
  final int count;

  /// 归档数据（JSON 格式）
  final Map<String, dynamic> data;

  /// 已归档的画像条目
  final List<ProfileEntry> archivedEntries;

  /// 剩余的画像条目
  final List<ProfileEntry> remainingEntries;

  const MemoryArchive({
    required this.archivedAt,
    required this.count,
    required this.data,
    required this.archivedEntries,
    required this.remainingEntries,
  });

  /// 归档数据序列化为 JSON 字符串
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}

/// 记忆统计信息
class MemoryStats {
  /// 总画像条目数
  final int totalEntries;

  /// 活跃画像数
  final int activeEntries;

  /// 过期画像数
  final int expiredEntries;

  /// 平均置信度
  final double averageConfidence;

  /// 各类别画像数量
  final Map<String, int> categories;

  const MemoryStats({
    required this.totalEntries,
    required this.activeEntries,
    required this.expiredEntries,
    required this.averageConfidence,
    required this.categories,
  });

  Map<String, dynamic> toJson() => {
        'total_entries': totalEntries,
        'active_entries': activeEntries,
        'expired_entries': expiredEntries,
        'average_confidence': averageConfidence,
        'categories': categories,
      };
}

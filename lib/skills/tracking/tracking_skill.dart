// ============================================================================
// 小酥 AI 助手 - 话题追踪技能
// ============================================================================
// 提供话题追踪、定期简报、通知推送等功能
// 支持多种信息源、AI 摘要、历史搜索、报告导出
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/skill/skill.dart';

// ============================================================================
// 话题模型
// ============================================================================

/// 话题优先级
enum TopicPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const TopicPriority(this.value);
}

/// 话题状态
enum TopicStatus {
  active('active'),
  paused('paused'),
  archived('archived');

  final String value;
  const TopicStatus(this.value);
}

/// 追踪话题
class TrackingTopic {
  /// 话题 ID
  final String id;

  /// 话题名称
  final String name;

  /// 话题描述
  final String description;

  /// 话题标签
  final List<String> tags;

  /// 所属分组
  final String group;

  /// 优先级
  final TopicPriority priority;

  /// 状态
  final TopicStatus status;

  /// 信息源列表
  final List<TrackingSource> sources;

  /// 简报频率配置
  final BriefingFrequency frequency;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime lastUpdatedAt;

  /// 通知配置
  final NotificationConfig notification;

  /// 追踪到的文章/事件计数
  final int trackedCount;

  TrackingTopic({
    required this.id,
    required this.name,
    this.description = '',
    this.tags = const [],
    this.group = 'default',
    this.priority = TopicPriority.medium,
    this.status = TopicStatus.active,
    this.sources = const [],
    this.frequency = const BriefingFrequency(),
    required this.createdAt,
    this.lastUpdatedAt,
    this.notification = const NotificationConfig(),
    this.trackedCount = 0,
  });

  TrackingTopic copyWith({
    String? name,
    String? description,
    List<String>? tags,
    String? group,
    TopicPriority? priority,
    TopicStatus? status,
    List<TrackingSource>? sources,
    BriefingFrequency? frequency,
    NotificationConfig? notification,
    int? trackedCount,
  }) {
    return TrackingTopic(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      group: group ?? this.group,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      sources: sources ?? this.sources,
      frequency: frequency ?? this.frequency,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      notification: notification ?? this.notification,
      trackedCount: trackedCount ?? this.trackedCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tags': tags,
        'group': group,
        'priority': priority.value,
        'status': status.value,
        'sources': sources.map((s) => s.toJson()).toList(),
        'frequency': frequency.toJson(),
        'created_at': createdAt.toIso8601String(),
        'last_updated_at': lastUpdatedAt?.toIso8601String(),
        'notification': notification.toJson(),
        'tracked_count': trackedCount,
      };

  factory TrackingTopic.fromJson(Map<String, dynamic> json) {
    return TrackingTopic(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      group: json['group'] as String? ?? 'default',
      priority: TopicPriority.values.firstWhere(
        (p) => p.value == json['priority'],
        orElse: () => TopicPriority.medium,
      ),
      status: TopicStatus.values.firstWhere(
        (s) => s.value == json['status'],
        orElse: () => TopicStatus.active,
      ),
      sources: (json['sources'] as List?)
              ?.map((s) => TrackingSource.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      frequency: json['frequency'] != null
          ? BriefingFrequency.fromJson(json['frequency'] as Map<String, dynamic>)
          : const BriefingFrequency(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      lastUpdatedAt: DateTime.tryParse(json['last_updated_at'] as String? ?? ''),
      notification: json['notification'] != null
          ? NotificationConfig.fromJson(json['notification'] as Map<String, dynamic>)
          : const NotificationConfig(),
      trackedCount: json['tracked_count'] as int? ?? 0,
    );
  }
}

// ============================================================================
// 信息源模型
// ============================================================================

/// 信息源类型
enum SourceType {
  rss('rss'),
  newsApi('news_api'),
  socialKeyword('social_keyword'),
  academicSearch('academic_search'),
  webMonitor('web_monitor'),
  customApi('custom_api');

  final String value;
  const SourceType(this.value);
}

/// 追踪信息源
class TrackingSource {
  /// 源 ID
  final String id;

  /// 源名称
  final String name;

  /// 源类型
  final SourceType type;

  /// 源地址（RSS URL / API endpoint / 监控 URL / 关键词）
  final String url;

  /// 是否启用
  final bool enabled;

  /// 刷新间隔（分钟）
  final int refreshIntervalMinutes;

  /// 额外配置
  final Map<String, dynamic> config;

  /// 最后抓取时间
  final DateTime? lastFetchedAt;

  const TrackingSource({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.enabled = true,
    this.refreshIntervalMinutes = 60,
    this.config = const {},
    this.lastFetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.value,
        'url': url,
        'enabled': enabled,
        'refresh_interval': refreshIntervalMinutes,
        'config': config,
        if (lastFetchedAt != null) 'last_fetched_at': lastFetchedAt!.toIso8601String(),
      };

  factory TrackingSource.fromJson(Map<String, dynamic> json) {
    return TrackingSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: SourceType.values.firstWhere(
        (t) => t.value == json['type'],
        orElse: () => SourceType.rss,
      ),
      url: json['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      refreshIntervalMinutes: json['refresh_interval'] as int? ?? 60,
      config: json['config'] as Map<String, dynamic>? ?? {},
      lastFetchedAt: json['last_fetched_at'] != null
          ? DateTime.tryParse(json['last_fetched_at'] as String)
          : null,
    );
  }
}

// ============================================================================
// 简报模型
// ============================================================================

/// 简报频率
class BriefingFrequency {
  /// 是否启用每日简报
  final bool dailyEnabled;

  /// 每日简报时间（HH:mm 格式）
  final String dailyTime;

  /// 是否启用每周简报
  final bool weeklyEnabled;

  /// 每周简报星期几（1=周一, 7=周日）
  final int weeklyDay;

  /// 每周简报时间
  final String weeklyTime;

  /// 是否实时推送重大事件
  final bool realtimeEnabled;

  const BriefingFrequency({
    this.dailyEnabled = true,
    this.dailyTime = '08:00',
    this.weeklyEnabled = false,
    this.weeklyDay = 1,
    this.weeklyTime = '09:00',
    this.realtimeEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'daily_enabled': dailyEnabled,
        'daily_time': dailyTime,
        'weekly_enabled': weeklyEnabled,
        'weekly_day': weeklyDay,
        'weekly_time': weeklyTime,
        'realtime_enabled': realtimeEnabled,
      };

  factory BriefingFrequency.fromJson(Map<String, dynamic> json) {
    return BriefingFrequency(
      dailyEnabled: json['daily_enabled'] as bool? ?? true,
      dailyTime: json['daily_time'] as String? ?? '08:00',
      weeklyEnabled: json['weekly_enabled'] as bool? ?? false,
      weeklyDay: json['weekly_day'] as int? ?? 1,
      weeklyTime: json['weekly_time'] as String? ?? '09:00',
      realtimeEnabled: json['realtime_enabled'] as bool? ?? true,
    );
  }
}

/// 追踪到的事件/文章
class TrackedItem {
  /// 唯一 ID
  final String id;

  /// 所属话题 ID
  final String topicId;

  /// 来源
  final String sourceName;

  /// 标题
  final String title;

  /// 摘要
  final String summary;

  /// 原始链接
  final String url;

  /// 发布时间
  final DateTime? publishedAt;

  /// 抓取时间
  final DateTime fetchedAt;

  /// 是否重大事件
  final bool isMajor;

  /// 重要性评分 (0-1)
  final double importanceScore;

  /// 标签
  final List<String> tags;

  /// 完整内容（可选）
  final String? fullContent;

  const TrackedItem({
    required this.id,
    required this.topicId,
    required this.sourceName,
    required this.title,
    this.summary = '',
    this.url = '',
    this.publishedAt,
    required this.fetchedAt,
    this.isMajor = false,
    this.importanceScore = 0.5,
    this.tags = const [],
    this.fullContent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic_id': topicId,
        'source_name': sourceName,
        'title': title,
        'summary': summary,
        'url': url,
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        'fetched_at': fetchedAt.toIso8601String(),
        'is_major': isMajor,
        'importance_score': importanceScore,
        'tags': tags,
      };

  factory TrackedItem.fromJson(Map<String, dynamic> json) {
    return TrackedItem(
      id: json['id'] as String? ?? '',
      topicId: json['topic_id'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      url: json['url'] as String? ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      fetchedAt: DateTime.tryParse(json['fetched_at'] as String? ?? '') ?? DateTime.now(),
      isMajor: json['is_major'] as bool? ?? false,
      importanceScore: (json['importance_score'] as num?)?.toDouble() ?? 0.5,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 简报内容
class Briefing {
  /// 简报 ID
  final String id;

  /// 话题 ID
  final String topicId;

  /// 简报标题
  final String title;

  /// 简报类型
  final String type; // daily / weekly / realtime

  /// AI 生成的摘要
  final String aiSummary;

  /// 关键事件列表
  final List<TrackedItem> keyEvents;

  /// 趋势分析
  final String? trendAnalysis;

  /// 生成时间
  final DateTime createdAt;

  /// 包含的文章数
  final int itemCount;

  const Briefing({
    required this.id,
    required this.topicId,
    required this.title,
    required this.type,
    required this.aiSummary,
    this.keyEvents = const [],
    this.trendAnalysis,
    required this.createdAt,
    this.itemCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic_id': topicId,
        'title': title,
        'type': type,
        'ai_summary': aiSummary,
        'key_events': keyEvents.map((e) => e.toJson()).toList(),
        if (trendAnalysis != null) 'trend_analysis': trendAnalysis,
        'created_at': createdAt.toIso8601String(),
        'item_count': itemCount,
      };
}

// ============================================================================
// 通知配置
// ============================================================================

/// 通知渠道
enum NotificationChannel {
  appPush('app_push'),
  email('email'),
  lark('lark'),
  webhook('webhook');

  final String value;
  const NotificationChannel(this.value);
}

/// 通知配置
class NotificationConfig {
  /// 启用的通知渠道
  final List<NotificationChannel> channels;

  /// 重大事件阈值（importance_score >= 此值时通知）
  final double majorThreshold;

  /// Webhook URL（channel 为 webhook 时使用）
  final String? webhookUrl;

  /// 邮件地址（channel 为 email 时使用）
  final String? emailAddress;

  /// 静默时间段（不发送通知）
  final String? quietStart;
  final String? quietEnd;

  const NotificationConfig({
    this.channels = const [NotificationChannel.appPush],
    this.majorThreshold = 0.8,
    this.webhookUrl,
    this.emailAddress,
    this.quietStart,
    this.quietEnd,
  });

  Map<String, dynamic> toJson() => {
        'channels': channels.map((c) => c.value).toList(),
        'major_threshold': majorThreshold,
        if (webhookUrl != null) 'webhook_url': webhookUrl,
        if (emailAddress != null) 'email_address': emailAddress,
        if (quietStart != null) 'quiet_start': quietStart,
        if (quietEnd != null) 'quiet_end': quietEnd,
      };

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      channels: (json['channels'] as List?)
              ?.map((c) => NotificationChannel.values.firstWhere(
                    (ch) => ch.value == c,
                    orElse: () => NotificationChannel.appPush,
                  ))
              .toList() ??
          const [NotificationChannel.appPush],
      majorThreshold: (json['major_threshold'] as num?)?.toDouble() ?? 0.8,
      webhookUrl: json['webhook_url'] as String?,
      emailAddress: json['email_address'] as String?,
      quietStart: json['quiet_start'] as String?,
      quietEnd: json['quiet_end'] as String?,
    );
  }
}

// ============================================================================
// 报告导出格式
// ============================================================================

enum ExportFormat {
  markdown('markdown'),
  pdf('pdf'),
  word('word'),
  json('json');

  final String value;
  const ExportFormat(this.value);
}

// ============================================================================
// 话题追踪技能
// ============================================================================

/// 话题追踪技能
/// 提供 start_tracking, stop_tracking, get_briefing 等 8 个工具
class TopicTrackingSkill extends Skill {
  /// 技能配置
  final TrackingSkillConfig _config;

  /// 话题存储（内存缓存）
  final Map<String, TrackingTopic> _topics = {};

  /// 追踪数据缓存
  final Map<String, List<TrackedItem>> _trackedItems = {};

  /// 历史简报缓存
  final Map<String, List<Briefing>> _briefings = {};

  TopicTrackingSkill({TrackingSkillConfig? config})
      : _config = config ?? const TrackingSkillConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'topic_tracking',
        name: '话题追踪',
        description: '持续追踪特定话题的最新动态。支持添加/管理追踪话题、'
            '配置多种信息源（RSS/新闻API/社交媒体/学术搜索/自定义网页）、'
            '定期生成 AI 简报、重大事件即时通知、历史搜索和报告导出。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.localStorage,
          SkillPermission.sendNotification,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _startTrackingTool,
        _stopTrackingTool,
        _getBriefingTool,
        _updateSourcesTool,
        _setFrequencyTool,
        _exportReportTool,
        _searchHistoryTool,
        _configureNotificationTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  late final SkillTool _startTrackingTool = SkillTool(
    name: 'start_tracking',
    description: '开始追踪一个话题。配置话题名称、标签、信息源和通知方式。',
    parameters: [
      ToolParameter(name: 'topic_name', description: '话题名称', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'description', description: '话题描述/关注重点', type: ToolParameterType.stringType),
      ToolParameter(name: 'tags', description: '话题标签列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'group', description: '话题分组', type: ToolParameterType.stringType, defaultValue: 'default'),
      ToolParameter(name: 'priority', description: '优先级', type: ToolParameterType.stringType, enumValues: ['low', 'medium', 'high', 'critical'], defaultValue: 'medium'),
      ToolParameter(name: 'sources', description: '信息源配置列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'daily_briefing', description: '是否开启每日简报', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'realtime_notify', description: '是否实时推送重大事件', type: ToolParameterType.boolType, defaultValue: true),
    ],
    timeoutMs: 30000,
    execute: _executeStartTracking,
  );

  late final SkillTool _stopTrackingTool = SkillTool(
    name: 'stop_tracking',
    description: '停止追踪话题。可暂停或归档。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'action', description: '操作类型', type: ToolParameterType.stringType, enumValues: ['pause', 'archive', 'delete'], defaultValue: 'pause'),
    ],
    timeoutMs: 10000,
    execute: _executeStopTracking,
  );

  late final SkillTool _getBriefingTool = SkillTool(
    name: 'get_briefing',
    description: '获取话题追踪简报。包含 AI 摘要、关键事件和趋势分析。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'type', description: '简报类型', type: ToolParameterType.stringType, enumValues: ['latest', 'daily', 'weekly'], defaultValue: 'latest'),
      ToolParameter(name: 'include_events', description: '是否包含关键事件详情', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'max_events', description: '最大关键事件数', type: ToolParameterType.intType, minValue: 1, maxValue: 50, defaultValue: 10),
    ],
    timeoutMs: 30000,
    execute: _executeGetBriefing,
  );

  late final SkillTool _updateSourcesTool = SkillTool(
    name: 'update_sources',
    description: '更新话题的信息源配置。支持添加、删除、修改信息源。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'action', description: '操作类型', type: ToolParameterType.stringType, enumValues: ['add', 'remove', 'update', 'enable', 'disable'], required: true),
      ToolParameter(name: 'source', description: '信息源配置（add/update 时必填）', type: ToolParameterType.objectType),
      ToolParameter(name: 'source_id', description: '信息源 ID（remove/enable/disable 时必填）', type: ToolParameterType.stringType),
    ],
    timeoutMs: 15000,
    execute: _executeUpdateSources,
  );

  late final SkillTool _setFrequencyTool = SkillTool(
    name: 'set_frequency',
    description: '设置话题的简报频率。配置每日/每周简报时间和实时通知。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'daily_enabled', description: '是否启用每日简报', type: ToolParameterType.boolType),
      ToolParameter(name: 'daily_time', description: '每日简报时间（HH:mm）', type: ToolParameterType.stringType),
      ToolParameter(name: 'weekly_enabled', description: '是否启用每周简报', type: ToolParameterType.boolType),
      ToolParameter(name: 'weekly_day', description: '每周简报星期几（1-7）', type: ToolParameterType.intType, minValue: 1, maxValue: 7),
      ToolParameter(name: 'weekly_time', description: '每周简报时间（HH:mm）', type: ToolParameterType.stringType),
      ToolParameter(name: 'realtime_enabled', description: '是否启用实时推送', type: ToolParameterType.boolType),
    ],
    timeoutMs: 10000,
    execute: _executeSetFrequency,
  );

  late final SkillTool _exportReportTool = SkillTool(
    name: 'export_report',
    description: '导出话题追踪报告。支持 Markdown、PDF、Word、JSON 格式。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'format', description: '导出格式', type: ToolParameterType.stringType, enumValues: ['markdown', 'pdf', 'word', 'json'], defaultValue: 'markdown'),
      ToolParameter(name: 'date_range', description: '日期范围：包含多少天的数据', type: ToolParameterType.intType, minValue: 1, maxValue: 365, defaultValue: 7),
      ToolParameter(name: 'include_summary', description: '是否包含 AI 摘要', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'include_trend', description: '是否包含趋势分析', type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'save_path', description: '保存路径', type: ToolParameterType.stringType),
    ],
    timeoutMs: 60000,
    execute: _executeExportReport,
  );

  late final SkillTool _searchHistoryTool = SkillTool(
    name: 'search_history',
    description: '全文检索历史追踪数据。搜索已追踪到的文章、事件和简报。',
    parameters: [
      ToolParameter(name: 'query', description: '搜索关键词', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'topic_id', description: '限定话题 ID（不传则搜索所有话题）', type: ToolParameterType.stringType),
      ToolParameter(name: 'date_from', description: '起始日期（ISO 8601）', type: ToolParameterType.stringType),
      ToolParameter(name: 'date_to', description: '结束日期（ISO 8601）', type: ToolParameterType.stringType),
      ToolParameter(name: 'min_importance', description: '最低重要性评分（0-1）', type: ToolParameterType.doubleType, minValue: 0, maxValue: 1),
      ToolParameter(name: 'max_results', description: '最大结果数', type: ToolParameterType.intType, minValue: 1, maxValue: 100, defaultValue: 20),
    ],
    timeoutMs: 15000,
    execute: _executeSearchHistory,
  );

  late final SkillTool _configureNotificationTool = SkillTool(
    name: 'configure_notification',
    description: '配置话题的通知方式。设置通知渠道、阈值和静默时段。',
    parameters: [
      ToolParameter(name: 'topic_id', description: '话题 ID', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'channels', description: '通知渠道列表', type: ToolParameterType.arrayType),
      ToolParameter(name: 'major_threshold', description: '重大事件阈值（0-1）', type: ToolParameterType.doubleType, minValue: 0, maxValue: 1),
      ToolParameter(name: 'webhook_url', description: 'Webhook URL', type: ToolParameterType.stringType),
      ToolParameter(name: 'email_address', description: '通知邮箱', type: ToolParameterType.stringType),
      ToolParameter(name: 'quiet_start', description: '静默开始时间（HH:mm）', type: ToolParameterType.stringType),
      ToolParameter(name: 'quiet_end', description: '静默结束时间（HH:mm）', type: ToolParameterType.stringType),
    ],
    timeoutMs: 10000,
    execute: _executeConfigureNotification,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('话题追踪技能初始化');

    // 从持久化存储加载话题数据
    final savedTopics = await context.storage.get('tracking_topics');
    if (savedTopics != null) {
      try {
        final topicsList = jsonDecode(savedTopics) as List;
        for (final t in topicsList) {
          final topic = TrackingTopic.fromJson(t as Map<String, dynamic>);
          _topics[topic.id] = topic;
        }
        context.logger.info('已加载 ${_topics.length} 个追踪话题');
      } catch (e) {
        context.logger.error('加载话题数据失败', e);
      }
    }

    // 加载追踪数据
    final savedItems = await context.storage.get('tracking_items');
    if (savedItems != null) {
      try {
        final itemsMap = jsonDecode(savedItems) as Map<String, dynamic>;
        for (final entry in itemsMap.entries) {
          _trackedItems[entry.key] = (entry.value as List)
              .map((i) => TrackedItem.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        context.logger.error('加载追踪数据失败', e);
      }
    }
  }

  @override
  Future<void> onDispose() async {
    _topics.clear();
    _trackedItems.clear();
    _briefings.clear();
  }

  // ============================================================================
  // 持久化辅助
  // ============================================================================

  Future<void> _saveTopics(SkillContext context) async {
    final json = jsonEncode(_topics.values.map((t) => t.toJson()).toList());
    await context.storage.set('tracking_topics', json);
  }

  Future<void> _saveTrackedItems(SkillContext context) async {
    final json = jsonEncode(_trackedItems.map((k, v) => MapEntry(k, v.map((i) => i.toJson()).toList())));
    await context.storage.set('tracking_items', json);
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  Future<ToolResult> _executeStartTracking(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicName = args['topic_name'] as String;
    final description = args['description'] as String? ?? '';
    final tags = (args['tags'] as List?)?.cast<String>() ?? [];
    final group = args['group'] as String? ?? 'default';
    final priorityStr = args['priority'] as String? ?? 'medium';
    final sourcesData = args['sources'] as List?;
    final dailyBriefing = args['daily_briefing'] as bool? ?? true;
    final realtimeNotify = args['realtime_notify'] as bool? ?? true;

    context.logger.info('开始追踪话题: $topicName');

    // 检查是否已存在同名话题
    final existing = _topics.values.where((t) => t.name == topicName && t.status == TopicStatus.active);
    if (existing.isNotEmpty) {
      return ToolResult.failure(
        error: '已存在同名活跃话题: $topicName (ID: ${existing.first.id})',
        errorCode: 'DUPLICATE_TOPIC',
      );
    }

    // 生成话题 ID
    final topicId = 'topic_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    // 解析信息源
    final sources = <TrackingSource>[];
    if (sourcesData != null) {
      for (int i = 0; i < sourcesData.length; i++) {
        final s = sourcesData[i] as Map<String, dynamic>;
        sources.add(TrackingSource(
          id: 'src_${topicId}_$i',
          name: s['name'] as String? ?? '源 ${i + 1}',
          type: SourceType.values.firstWhere(
            (t) => t.value == s['type'],
            orElse: () => SourceType.rss,
          ),
          url: s['url'] as String? ?? '',
          config: s['config'] as Map<String, dynamic>? ?? {},
        ));
      }
    }

    // 如果没有指定信息源，自动创建默认源
    if (sources.isEmpty) {
      sources.addAll(_buildDefaultSources(topicId, topicName));
    }

    final topic = TrackingTopic(
      id: topicId,
      name: topicName,
      description: description,
      tags: tags,
      group: group,
      priority: TopicPriority.values.firstWhere(
        (p) => p.value == priorityStr,
        orElse: () => TopicPriority.medium,
      ),
      sources: sources,
      frequency: BriefingFrequency(
        dailyEnabled: dailyBriefing,
        realtimeEnabled: realtimeNotify,
      ),
      createdAt: DateTime.now(),
    );

    _topics[topicId] = topic;
    _trackedItems[topicId] = [];

    // 持久化
    await _saveTopics(context);

    final sourceSummary = sources.map((s) => '  - ${s.name} (${s.type.value}): ${s.url}').join('\n');

    return ToolResult.success(
      content: '话题追踪已启动: $topicName\n'
          '话题 ID: $topicId\n'
          '优先级: $priorityStr\n'
          '信息源: ${sources.length} 个\n'
          '每日简报: ${dailyBriefing ? "已启用" : "未启用"}\n'
          '实时通知: ${realtimeNotify ? "已启用" : "未启用"}\n'
          '\n信息源详情:\n$sourceSummary',
      data: {
        'topic_id': topicId,
        'topic_name': topicName,
        'priority': priorityStr,
        'source_count': sources.length,
        'daily_briefing': dailyBriefing,
        'realtime_notify': realtimeNotify,
      },
    );
  }

  Future<ToolResult> _executeStopTracking(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;
    final action = args['action'] as String? ?? 'pause';

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    final newStatus = switch (action) {
      'archive' => TopicStatus.archived,
      'delete' => null,
      _ => TopicStatus.paused,
    };

    if (newStatus == null) {
      _topics.remove(topicId);
      _trackedItems.remove(topicId);
      _briefings.remove(topicId);
      await _saveTopics(context);
      await _saveTrackedItems(context);
      return ToolResult.success(
        content: '话题已删除: ${topic.name}',
        data: {'topic_id': topicId, 'action': 'delete'},
      );
    }

    _topics[topicId] = topic.copyWith(status: newStatus);
    await _saveTopics(context);

    final actionName = action == 'archive' ? '已归档' : '已暂停';

    return ToolResult.success(
      content: '话题$actionName: ${topic.name} (ID: $topicId)',
      data: {'topic_id': topicId, 'action': action, 'status': newStatus.value},
    );
  }

  Future<ToolResult> _executeGetBriefing(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;
    final type = args['type'] as String? ?? 'latest';
    final includeEvents = args['include_events'] as bool? ?? true;
    final maxEvents = args['max_events'] as int? ?? 10;

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    context.logger.info('生成简报: ${topic.name} (类型: $type)');
    context.onProgress?.call(0.1, '正在收集追踪数据...');

    // 获取追踪到的数据
    final items = _trackedItems[topicId] ?? [];

    // 按时间范围过滤
    final now = DateTime.now();
    final dateRange = switch (type) {
      'daily' => now.subtract(const Duration(days: 1)),
      'weekly' => now.subtract(const Duration(days: 7)),
      _ => DateTime(2020), // latest: 全部
    };

    final filteredItems = items.where((i) => i.fetchedAt.isAfter(dateRange)).toList();
    filteredItems.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));

    context.onProgress?.call(0.4, '正在生成 AI 摘要...');

    // 构建简报
    final keyEvents = filteredItems.take(maxEvents).toList();
    final majorEvents = filteredItems.where((i) => i.isMajor).toList();

    // AI 摘要（通过调用 LLM 生成）
    String aiSummary;
    if (filteredItems.isEmpty) {
      aiSummary = '近期暂无新动态。';
    } else {
      aiSummary = _generateBriefingSummary(topic, filteredItems, majorEvents);
    }

    // 趋势分析
    String? trendAnalysis;
    if (filteredItems.length >= 3) {
      trendAnalysis = _generateTrendAnalysis(filteredItems);
    }

    context.onProgress?.call(0.9, '简报生成完成');

    final briefingTitle = switch (type) {
      'daily' => '${topic.name} - 每日简报 (${_formatDate(now)})',
      'weekly' => '${topic.name} - 每周简报 (${_formatDate(now)})',
      _ => '${topic.name} - 最新简报',
    };

    // 保存简报
    final briefing = Briefing(
      id: 'briefing_${DateTime.now().millisecondsSinceEpoch}',
      topicId: topicId,
      title: briefingTitle,
      type: type,
      aiSummary: aiSummary,
      keyEvents: keyEvents,
      trendAnalysis: trendAnalysis,
      createdAt: now,
      itemCount: filteredItems.length,
    );

    _briefings.putIfAbsent(topicId, () => []);
    _briefings[topicId]!.insert(0, briefing);

    // 格式化输出
    final buffer = StringBuffer();
    buffer.writeln('# $briefingTitle');
    buffer.writeln();
    buffer.writeln('## 📊 概览');
    buffer.writeln('- 追踪时间范围内共 **${filteredItems.length}** 条动态');
    buffer.writeln('- 其中重大事件 **${majorEvents.length}** 条');
    buffer.writeln();
    buffer.writeln('## 🤖 AI 摘要');
    buffer.writeln(aiSummary);
    buffer.writeln();

    if (trendAnalysis != null) {
      buffer.writeln('## 📈 趋势分析');
      buffer.writeln(trendAnalysis);
      buffer.writeln();
    }

    if (includeEvents && keyEvents.isNotEmpty) {
      buffer.writeln('## 🔑 关键事件');
      buffer.writeln();
      for (int i = 0; i < keyEvents.length; i++) {
        final event = keyEvents[i];
        final importance = (event.importanceScore * 100).toInt();
        buffer.writeln('### ${i + 1}. ${event.title}');
        buffer.writeln('来源: ${event.sourceName} | 重要性: $importance%');
        if (event.summary.isNotEmpty) buffer.writeln(event.summary);
        if (event.url.isNotEmpty) buffer.writeln('链接: ${event.url}');
        buffer.writeln();
      }
    }

    return ToolResult.success(
      content: buffer.toString().trim(),
      data: {
        'briefing_id': briefing.id,
        'topic_id': topicId,
        'topic_name': topic.name,
        'type': type,
        'total_items': filteredItems.length,
        'major_items': majorEvents.length,
        'key_events_count': keyEvents.length,
      },
    );
  }

  Future<ToolResult> _executeUpdateSources(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;
    final action = args['action'] as String;
    final sourceData = args['source'] as Map<String, dynamic>?;
    final sourceId = args['source_id'] as String?;

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    final currentSources = List<TrackingSource>.from(topic.sources);

    switch (action) {
      case 'add':
        if (sourceData == null) {
          return ToolResult.failure(error: 'add 操作需要 source 参数', errorCode: 'MISSING_PARAM');
        }
        final newSource = TrackingSource(
          id: 'src_${topicId}_${currentSources.length}',
          name: sourceData['name'] as String? ?? '新信息源',
          type: SourceType.values.firstWhere(
            (t) => t.value == sourceData['type'],
            orElse: () => SourceType.rss,
          ),
          url: sourceData['url'] as String? ?? '',
          config: sourceData['config'] as Map<String, dynamic>? ?? {},
        );
        currentSources.add(newSource);
        _topics[topicId] = topic.copyWith(sources: currentSources);

      case 'remove':
        if (sourceId == null) {
          return ToolResult.failure(error: 'remove 操作需要 source_id', errorCode: 'MISSING_PARAM');
        }
        currentSources.removeWhere((s) => s.id == sourceId);
        _topics[topicId] = topic.copyWith(sources: currentSources);

      case 'enable':
      case 'disable':
        if (sourceId == null) {
          return ToolResult.failure(error: '$action 操作需要 source_id', errorCode: 'MISSING_PARAM');
        }
        final idx = currentSources.indexWhere((s) => s.id == sourceId);
        if (idx == -1) {
          return ToolResult.failure(error: '未找到信息源: $sourceId', errorCode: 'SOURCE_NOT_FOUND');
        }
        final old = currentSources[idx];
        currentSources[idx] = TrackingSource(
          id: old.id,
          name: old.name,
          type: old.type,
          url: old.url,
          enabled: action == 'enable',
          refreshIntervalMinutes: old.refreshIntervalMinutes,
          config: old.config,
          lastFetchedAt: old.lastFetchedAt,
        );
        _topics[topicId] = topic.copyWith(sources: currentSources);

      case 'update':
        if (sourceId == null || sourceData == null) {
          return ToolResult.failure(error: 'update 操作需要 source_id 和 source', errorCode: 'MISSING_PARAM');
        }
        final idx = currentSources.indexWhere((s) => s.id == sourceId);
        if (idx == -1) {
          return ToolResult.failure(error: '未找到信息源: $sourceId', errorCode: 'SOURCE_NOT_FOUND');
        }
        final old = currentSources[idx];
        currentSources[idx] = TrackingSource(
          id: old.id,
          name: sourceData['name'] as String? ?? old.name,
          type: SourceType.values.firstWhere(
            (t) => t.value == (sourceData['type'] ?? old.type.value),
            orElse: () => old.type,
          ),
          url: sourceData['url'] as String? ?? old.url,
          enabled: old.enabled,
          refreshIntervalMinutes: (sourceData['refresh_interval'] as int?) ?? old.refreshIntervalMinutes,
          config: sourceData['config'] as Map<String, dynamic>? ?? old.config,
        );
        _topics[topicId] = topic.copyWith(sources: currentSources);

      default:
        return ToolResult.failure(error: '未知操作: $action', errorCode: 'UNKNOWN_ACTION');
    }

    await _saveTopics(context);

    return ToolResult.success(
      content: '信息源已更新: ${topic.name}\n当前共 ${currentSources.length} 个信息源',
      data: {'topic_id': topicId, 'action': action, 'source_count': currentSources.length},
    );
  }

  Future<ToolResult> _executeSetFrequency(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    final old = topic.frequency;
    final newFreq = BriefingFrequency(
      dailyEnabled: args['daily_enabled'] as bool? ?? old.dailyEnabled,
      dailyTime: args['daily_time'] as String? ?? old.dailyTime,
      weeklyEnabled: args['weekly_enabled'] as bool? ?? old.weeklyEnabled,
      weeklyDay: args['weekly_day'] as int? ?? old.weeklyDay,
      weeklyTime: args['weekly_time'] as String? ?? old.weeklyTime,
      realtimeEnabled: args['realtime_enabled'] as bool? ?? old.realtimeEnabled,
    );

    _topics[topicId] = topic.copyWith(frequency: newFreq);
    await _saveTopics(context);

    final freqDesc = StringBuffer();
    if (newFreq.dailyEnabled) freqDesc.writeln('- 每日简报: ${newFreq.dailyTime}');
    if (newFreq.weeklyEnabled) freqDesc.writeln('- 每周简报: 周${newFreq.weeklyDay} ${newFreq.weeklyTime}');
    if (newFreq.realtimeEnabled) freqDesc.writeln('- 实时通知: 已启用');

    return ToolResult.success(
      content: '简报频率已更新: ${topic.name}\n${freqDesc.toString().trim()}',
      data: {'topic_id': topicId, 'frequency': newFreq.toJson()},
    );
  }

  Future<ToolResult> _executeExportReport(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;
    final format = args['format'] as String? ?? 'markdown';
    final dateRange = args['date_range'] as int? ?? 7;
    final includeSummary = args['include_summary'] as bool? ?? true;
    final includeTrend = args['include_trend'] as bool? ?? true;
    final savePath = args['save_path'] as String?;

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    context.logger.info('导出报告: ${topic.name} (格式: $format)');
    context.onProgress?.call(0.1, '正在收集数据...');

    final items = _trackedItems[topicId] ?? [];
    final cutoff = DateTime.now().subtract(Duration(days: dateRange));
    final filteredItems = items.where((i) => i.fetchedAt.isAfter(cutoff)).toList();
    filteredItems.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));

    context.onProgress?.call(0.4, '正在生成报告...');

    final fileName = savePath ?? '${topic.name}_报告_${_formatDate(DateTime.now())}.${_fileExtension(format)}';

    String content;
    switch (format) {
      case 'json':
        content = jsonEncode({
          'topic': topic.toJson(),
          'period_days': dateRange,
          'items': filteredItems.map((i) => i.toJson()).toList(),
          'exported_at': DateTime.now().toIso8601String(),
        });
      case 'markdown':
      default:
        final buffer = StringBuffer();
        buffer.writeln('# ${topic.name} - 追踪报告');
        buffer.writeln();
        buffer.writeln('> 生成时间: ${_formatDateTime(DateTime.now())}');
        buffer.writeln('> 数据范围: 近 $dateRange 天');
        buffer.writeln('> 动态总数: ${filteredItems.length}');
        buffer.writeln();

        if (includeSummary) {
          final majorEvents = filteredItems.where((i) => i.isMajor).toList();
          buffer.writeln('## AI 摘要');
          buffer.writeln();
          if (filteredItems.isEmpty) {
            buffer.writeln('近 $dateRange 天无新动态。');
          } else {
            buffer.writeln(_generateBriefingSummary(topic, filteredItems, majorEvents));
          }
          buffer.writeln();
        }

        if (includeTrend && filteredItems.length >= 3) {
          buffer.writeln('## 趋势分析');
          buffer.writeln();
          buffer.writeln(_generateTrendAnalysis(filteredItems));
          buffer.writeln();
        }

        buffer.writeln('## 详细动态');
        buffer.writeln();
        for (final item in filteredItems) {
          buffer.writeln('### ${item.title}');
          buffer.writeln('- 来源: ${item.sourceName}');
          buffer.writeln('- 时间: ${item.publishedAt != null ? _formatDateTime(item.publishedAt!) : "未知"}');
          buffer.writeln('- 重要性: ${(item.importanceScore * 100).toInt()}%');
          if (item.isMajor) buffer.writeln('- ⚠️ **重大事件**');
          if (item.summary.isNotEmpty) buffer.writeln(item.summary);
          if (item.url.isNotEmpty) buffer.writeln('- 链接: ${item.url}');
          buffer.writeln();
        }

        content = buffer.toString();
    }

    context.onProgress?.call(0.9, '报告生成完成');

    // 保存到存储
    await context.storage.set('report_${topicId}_latest', content);

    return ToolResult.success(
      content: '报告已导出: $fileName\n格式: $format\n包含 ${filteredItems.length} 条动态',
      data: {
        'topic_id': topicId,
        'file_path': fileName,
        'format': format,
        'item_count': filteredItems.length,
        'period_days': dateRange,
      },
    );
  }

  Future<ToolResult> _executeSearchHistory(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final query = args['query'] as String;
    final topicId = args['topic_id'] as String?;
    final dateFrom = args['date_from'] as String?;
    final dateTo = args['date_to'] as String?;
    final minImportance = (args['min_importance'] as num?)?.toDouble();
    final maxResults = args['max_results'] as int? ?? 20;

    context.logger.info('搜索历史: "$query"');

    final results = <TrackedItem>[];
    final queryLower = query.toLowerCase();

    // 确定搜索范围
    final searchTopics = topicId != null
        ? [_topics[topicId]].whereType<TrackingTopic>()
        : _topics.values;

    for (final topic in searchTopics) {
      final items = _trackedItems[topic.id] ?? [];
      for (final item in items) {
        // 文本匹配
        final matchesQuery = item.title.toLowerCase().contains(queryLower) ||
            item.summary.toLowerCase().contains(queryLower) ||
            item.sourceName.toLowerCase().contains(queryLower) ||
            item.tags.any((t) => t.toLowerCase().contains(queryLower));
        if (!matchesQuery) continue;

        // 日期过滤
        if (dateFrom != null) {
          final from = DateTime.tryParse(dateFrom);
          if (from != null && item.fetchedAt.isBefore(from)) continue;
        }
        if (dateTo != null) {
          final to = DateTime.tryParse(dateTo);
          if (to != null && item.fetchedAt.isAfter(to)) continue;
        }

        // 重要性过滤
        if (minImportance != null && item.importanceScore < minImportance) continue;

        results.add(item);
      }
    }

    // 按相关性排序（简单实现：标题匹配优先）
    results.sort((a, b) {
      final aTitleMatch = a.title.toLowerCase().contains(queryLower) ? 1 : 0;
      final bTitleMatch = b.title.toLowerCase().contains(queryLower) ? 1 : 0;
      if (aTitleMatch != bTitleMatch) return bTitleMatch - aTitleMatch;
      return b.importanceScore.compareTo(a.importanceScore);
    });

    final limitedResults = results.take(maxResults).toList();

    if (limitedResults.isEmpty) {
      return ToolResult.success(
        content: '未找到与 "$query" 匹配的历史记录',
        data: {'query': query, 'result_count': 0},
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('找到 ${results.length} 条匹配记录（显示前 ${limitedResults.length} 条）:');
    buffer.writeln();

    for (int i = 0; i < limitedResults.length; i++) {
      final item = limitedResults[i];
      final topicName = _topics[item.topicId]?.name ?? '未知话题';
      buffer.writeln('**${i + 1}. ${item.title}**');
      buffer.writeln('   话题: $topicName | 来源: ${item.sourceName}');
      buffer.writeln('   时间: ${_formatDateTime(item.fetchedAt)} | 重要性: ${(item.importanceScore * 100).toInt()}%');
      if (item.summary.isNotEmpty) buffer.writeln('   ${item.summary}');
      if (item.url.isNotEmpty) buffer.writeln('   链接: ${item.url}');
      buffer.writeln();
    }

    return ToolResult.success(
      content: buffer.toString().trim(),
      data: {
        'query': query,
        'total_matches': results.length,
        'returned': limitedResults.length,
      },
    );
  }

  Future<ToolResult> _executeConfigureNotification(
    Map<String, dynamic> args, SkillContext context,
  ) async {
    final topicId = args['topic_id'] as String;

    final topic = _topics[topicId];
    if (topic == null) {
      return ToolResult.failure(error: '未找到话题: $topicId', errorCode: 'TOPIC_NOT_FOUND');
    }

    final old = topic.notification;
    final channels = args['channels'] as List?;

    final parsedChannels = channels != null
        ? channels.map((c) {
            return NotificationChannel.values.firstWhere(
              (ch) => ch.value == c,
              orElse: () => NotificationChannel.appPush,
            );
          }).toList()
        : old.channels;

    final newConfig = NotificationConfig(
      channels: parsedChannels,
      majorThreshold: (args['major_threshold'] as num?)?.toDouble() ?? old.majorThreshold,
      webhookUrl: args['webhook_url'] as String? ?? old.webhookUrl,
      emailAddress: args['email_address'] as String? ?? old.emailAddress,
      quietStart: args['quiet_start'] as String? ?? old.quietStart,
      quietEnd: args['quiet_end'] as String? ?? old.quietEnd,
    );

    _topics[topicId] = topic.copyWith(notification: newConfig);
    await _saveTopics(context);

    final channelDesc = newConfig.channels.map((c) => c.value).join(', ');

    return ToolResult.success(
      content: '通知配置已更新: ${topic.name}\n'
          '通知渠道: $channelDesc\n'
          '重大事件阈值: ${(newConfig.majorThreshold * 100).toInt()}%\n'
          '${newConfig.quietStart != null ? "静默时段: ${newConfig.quietStart} - ${newConfig.quietEnd}" : ""}',
      data: {'topic_id': topicId, 'notification': newConfig.toJson()},
    );
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 根据话题名称自动构建默认信息源
  List<TrackingSource> _buildDefaultSources(String topicId, String topicName) {
    final sources = <TrackingSource>[];

    // RSS: Google News
    sources.add(TrackingSource(
      id: 'src_${topicId}_0',
      name: 'Google News - $topicName',
      type: SourceType.rss,
      url: 'https://news.google.com/rss/search?q=${Uri.encodeComponent(topicName)}&hl=zh-CN',
    ));

    // 学术搜索
    sources.add(TrackingSource(
      id: 'src_${topicId}_1',
      name: '学术搜索 - $topicName',
      type: SourceType.academicSearch,
      url: topicName,
      config: {'engine': 'scholar'},
    ));

    return sources;
  }

  /// 生成简报摘要
  String _generateBriefingSummary(
    TrackingTopic topic,
    List<TrackedItem> items,
    List<TrackedItem> majorEvents,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('围绕「${topic.name}」话题，近期共追踪到 **${items.length}** 条动态');

    if (majorEvents.isNotEmpty) {
      buffer.writeln('，其中 **${majorEvents.length}** 条为重大事件。');
    } else {
      buffer.writeln('。');
    }

    if (items.isNotEmpty) {
      final topItems = items.take(3).toList();
      buffer.writeln('最受关注的动态包括:');
      for (final item in topItems) {
        buffer.writeln('- ${item.title}');
      }
    }

    // 来源分布
    final sourceCounts = <String, int>{};
    for (final item in items) {
      sourceCounts[item.sourceName] = (sourceCounts[item.sourceName] ?? 0) + 1;
    }
    if (sourceCounts.isNotEmpty) {
      buffer.writeln();
      buffer.write('信息来源分布: ');
      buffer.write(sourceCounts.entries
          .map((e) => '${e.key}(${e.value}条)')
          .join('、'));
      buffer.writeln('。');
    }

    return buffer.toString().trim();
  }

  /// 生成趋势分析
  String _generateTrendAnalysis(List<TrackedItem> items) {
    if (items.length < 3) return '数据不足，暂无法分析趋势。';

    final buffer = StringBuffer();

    // 时间分布
    final dayCounts = <String, int>{};
    for (final item in items) {
      final day = '${item.fetchedAt.month}/${item.fetchedAt.day}';
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    final sortedDays = dayCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxDay = sortedDays.reduce((a, b) => a.value > b.value ? a : b);

    buffer.writeln('- 信息高峰: **$maxDay** (${maxDay.value} 条)');

    // 重要性分布
    final avgImportance = items.map((i) => i.importanceScore).reduce((a, b) => a + b) / items.length;
    buffer.writeln('- 平均重要性: **${(avgImportance * 100).toInt()}%**');

    final majorRatio = items.where((i) => i.isMajor).length / items.length;
    if (majorRatio > 0.3) {
      buffer.writeln('- 近期重大事件占比较高 (${(majorRatio * 100).toInt()}%)，建议持续关注');
    }

    // 标签热度
    final tagCounts = <String, int>{};
    for (final item in items) {
      for (final tag in item.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    if (tagCounts.isNotEmpty) {
      final topTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3 = topTags.take(3).map((e) => '${e.key}(${e.value})').join('、');
      buffer.writeln('- 热门标签: $top3');
    }

    return buffer.toString().trim();
  }

  /// 格式化日期
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 获取文件扩展名
  String _fileExtension(String format) {
    return switch (format) {
      'markdown' => 'md',
      'pdf' => 'pdf',
      'word' => 'docx',
      'json' => 'json',
      _ => 'txt',
    };
  }
}

// ============================================================================
// 配置
// ============================================================================

/// 话题追踪技能配置
class TrackingSkillConfig {
  /// 数据持久化路径
  final String storagePath;

  /// 默认刷新间隔（分钟）
  final int defaultRefreshIntervalMinutes;

  /// 最大缓存条目数（每个话题）
  final int maxItemsPerTopic;

  /// 简报保留天数
  final int briefingRetentionDays;

  /// 重大事件判定阈值
  final double defaultMajorThreshold;

  /// LLM API 端点（用于 AI 摘要生成）
  final String llmEndpoint;

  /// LLM API Key
  final String llmApiKey;

  const TrackingSkillConfig({
    this.storagePath = '',
    this.defaultRefreshIntervalMinutes = 60,
    this.maxItemsPerTopic = 1000,
    this.briefingRetentionDays = 90,
    this.defaultMajorThreshold = 0.8,
    this.llmEndpoint = '',
    this.llmApiKey = '',
  });
}

// ============================================================================
// 小酥 - Coze Studio 任务/日程模型
// Phase 6: 对接 Coze Studio 任务调度 API
// ============================================================================

/// 日程状态
enum CozeEventStatus {
  pending,   // 待执行
  completed, // 已完成
  cancelled, // 已取消
}

/// Coze Studio 日程事件模型
class CozeCalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? reminder;
  final CozeEventStatus status;
  final String? botId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CozeCalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.reminder,
    this.status = CozeEventStatus.pending,
    this.botId,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory CozeCalendarEvent.fromJson(Map<String, dynamic> json) {
    return CozeCalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      reminder: json['reminder'] as String?,
      status: CozeEventStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CozeEventStatus.pending,
      ),
      botId: json['bot_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'reminder': reminder,
        'status': status.name,
        'bot_id': botId,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  CozeCalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? reminder,
    CozeEventStatus? status,
    String? botId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CozeCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reminder: reminder ?? this.reminder,
      status: status ?? this.status,
      botId: botId ?? this.botId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

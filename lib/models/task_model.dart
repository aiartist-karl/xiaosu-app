// ============================================================================
// 小酥 (XiaoSu) - 任务模型
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'task_model.g.dart';

/// 任务类型枚举
enum TaskType {
  /// 一次性定时任务
  oneTime('one_time'),
  /// 周期重复任务
  periodic('periodic'),
  /// 话题追踪任务
  topicTrack('topic_track');

  final String value;
  const TaskType(this.value);
}

/// 任务状态枚举
enum TaskStatus {
  /// 已调度（等待执行）
  scheduled('scheduled'),
  /// 执行中
  running('running'),
  /// 已完成（一次性任务）
  completed('completed'),
  /// 已暂停
  paused('paused'),
  /// 已取消
  cancelled('cancelled'),
  /// 执行失败
  failed('failed');

  final String value;
  const TaskStatus(this.value);
}

/// 调度任务模型
@JsonSerializable()
class ScheduledTask {
  /// 任务唯一 ID
  final String id;

  /// 任务标题
  final String title;

  /// 任务类型
  final TaskType type;

  /// 执行时的提示词
  final String prompt;

  /// 计划执行时间
  final DateTime executeAt;

  /// 周期任务的间隔（秒）
  @Default(null)
  final int? intervalSeconds;

  /// 关联的对话 ID
  @Default('')
  final String conversationId;

  /// 任务状态
  final TaskStatus status;

  /// 附加元数据
  @Default(null)
  final Map<String, dynamic>? metadata;

  /// 创建时间
  final DateTime createdAt;

  /// 最后执行时间
  @Default(null)
  final DateTime? lastExecutedAt;

  /// 执行次数
  @Default(0)
  final int executionCount;

  /// 最后错误信息
  @Default('')
  final String lastError;

  const ScheduledTask({
    required this.id,
    required this.title,
    required this.type,
    required this.prompt,
    required this.executeAt,
    this.intervalSeconds,
    this.conversationId = '',
    required this.status,
    this.metadata,
    required this.createdAt,
    this.lastExecutedAt,
    this.executionCount = 0,
    this.lastError = '',
  });

  /// 任务是否处于活跃状态
  bool get isActive =>
      status == TaskStatus.scheduled || status == TaskStatus.running;

  factory ScheduledTask.fromJson(Map<String, dynamic> json) =>
      _$ScheduledTaskFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledTaskToJson(this);

  ScheduledTask copyWith({
    String? id,
    String? title,
    TaskType? type,
    String? prompt,
    DateTime? executeAt,
    int? intervalSeconds,
    String? conversationId,
    TaskStatus? status,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? lastExecutedAt,
    int? executionCount,
    String? lastError,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      executeAt: executeAt ?? this.executeAt,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      conversationId: conversationId ?? this.conversationId,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      executionCount: executionCount ?? this.executionCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

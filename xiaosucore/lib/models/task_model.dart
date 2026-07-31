// ============================================================================
// 小酥 - 任务模型
// ============================================================================

import 'package:equatable/equatable.dart';

/// 任务类型
enum TaskType {
  scheduled,      // 定时任务
  topicTracking,  // 话题追踪
  reminder,       // 提醒
  workflow,       // 工作流
  custom,         // 自定义
}

/// 任务状态
enum TaskStatus {
  idle,       // 空闲
  running,    // 运行中
  paused,     // 已暂停
  completed,  // 已完成
  failed,     // 失败
  cancelled,  // 已取消
}

/// 任务模型
class TaskModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final TaskType type;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? lastExecutedAt;
  final int executionCount;
  final String? lastError;
  final String? lastResult;
  final Duration? interval;      // 执行间隔
  final DateTime? nextExecutionAt; // 下次执行时间
  final Map<String, dynamic> config; // 任务配置
  final Map<String, dynamic>? metadata;

  const TaskModel({
    required this.id,
    required this.name,
    this.description = '',
    this.type = TaskType.custom,
    this.status = TaskStatus.idle,
    required this.createdAt,
    this.lastExecutedAt,
    this.executionCount = 0,
    this.lastError,
    this.lastResult,
    this.interval,
    this.nextExecutionAt,
    this.config = const {},
    this.metadata,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: TaskType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TaskType.custom,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.idle,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String) : null,
      executionCount: json['executionCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      lastResult: json['lastResult'] as String?,
      interval: json['intervalMs'] != null
          ? Duration(milliseconds: json['intervalMs'] as int) : null,
      nextExecutionAt: json['nextExecutionAt'] != null
          ? DateTime.parse(json['nextExecutionAt'] as String) : null,
      config: (json['config'] as Map<String, dynamic>?) ?? {},
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'type': type.name, 'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'lastExecutedAt': lastExecutedAt?.toIso8601String(),
    'executionCount': executionCount,
    'lastError': lastError, 'lastResult': lastResult,
    'intervalMs': interval?.inMilliseconds,
    'nextExecutionAt': nextExecutionAt?.toIso8601String(),
    'config': config, 'metadata': metadata,
  };

  TaskModel copyWith({
    String? id, String? name, String? description, TaskType? type,
    TaskStatus? status, DateTime? createdAt, DateTime? lastExecutedAt,
    int? executionCount, String? lastError, String? lastResult,
    Duration? interval, DateTime? nextExecutionAt,
    Map<String, dynamic>? config, Map<String, dynamic>? metadata,
  }) {
    return TaskModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      executionCount: executionCount ?? this.executionCount,
      lastError: lastError ?? this.lastError,
      lastResult: lastResult ?? this.lastResult,
      interval: interval ?? this.interval,
      nextExecutionAt: nextExecutionAt ?? this.nextExecutionAt,
      config: config ?? this.config,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, name, type, status];
}

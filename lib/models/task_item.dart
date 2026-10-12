import 'package:flutter/material.dart';
import '../core/constants/plan_colors.dart';

class TaskItem {
  final String id;
  final String userId;
  final String title;
  final String? notes;
  final String projectId;
  final int estimatedMinutes;
  final String priority; // 'none', 'low', 'medium', 'urgent'
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;

  // Subtask linking:
  final String? parentTaskId;

  // Time-blocking fields:
  final bool isTimeBlocked;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  const TaskItem({
    required this.id,
    this.userId = '',
    required this.title,
    this.notes,
    required this.projectId,
    this.estimatedMinutes = 30,
    this.priority = 'none',
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.parentTaskId,
    this.isTimeBlocked = false,
    this.scheduledStart,
    this.scheduledEnd,
  });

  bool get isSubtask => parentTaskId != null && parentTaskId!.isNotEmpty;

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return PlanColors.priorityUrgent;
      case 'high':
        return PlanColors.priorityHigh;
      case 'medium':
        return PlanColors.priorityMedium;
      case 'low':
      case 'none':
      default:
        return PlanColors.priorityLow;
    }
  }

  TaskItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    String? projectId,
    int? estimatedMinutes,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    String? parentTaskId,
    bool clearParentTaskId = false,
    bool? isTimeBlocked,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool clearScheduledTimes = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      projectId: projectId ?? this.projectId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      parentTaskId: clearParentTaskId ? null : (parentTaskId ?? this.parentTaskId),
      isTimeBlocked: clearScheduledTimes ? false : (isTimeBlocked ?? this.isTimeBlocked),
      scheduledStart: clearScheduledTimes ? null : (scheduledStart ?? this.scheduledStart),
      scheduledEnd: clearScheduledTimes ? null : (scheduledEnd ?? this.scheduledEnd),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'notes': notes,
      'projectId': projectId,
      'estimatedMinutes': estimatedMinutes,
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'parentTaskId': parentTaskId,
      'isTimeBlocked': isTimeBlocked,
      'scheduledStart': scheduledStart?.toIso8601String(),
      'scheduledEnd': scheduledEnd?.toIso8601String(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      projectId: json['projectId'] as String? ?? '',
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
      priority: json['priority'] as String? ?? 'none',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      parentTaskId: json['parentTaskId'] as String?,
      isTimeBlocked: json['isTimeBlocked'] as bool? ?? false,
      scheduledStart: json['scheduledStart'] != null ? DateTime.tryParse(json['scheduledStart'] as String) : null,
      scheduledEnd: json['scheduledEnd'] != null ? DateTime.tryParse(json['scheduledEnd'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

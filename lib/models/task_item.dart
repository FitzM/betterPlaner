import 'package:flutter/material.dart';
import '../core/constants/plan_colors.dart';
import '../core/utils/time_utils.dart';

class TaskItem {
  final String id;
  final String userId;
  final String title;
  final String? notes;
  final String projectId;
  final String? folderName;
  final String? listName;
  final int estimatedMinutes;
  final String priority; // 'none', 'low', 'medium', 'urgent'
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? createdAt;

  // Subtask linking:
  final String? parentTaskId;

  // Time-blocking fields:
  final bool isTimeBlocked;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  // TickTick-specific fields:
  final String kind; // 'TEXT', 'CHECKLIST', 'NOTE'
  final bool isChecklist;
  final List<String> tags;
  final bool isAllDay;
  final String? repeat;
  final String? reminder;
  final String? timezone;
  final String? columnName;
  final int? columnOrder;
  final int? sortOrder;
  final String? rawTaskId;
  final String? rawParentId;

  // Smart Filter Window ("Symlink Group") fields:
  final String? linkedProjectId;
  final String? linkedTag;
  final String? linkedSection;

  const TaskItem({
    required this.id,
    this.userId = '',
    required this.title,
    this.notes,
    required this.projectId,
    this.folderName,
    this.listName,
    this.estimatedMinutes = 30,
    this.priority = 'none',
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.createdAt,
    this.parentTaskId,
    this.isTimeBlocked = false,
    this.scheduledStart,
    this.scheduledEnd,
    this.kind = 'TEXT',
    this.isChecklist = false,
    this.tags = const [],
    this.isAllDay = false,
    this.repeat,
    this.reminder,
    this.timezone,
    this.columnName,
    this.columnOrder,
    this.sortOrder,
    this.rawTaskId,
    this.rawParentId,
    this.linkedProjectId,
    this.linkedTag,
    this.linkedSection,
  });

  bool get isSubtask => parentTaskId != null && parentTaskId!.isNotEmpty;

  bool get hasLinkedFilter =>
      (linkedProjectId != null && linkedProjectId!.isNotEmpty) ||
      (linkedTag != null && linkedTag!.isNotEmpty) ||
      (linkedSection != null && linkedSection!.isNotEmpty);

  /// Checks if this task belongs to the given calendar day
  bool isScheduledForDate(DateTime date) {
    if (scheduledStart != null && TimeUtils.isSameDay(scheduledStart!, date)) {
      return true;
    }
    if (dueDate != null && TimeUtils.isSameDay(dueDate!, date)) {
      return true;
    }
    return false;
  }

  /// Checks if this task is scheduled for the date without a specific time block (all-day / anytime)
  bool isAnytimeForDate(DateTime date) {
    if (!isScheduledForDate(date)) return false;
    return isAllDay || !isTimeBlocked || scheduledStart == null;
  }

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
    String? folderName,
    String? listName,
    int? estimatedMinutes,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    String? parentTaskId,
    bool clearParentTaskId = false,
    bool? isTimeBlocked,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool clearScheduledTimes = false,
    String? kind,
    bool? isChecklist,
    List<String>? tags,
    bool? isAllDay,
    String? repeat,
    String? reminder,
    String? timezone,
    String? columnName,
    int? columnOrder,
    int? sortOrder,
    String? rawTaskId,
    String? rawParentId,
    String? linkedProjectId,
    String? linkedTag,
    String? linkedSection,
    bool clearLinkedFilter = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      projectId: projectId ?? this.projectId,
      folderName: folderName ?? this.folderName,
      listName: listName ?? this.listName,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      parentTaskId: clearParentTaskId ? null : (parentTaskId ?? this.parentTaskId),
      isTimeBlocked: clearScheduledTimes ? false : (isTimeBlocked ?? this.isTimeBlocked),
      scheduledStart: clearScheduledTimes ? null : (scheduledStart ?? this.scheduledStart),
      scheduledEnd: clearScheduledTimes ? null : (scheduledEnd ?? this.scheduledEnd),
      kind: kind ?? this.kind,
      isChecklist: isChecklist ?? this.isChecklist,
      tags: tags ?? this.tags,
      isAllDay: isAllDay ?? this.isAllDay,
      repeat: repeat ?? this.repeat,
      reminder: reminder ?? this.reminder,
      timezone: timezone ?? this.timezone,
      columnName: columnName ?? this.columnName,
      columnOrder: columnOrder ?? this.columnOrder,
      sortOrder: sortOrder ?? this.sortOrder,
      rawTaskId: rawTaskId ?? this.rawTaskId,
      rawParentId: rawParentId ?? this.rawParentId,
      linkedProjectId: clearLinkedFilter ? null : (linkedProjectId ?? this.linkedProjectId),
      linkedTag: clearLinkedFilter ? null : (linkedTag ?? this.linkedTag),
      linkedSection: clearLinkedFilter ? null : (linkedSection ?? this.linkedSection),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      if (notes != null) 'notes': notes,
      'projectId': projectId,
      if (folderName != null) 'folderName': folderName,
      if (listName != null) 'listName': listName,
      'estimatedMinutes': estimatedMinutes,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (parentTaskId != null) 'parentTaskId': parentTaskId,
      'isTimeBlocked': isTimeBlocked,
      if (scheduledStart != null) 'scheduledStart': scheduledStart!.toIso8601String(),
      if (scheduledEnd != null) 'scheduledEnd': scheduledEnd!.toIso8601String(),
      'kind': kind,
      'isChecklist': isChecklist,
      if (tags.isNotEmpty) 'tags': tags,
      'isAllDay': isAllDay,
      if (repeat != null) 'repeat': repeat,
      if (reminder != null) 'reminder': reminder,
      if (timezone != null) 'timezone': timezone,
      if (columnName != null) 'columnName': columnName,
      if (columnOrder != null) 'columnOrder': columnOrder,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (rawTaskId != null) 'rawTaskId': rawTaskId,
      if (rawParentId != null) 'rawParentId': rawParentId,
      if (linkedProjectId != null) 'linkedProjectId': linkedProjectId,
      if (linkedTag != null) 'linkedTag': linkedTag,
      if (linkedSection != null) 'linkedSection': linkedSection,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      projectId: json['projectId'] as String? ?? '',
      folderName: json['folderName'] as String?,
      listName: json['listName'] as String?,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
      priority: json['priority'] as String? ?? 'none',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      parentTaskId: json['parentTaskId'] as String?,
      isTimeBlocked: json['isTimeBlocked'] as bool? ?? false,
      scheduledStart: json['scheduledStart'] != null ? DateTime.tryParse(json['scheduledStart'] as String) : null,
      scheduledEnd: json['scheduledEnd'] != null ? DateTime.tryParse(json['scheduledEnd'] as String) : null,
      kind: json['kind'] as String? ?? 'TEXT',
      isChecklist: json['isChecklist'] as bool? ?? false,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isAllDay: json['isAllDay'] as bool? ?? false,
      repeat: json['repeat'] as String?,
      reminder: json['reminder'] as String?,
      timezone: json['timezone'] as String?,
      columnName: json['columnName'] as String?,
      columnOrder: (json['columnOrder'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      rawTaskId: json['rawTaskId'] as String?,
      rawParentId: json['rawParentId'] as String?,
      linkedProjectId: json['linkedProjectId'] as String?,
      linkedTag: json['linkedTag'] as String?,
      linkedSection: json['linkedSection'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

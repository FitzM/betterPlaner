import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/time_utils.dart';
import '../models/task_item.dart';
import '../models/view_mode.dart';
import '../repositories/firestore_repository.dart';
import '../repositories/task_repository.dart';
import 'auth_provider.dart';
import 'project_providers.dart';

final localTaskRepositoryProvider = Provider<TaskRepository>((ref) {
  return LocalTaskRepository();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;

  if (user != null && !user.isDemo) {
    return FirestoreTaskRepository(userId: user.id);
  }
  return ref.watch(localTaskRepositoryProvider);
});

final tasksStreamProvider = StreamProvider<List<TaskItem>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchTasks();
});

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void setFilter(TaskFilter filter) => state = filter;
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

class TaskSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final taskSearchQueryProvider =
    NotifierProvider<TaskSearchQueryNotifier, String>(
        TaskSearchQueryNotifier.new);

/// Tasks filtered for display in the middle task pane
final filteredTasksProvider = Provider<List<TaskItem>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final selectedProjectId = ref.watch(selectedProjectIdProvider);
  final filter = ref.watch(taskFilterProvider);
  final query = ref.watch(taskSearchQueryProvider).toLowerCase().trim();

  return tasksAsync.maybeWhen(
    data: (tasks) {
      return tasks.where((task) {
        // Subtasks are rendered under their parent card, not as top-level cards
        if (task.isSubtask) return false;

        // Project filter
        if (selectedProjectId != null && task.projectId != selectedProjectId) {
          return false;
        }

        // Search query filter
        if (query.isNotEmpty) {
          final matchesTitle = task.title.toLowerCase().contains(query);
          final matchesNotes = task.notes?.toLowerCase().contains(query) ?? false;
          if (!matchesTitle && !matchesNotes) return false;
        }

        // Category filter
        switch (filter) {
          case TaskFilter.all:
            return true;
          case TaskFilter.today:
            if (task.scheduledStart != null && TimeUtils.isToday(task.scheduledStart!)) {
              return true;
            }
            if (task.dueDate != null && TimeUtils.isToday(task.dueDate!)) {
              return true;
            }
            return false;
          case TaskFilter.unscheduled:
            return !task.isTimeBlocked && !task.isCompleted;
          case TaskFilter.upcoming:
            if (task.scheduledStart == null && task.dueDate == null) return false;
            final targetDate = task.scheduledStart ?? task.dueDate!;
            final diff = targetDate.difference(DateTime.now()).inDays;
            return diff >= 0 && diff <= 7;
          case TaskFilter.completed:
            return task.isCompleted;
        }
      }).toList();
    },
    orElse: () => [],
  );
});

/// Unscheduled backlog tasks ready to be dragged onto the calendar
final unscheduledTasksProvider = Provider<List<TaskItem>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final selectedProjectId = ref.watch(selectedProjectIdProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) {
      return tasks.where((t) {
        if (t.isSubtask) return false;
        if (t.isCompleted || t.isTimeBlocked) return false;
        if (selectedProjectId != null && t.projectId != selectedProjectId) return false;
        return true;
      }).toList();
    },
    orElse: () => [],
  );
});

/// Tasks scheduled for a specific date at a specific time (hourly grid)
final scheduledTasksForDateFamily = Provider.family<List<TaskItem>, DateTime>((ref, date) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) {
      return tasks.where((t) {
        if (t.isSubtask) return false;
        if (!t.isTimeBlocked || t.isAllDay || t.scheduledStart == null) return false;
        return TimeUtils.isSameDay(t.scheduledStart!, date);
      }).toList();
    },
    orElse: () => [],
  );
});

/// Tasks set for a specific date without a specific time (All-Day / Anytime Today)
final anytimeTasksForDateFamily = Provider.family<List<TaskItem>, DateTime>((ref, date) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) {
      return tasks.where((t) {
        if (t.isSubtask) return false;
        return t.isAnytimeForDate(date);
      }).toList();
    },
    orElse: () => [],
  );
});

/// Live tasks matching a Smart Filter Window ("Symlink Group")
final filterWindowTasksProvider = Provider.family<List<TaskItem>, TaskItem>((ref, event) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) {
      if (!event.hasLinkedFilter) return const [];
      return tasks.where((t) {
        if (t.id == event.id) return false;
        if (t.isSubtask) return false;

        // Project filter
        if (event.linkedProjectId != null && event.linkedProjectId!.isNotEmpty) {
          if (t.projectId != event.linkedProjectId) return false;
        }

        // Tag filter
        if (event.linkedTag != null && event.linkedTag!.isNotEmpty) {
          if (!t.tags.contains(event.linkedTag)) return false;
        }

        // Section / Column filter
        if (event.linkedSection != null && event.linkedSection!.isNotEmpty) {
          if (t.columnName != event.linkedSection) return false;
        }

        return true;
      }).toList();
    },
    orElse: () => const [],
  );
});

class TaskController {
  final Ref ref;
  TaskController(this.ref);

  Future<TaskItem> addTask({
    required String title,
    String? notes,
    required String projectId,
    int estimatedMinutes = 30,
    String priority = 'none',
    DateTime? dueDate,
    String? parentTaskId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool isTimeBlocked = false,
    bool isAllDay = false,
    String? linkedProjectId,
    String? linkedTag,
    String? linkedSection,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final user = ref.read(authProvider).user;
    final task = TaskItem(
      id: 'task_${const Uuid().v4().substring(0, 8)}',
      userId: user?.id ?? '',
      title: title.trim(),
      notes: notes?.trim(),
      projectId: projectId,
      estimatedMinutes: estimatedMinutes,
      priority: priority,
      dueDate: dueDate,
      parentTaskId: parentTaskId,
      isTimeBlocked: (isTimeBlocked || scheduledStart != null) && !isAllDay,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      isAllDay: isAllDay,
      linkedProjectId: linkedProjectId,
      linkedTag: linkedTag,
      linkedSection: linkedSection,
    );
    await repo.addTask(task);
    return task;
  }

  Future<TaskItem> addSubtask({
    required String parentTaskId,
    required String title,
    String? projectId,
    int estimatedMinutes = 30,
  }) async {
    final tasks = ref.read(tasksStreamProvider).value ?? [];
    final parent = tasks.where((t) => t.id == parentTaskId).firstOrNull;
    return addTask(
      title: title,
      projectId: projectId ?? (parent?.projectId ?? 'proj_inbox'),
      parentTaskId: parentTaskId,
      estimatedMinutes: estimatedMinutes,
    );
  }

  Future<void> updateTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.updateTask(task);
  }

  Future<void> deleteTask(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.deleteTask(taskId);
  }

  Future<void> toggleComplete(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.toggleTaskComplete(taskId);
  }

  Future<void> scheduleTask({
    required String taskId,
    required DateTime start,
    required DateTime end,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.scheduleTask(taskId, start, end);
  }

  Future<void> unscheduleTask(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.unscheduleTask(taskId);
  }

  Future<void> rescheduleTask({
    required String taskId,
    required DateTime newStart,
    required int durationMinutes,
  }) async {
    final newEnd = newStart.add(Duration(minutes: durationMinutes));
    final repo = ref.read(taskRepositoryProvider);
    await repo.scheduleTask(taskId, newStart, newEnd);
  }

  Future<void> resizeTaskDuration({
    required String taskId,
    required DateTime start,
    required int newDurationMinutes,
  }) async {
    final clampedDuration = newDurationMinutes < 5 ? 5 : newDurationMinutes;
    final newEnd = start.add(Duration(minutes: clampedDuration));
    final repo = ref.read(taskRepositoryProvider);
    await repo.scheduleTask(taskId, start, newEnd);
  }

  /// Sets a task for a date without a specific time (All-day / Anytime Today)
  Future<void> setTaskForDateAnytime(String taskId, DateTime date) async {
    final tasks = ref.read(tasksStreamProvider).value ?? [];
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      final targetDate = DateTime(date.year, date.month, date.day);
      final updated = task.copyWith(
        isTimeBlocked: false,
        isAllDay: true,
        dueDate: targetDate,
        scheduledStart: targetDate,
        clearScheduledTimes: false,
      );
      final repo = ref.read(taskRepositoryProvider);
      await repo.updateTask(updated);
    }
  }

  /// Configures or updates a Smart Filter Window (symlink group) on an event
  Future<void> setTaskFilterWindow({
    required String taskId,
    String? linkedProjectId,
    String? linkedTag,
    String? linkedSection,
  }) async {
    final tasks = ref.read(tasksStreamProvider).value ?? [];
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      final updated = task.copyWith(
        linkedProjectId: linkedProjectId,
        linkedTag: linkedTag,
        linkedSection: linkedSection,
        clearLinkedFilter: (linkedProjectId == null || linkedProjectId.isEmpty) &&
            (linkedTag == null || linkedTag.isEmpty) &&
            (linkedSection == null || linkedSection.isEmpty),
      );
      final repo = ref.read(taskRepositoryProvider);
      await repo.updateTask(updated);
    }
  }
}

final taskControllerProvider = Provider<TaskController>((ref) {
  return TaskController(ref);
});

/// Index map of tasks by ID for O(1) instant lookup
final taskMapProvider = Provider<Map<String, TaskItem>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final map = <String, TaskItem>{};
      for (final t in tasks) {
        map[t.id] = t;
      }
      return map;
    },
    orElse: () => const {},
  );
});

/// Index map of subtasks grouped by parent task ID for O(1) instant lookup
final subtaskMapProvider = Provider<Map<String, List<TaskItem>>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final map = <String, List<TaskItem>>{};
      for (final t in tasks) {
        if (t.parentTaskId != null && t.parentTaskId!.isNotEmpty) {
          map.putIfAbsent(t.parentTaskId!, () => []).add(t);
        }
      }
      return map;
    },
    orElse: () => const {},
  );
});

/// All subtasks belonging to a specific parent task (O(1) lookup)
final subtasksForParentProvider =
    Provider.family<List<TaskItem>, String>((ref, parentId) {
  final map = ref.watch(subtaskMapProvider);
  return map[parentId] ?? const [];
});

/// Parent task of a subtask (O(1) lookup)
final parentTaskProvider =
    Provider.family<TaskItem?, String?>((ref, parentId) {
  if (parentId == null) return null;
  final map = ref.watch(taskMapProvider);
  return map[parentId];
});

/// Tasks grouped by project ID for O(1) instant column access on Board View
final tasksByProjectMapProvider = Provider<Map<String, List<TaskItem>>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final map = <String, List<TaskItem>>{};
      for (final t in tasks) {
        if (!t.isSubtask) {
          (map[t.projectId] ??= []).add(t);
        }
      }
      return map;
    },
    orElse: () => const {},
  );
});

class SidebarCounts {
  final int allCount;
  final int todayCount;
  final int unscheduledCount;
  final Map<String, int> projectCounts;

  const SidebarCounts({
    this.allCount = 0,
    this.todayCount = 0,
    this.unscheduledCount = 0,
    this.projectCounts = const {},
  });
}

/// Memoized single-pass counts for sidebar navigation
final sidebarCountsProvider = Provider<SidebarCounts>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  int all = 0;
  int today = 0;
  int unscheduled = 0;
  final projectCounts = <String, int>{};

  for (final t in tasks) {
    if (t.isSubtask) continue;
    if (!t.isCompleted) {
      all++;
      projectCounts[t.projectId] = (projectCounts[t.projectId] ?? 0) + 1;

      if (!t.isTimeBlocked) {
        unscheduled++;
      }

      if ((t.scheduledStart != null && TimeUtils.isToday(t.scheduledStart!)) ||
          (t.dueDate != null && TimeUtils.isToday(t.dueDate!))) {
        today++;
      }
    }
  }

  return SidebarCounts(
    allCount: all,
    todayCount: today,
    unscheduledCount: unscheduled,
    projectCounts: projectCounts,
  );
});

enum InspectorSource {
  taskBar,
  calendar,
}

class ActiveInspectorSession {
  final String taskId;
  final InspectorSource source;
  final Rect? anchorRect;

  const ActiveInspectorSession({
    required this.taskId,
    this.source = InspectorSource.taskBar,
    this.anchorRect,
  });
}

class ActiveInspectorSessionNotifier extends Notifier<ActiveInspectorSession?> {
  @override
  ActiveInspectorSession? build() => null;

  @override
  set state(ActiveInspectorSession? value) => super.state = value;

  void openTask(String taskId, {InspectorSource source = InspectorSource.taskBar, Rect? anchorRect}) {
    state = ActiveInspectorSession(taskId: taskId, source: source, anchorRect: anchorRect);
  }

  void select(String? id, {InspectorSource source = InspectorSource.taskBar, Rect? anchorRect}) {
    if (id == null) {
      state = null;
    } else {
      state = ActiveInspectorSession(taskId: id, source: source, anchorRect: anchorRect);
    }
  }

  void clear() => state = null;
}

final activeInspectorSessionProvider =
    NotifierProvider<ActiveInspectorSessionNotifier, ActiveInspectorSession?>(
  ActiveInspectorSessionNotifier.new,
);

/// Active task ID displayed in the floating inspector popup
class ActiveInspectorTaskIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(activeInspectorSessionProvider)?.taskId;
  }

  @override
  set state(String? value) {
    if (value == null) {
      ref.read(activeInspectorSessionProvider.notifier).clear();
    } else {
      ref.read(activeInspectorSessionProvider.notifier).select(value);
    }
  }

  void select(String? id) {
    if (id == null) {
      ref.read(activeInspectorSessionProvider.notifier).clear();
    } else {
      ref.read(activeInspectorSessionProvider.notifier).select(id);
    }
  }

  void clear() => ref.read(activeInspectorSessionProvider.notifier).clear();
}

final activeInspectorTaskIdProvider =
    NotifierProvider<ActiveInspectorTaskIdNotifier, String?>(
  ActiveInspectorTaskIdNotifier.new,
);

/// Active task object displayed in the floating inspector popup
final activeInspectorTaskProvider = Provider<TaskItem?>((ref) {
  final taskId = ref.watch(activeInspectorTaskIdProvider);
  if (taskId == null) return null;
  final taskMap = ref.watch(taskMapProvider);
  return taskMap[taskId];
});

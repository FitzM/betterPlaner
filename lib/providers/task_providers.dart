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
        if (t.isCompleted || t.isTimeBlocked) return false;
        if (selectedProjectId != null && t.projectId != selectedProjectId) return false;
        return true;
      }).toList();
    },
    orElse: () => [],
  );
});

/// Tasks scheduled for a specific date
final scheduledTasksForDateFamily = Provider.family<List<TaskItem>, DateTime>((ref, date) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) {
      return tasks.where((t) {
        if (!t.isTimeBlocked || t.scheduledStart == null) return false;
        return TimeUtils.isSameDay(t.scheduledStart!, date);
      }).toList();
    },
    orElse: () => [],
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
      isTimeBlocked: isTimeBlocked || scheduledStart != null,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
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
}

final taskControllerProvider = Provider<TaskController>((ref) {
  return TaskController(ref);
});

/// All subtasks belonging to a specific parent task
final subtasksForParentProvider =
    Provider.family<List<TaskItem>, String>((ref, parentId) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) => t.parentTaskId == parentId).toList(),
    orElse: () => [],
  );
});

/// Parent task of a subtask
final parentTaskProvider =
    Provider.family<TaskItem?, String?>((ref, parentId) {
  if (parentId == null) return null;
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) => t.id == parentId).firstOrNull,
    orElse: () => null,
  );
});

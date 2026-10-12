import 'dart:async';
import '../models/task_item.dart';
import 'mock_data.dart';

abstract class TaskRepository {
  Stream<List<TaskItem>> watchTasks();
  Future<List<TaskItem>> getTasks();
  Future<void> addTask(TaskItem task);
  Future<void> updateTask(TaskItem task);
  Future<void> deleteTask(String taskId);
  Future<void> toggleTaskComplete(String taskId);
  Future<void> scheduleTask(String taskId, DateTime start, DateTime end);
  Future<void> unscheduleTask(String taskId);
}

class LocalTaskRepository implements TaskRepository {
  final List<TaskItem> _tasks = List.from(MockData.getInitialTasks());
  final _controller = StreamController<List<TaskItem>>.broadcast();

  LocalTaskRepository() {
    _emit();
  }

  void _emit() {
    _controller.add(List.unmodifiable(_tasks));
  }

  @override
  Stream<List<TaskItem>> watchTasks() async* {
    yield List.unmodifiable(_tasks);
    yield* _controller.stream;
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    return List.unmodifiable(_tasks);
  }

  @override
  Future<void> addTask(TaskItem task) async {
    _tasks.insert(0, task);
    _emit();
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      _emit();
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    _emit();
  }

  @override
  Future<void> toggleTaskComplete(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final newStatus = !task.isCompleted;
      _tasks[index] = task.copyWith(
        isCompleted: newStatus,
        completedAt: newStatus ? DateTime.now() : null,
      );
      _emit();
    }
  }

  @override
  Future<void> scheduleTask(String taskId, DateTime start, DateTime end) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final duration = end.difference(start).inMinutes;
      _tasks[index] = task.copyWith(
        isTimeBlocked: true,
        scheduledStart: start,
        scheduledEnd: end,
        estimatedMinutes: duration > 0 ? duration : task.estimatedMinutes,
      );
      _emit();
    }
  }

  @override
  Future<void> unscheduleTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        isTimeBlocked: false,
        clearScheduledTimes: true,
      );
      _emit();
    }
  }
}

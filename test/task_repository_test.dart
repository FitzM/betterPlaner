import 'package:flutter_test/flutter_test.dart';
import 'package:getplan_better/models/task_item.dart';
import 'package:getplan_better/repositories/task_repository.dart';

void main() {
  group('LocalTaskRepository Tests', () {
    late LocalTaskRepository repository;

    setUp(() {
      repository = LocalTaskRepository();
    });

    test('Loads initial tasks', () async {
      final tasks = await repository.getTasks();
      expect(tasks.isNotEmpty, true);
    });

    test('Add task adds item to the list', () async {
      const newTask = TaskItem(
        id: 'new_task_1',
        title: 'Testing Repository',
        projectId: 'proj_work',
        estimatedMinutes: 30,
      );

      await repository.addTask(newTask);
      final tasks = await repository.getTasks();
      expect(tasks.any((t) => t.id == 'new_task_1'), true);
    });

    test('Toggle complete changes task completion status', () async {
      final initialTasks = await repository.getTasks();
      final firstTask = initialTasks.first;

      await repository.toggleTaskComplete(firstTask.id);
      final updatedTasks = await repository.getTasks();
      final updatedTask = updatedTasks.firstWhere((t) => t.id == firstTask.id);

      expect(updatedTask.isCompleted, !firstTask.isCompleted);
    });

    test('Schedule and unschedule updates task time block', () async {
      final initialTasks = await repository.getTasks();
      final task = initialTasks.first;

      final start = DateTime(2026, 10, 2, 10, 0);
      final end = DateTime(2026, 10, 2, 10, 45);

      await repository.scheduleTask(task.id, start, end);
      var tasks = await repository.getTasks();
      var scheduled = tasks.firstWhere((t) => t.id == task.id);
      expect(scheduled.isTimeBlocked, true);
      expect(scheduled.scheduledStart, start);
      expect(scheduled.scheduledEnd, end);
      expect(scheduled.estimatedMinutes, 45);

      await repository.unscheduleTask(task.id);
      tasks = await repository.getTasks();
      var unscheduled = tasks.firstWhere((t) => t.id == task.id);
      expect(unscheduled.isTimeBlocked, false);
      expect(unscheduled.scheduledStart, isNull);
    });
  });
}

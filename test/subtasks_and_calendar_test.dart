import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getplan_better/models/task_item.dart';
import 'package:getplan_better/models/user_settings.dart';
import 'package:getplan_better/models/view_mode.dart';
import 'package:getplan_better/providers/calendar_providers.dart';
import 'package:getplan_better/providers/settings_provider.dart';
import 'package:getplan_better/providers/task_providers.dart';
import 'package:getplan_better/core/utils/time_utils.dart';

void main() {
  group('Subtask Hierarchy & Scheduling Tests', () {
    test('TaskItem subtask properties and serialization', () {
      const parentTask = TaskItem(
        id: 'parent_1',
        title: 'Project Launch',
        projectId: 'proj_work',
      );
      expect(parentTask.isSubtask, false);

      const subtask = TaskItem(
        id: 'sub_1',
        parentTaskId: 'parent_1',
        title: 'Draft Announcement',
        projectId: 'proj_work',
        estimatedMinutes: 20,
      );
      expect(subtask.isSubtask, true);
      expect(subtask.parentTaskId, 'parent_1');

      final json = subtask.toJson();
      expect(json['parentTaskId'], 'parent_1');

      final revived = TaskItem.fromJson(json);
      expect(revived.isSubtask, true);
      expect(revived.parentTaskId, 'parent_1');
    });

    test('addSubtask creates linked task and subtasks provider resolves children', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Listen to keep stream active
      container.listen(tasksStreamProvider, (prev, next) {});
      await pumpEventQueue();

      final controller = container.read(taskControllerProvider);

      // Add parent task
      final parent = await controller.addTask(
        title: 'Parent Roadmap Task',
        projectId: 'proj_work',
        estimatedMinutes: 60,
      );
      await pumpEventQueue();

      // Add subtask
      final subtask = await controller.addSubtask(
        parentTaskId: parent.id,
        title: 'Subtask 1: Wireframes',
        projectId: 'proj_work',
        estimatedMinutes: 25,
      );
      await pumpEventQueue();

      // Verify subtasksForParentProvider
      final subtasks = container.read(subtasksForParentProvider(parent.id));
      expect(subtasks.length, 1);
      expect(subtasks.first.title, 'Subtask 1: Wireframes');
      expect(subtasks.first.parentTaskId, parent.id);
      expect(subtasks.first.isSubtask, true);

      // Verify parentTaskProvider resolves back to parent
      final resolvedParent = container.read(parentTaskProvider(subtask.parentTaskId));
      expect(resolvedParent, isNotNull);
      expect(resolvedParent!.id, parent.id);
      expect(resolvedParent.title, 'Parent Roadmap Task');
    });

    test('Subtasks can be scheduled independently on the calendar', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(taskControllerProvider);
      final repo = container.read(taskRepositoryProvider);
      await repo.getTasks();

      // Add parent task (unscheduled)
      final parent = await controller.addTask(
        title: 'Quarterly Review',
        projectId: 'proj_work',
      );

      // Add subtask scheduled on calendar
      final startTime = DateTime(2026, 10, 2, 14, 0);
      final endTime = DateTime(2026, 10, 2, 14, 30);
      final scheduledSubtask = await controller.addTask(
        title: 'Prepare Slide Deck',
        parentTaskId: parent.id,
        projectId: 'proj_work',
        scheduledStart: startTime,
        scheduledEnd: endTime,
      );

      expect(scheduledSubtask.isSubtask, true);
      expect(scheduledSubtask.parentTaskId, parent.id);
      expect(scheduledSubtask.isTimeBlocked, true);
      expect(scheduledSubtask.scheduledStart, startTime);
      expect(scheduledSubtask.scheduledEnd, endTime);

      // Parent remains unscheduled
      final refreshedTasks = await repo.getTasks();
      final refreshedParent = refreshedTasks.firstWhere((t) => t.id == parent.id);
      expect(refreshedParent.isTimeBlocked, false);
    });
  });

  group('Calendar Zoom & View Modes Tests', () {
    test('CalendarZoomNotifier clamps between 3.0h and 24.0h', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final zoomNotifier = container.read(calendarZoomProvider.notifier);
      expect(container.read(calendarZoomProvider), 9.0);

      // Zoom in multiple times until minimum limit of 3.0h
      for (var i = 0; i < 20; i++) {
        zoomNotifier.zoomIn();
      }
      expect(container.read(calendarZoomProvider), CalendarZoomNotifier.minHours);
      expect(container.read(calendarZoomProvider), 3.0);

      // Zoom out multiple times until maximum limit of 24.0h
      for (var i = 0; i < 30; i++) {
        zoomNotifier.zoomOut();
      }
      expect(container.read(calendarZoomProvider), CalendarZoomNotifier.maxHours);
      expect(container.read(calendarZoomProvider), 24.0);

      // Reset restores to default 9.0h
      zoomNotifier.reset();
      expect(container.read(calendarZoomProvider), CalendarZoomNotifier.defaultHours);
      expect(container.read(calendarZoomProvider), 9.0);
    });

    test('DashboardLayoutModeNotifier toggles between splitCalendar and multiColumnBoard', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final layoutNotifier = container.read(dashboardLayoutModeProvider.notifier);
      expect(container.read(dashboardLayoutModeProvider), DashboardLayoutMode.splitCalendar);

      layoutNotifier.setMode(DashboardLayoutMode.multiColumnBoard);
      expect(container.read(dashboardLayoutModeProvider), DashboardLayoutMode.multiColumnBoard);

      layoutNotifier.toggle();
      expect(container.read(dashboardLayoutModeProvider), DashboardLayoutMode.splitCalendar);
    });
  });

  group('User Settings Tests', () {
    test('UserSettings serialization and default values', () {
      const defaults = UserSettings();
      expect(defaults.defaultTaskDuration, 30);
      expect(defaults.timeSnapMinutes, 5);
      expect(defaults.defaultVisibleHours, 9.0);

      final json = defaults.toJson();
      expect(json['defaultTaskDuration'], 30);
      expect(json['timeSnapMinutes'], 5);

      final restored = UserSettings.fromJson(json);
      expect(restored.defaultTaskDuration, 30);
      expect(restored.timeSnapMinutes, 5);
    });

    test('UserSettingsNotifier updates duration and snap settings', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settingsNotifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).defaultTaskDuration, 30);

      settingsNotifier.setDefaultDuration(45);
      expect(container.read(settingsProvider).defaultTaskDuration, 45);

      settingsNotifier.setTimeSnap(15);
      expect(container.read(settingsProvider).timeSnapMinutes, 15);
    });

    test('Click-to-create centered calculation with custom settings duration', () {
      final clickTime = DateTime(2026, 10, 2, 14, 0); // 2:00 PM
      // 45 minute duration centered around 2:00 PM
      // 14:00 - 22m = 13:38 -> snaps to 13:40 (5m step)
      // End = 13:40 + 45m = 14:25
      final range = TimeUtils.calculateCenteredRange(clickTime, 45, snapMinutes: 5);
      expect(range.start.hour, 13);
      expect(range.start.minute, 40);
      expect(range.end.hour, 14);
      expect(range.end.minute, 25);
      expect(range.end.difference(range.start).inMinutes, 45);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:getplan_better/models/project_item.dart';
import 'package:getplan_better/models/task_item.dart';

void main() {
  group('Models Serialization Tests', () {
    test('ProjectItem serialization and deserialization', () {
      const project = ProjectItem(
        id: 'proj_test',
        userId: 'user_123',
        name: 'Work',
        colorValue: 0xFF0284C7,
        sortOrder: 1,
        isDefault: false,
      );

      final json = project.toJson();
      expect(json['id'], 'proj_test');
      expect(json['name'], 'Work');
      expect(json['colorValue'], 0xFF0284C7);

      final revived = ProjectItem.fromJson(json);
      expect(revived.id, project.id);
      expect(revived.name, project.name);
      expect(revived.colorValue, project.colorValue);
    });

    test('TaskItem serialization and deserialization', () {
      final now = DateTime(2026, 10, 2, 14, 0);
      final task = TaskItem(
        id: 'task_1',
        userId: 'user_123',
        title: 'Complete Presentation',
        notes: 'Add charts and metrics',
        projectId: 'proj_test',
        estimatedMinutes: 45,
        priority: 'high',
        isTimeBlocked: true,
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(minutes: 45)),
      );

      final json = task.toJson();
      expect(json['id'], 'task_1');
      expect(json['title'], 'Complete Presentation');
      expect(json['estimatedMinutes'], 45);
      expect(json['isTimeBlocked'], true);

      final revived = TaskItem.fromJson(json);
      expect(revived.id, task.id);
      expect(revived.title, task.title);
      expect(revived.notes, task.notes);
      expect(revived.estimatedMinutes, 45);
      expect(revived.isTimeBlocked, true);
      expect(revived.scheduledStart, now);
    });

    test('TaskItem copyWith clearScheduledTimes clears scheduling', () {
      final now = DateTime(2026, 10, 2, 14, 0);
      final task = TaskItem(
        id: 'task_1',
        title: 'Complete Presentation',
        projectId: 'proj_test',
        isTimeBlocked: true,
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(minutes: 45)),
      );

      final unscheduled = task.copyWith(clearScheduledTimes: true);
      expect(unscheduled.isTimeBlocked, false);
      expect(unscheduled.scheduledStart, isNull);
      expect(unscheduled.scheduledEnd, isNull);
    });
  });
}

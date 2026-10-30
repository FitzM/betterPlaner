import 'package:flutter_test/flutter_test.dart';
import 'package:getplan_better/core/utils/ticktick_parser.dart';
import 'package:getplan_better/models/task_item.dart';

void main() {
  group('TickTickParser', () {
    test('parses TickTick JSON format with project data and subtasks', () {
      const sampleJson = '''
      {
        "project": {
          "id": "inbox_proj",
          "name": "Inbox"
        },
        "tasks": [
          {
            "id": "tt_task_1",
            "title": "Client meeting",
            "content": "Discuss roadmap and contract",
            "priority": 5,
            "status": 0,
            "startDate": "2026-10-29T10:00:00.000+0000",
            "dueDate": "2026-10-29T11:00:00.000+0000",
            "items": [
              {
                "id": "sub_1",
                "title": "Prepare slide deck",
                "status": 2
              }
            ]
          },
          {
            "id": "tt_task_2",
            "title": "Buy groceries",
            "priority": 1,
            "status": 2,
            "completedTime": "2026-10-29T08:30:00.000+0000"
          }
        ]
      }
      ''';

      final result = TickTickParser.parse(sampleJson);
      expect(result.projects.length, 1);
      expect(result.projects.first.name, 'Inbox');

      // 2 main tasks + 1 subtask
      expect(result.tasks.length, 3);
      expect(result.taskCount, 2);
      expect(result.subtaskCount, 1);

      final task1 = result.tasks.firstWhere((t) => t.title == 'Client meeting');
      expect(task1.priority, 'urgent');
      expect(task1.isTimeBlocked, true);
      expect(task1.estimatedMinutes, 60);
      expect(task1.notes, 'Discuss roadmap and contract');

      final subtask = result.tasks.firstWhere((t) => t.title == 'Prepare slide deck');
      expect(subtask.parentTaskId, task1.id);
      expect(subtask.isCompleted, true);

      final task2 = result.tasks.firstWhere((t) => t.title == 'Buy groceries');
      expect(task2.isCompleted, true);
      expect(task2.priority, 'low');
    });

    test('parses TickTick CSV backup export', () {
      const sampleCsv = '''"Folder Name","List Name","Title","Kind","Notes","Start Date","Due Date","Reminders","Repeat","Priority","Status","Created Time","Completed Time","Order","Timezone","Is All Day"
"","Work","Ship production release","TEXT","Review changelog","2026-10-29 14:00:00","2026-10-29 15:30:00","","","5","0","2026-10-28 09:00:00","","-1000","America/New_York","0"
"","Personal","Pay electricity bill","TEXT","","","2026-10-31 18:00:00","","","3","0","2026-10-28 10:00:00","","-2000","America/New_York","0"
"","Work","Finished task","TEXT","Done deal","","","","","0","2","2026-10-27 10:00:00","2026-10-28 11:00:00","-3000","America/New_York","0"
''';

      final result = TickTickParser.parse(sampleCsv);
      // Projects: Inbox (default) + Work + Personal = 3
      expect(result.projects.length, 3);
      final projectNames = result.projects.map((p) => p.name).toSet();
      expect(projectNames.contains('Work'), true);
      expect(projectNames.contains('Personal'), true);

      expect(result.tasks.length, 3);

      final workTask = result.tasks.firstWhere((t) => t.title == 'Ship production release');
      expect(workTask.priority, 'urgent');
      expect(workTask.isTimeBlocked, true);
      expect(workTask.estimatedMinutes, 90);
      expect(workTask.notes, 'Review changelog');

      final billTask = result.tasks.firstWhere((t) => t.title == 'Pay electricity bill');
      expect(billTask.priority, 'medium');
      expect(billTask.isTimeBlocked, false);
      expect(billTask.dueDate, isNotNull);

      final finishedTask = result.tasks.firstWhere((t) => t.title == 'Finished task');
      expect(finishedTask.isCompleted, true);
    });

    test('parses full 25-column TickTick CSV with metadata header, parentId, and inline checklist symbols', () {
      const fullCsv = '''"Date: 2026-10-29+0000"
"Version: 7.2"
"Status: 
0 Normal
-1 Abandoned 
2 Completed"
"Folder Name","List Name","Title","Kind","Tags","Content","Is Check list","Start Date","Due Date","Reminder","Repeat","Priority","Status","Created Time","Completed Time","Order","Timezone","Is All Day","Is Floating","Column Name","Column Order","View Mode","taskId","parentId","projectKind"
"WorkFolder","DevList","Sprint Feature","CHECKLIST","frontend, high-prio","▫Write unit tests\r▫Code review\r▪Create branch","Y","2026-10-29T14:00:00+0000","2026-10-29T15:00:00+0000","-PT30M","FREQ=DAILY","5","0","2026-10-28T09:00:00+0000","","1000","America/Denver","false","false","In Progress","1","list","101","","TASK"
"WorkFolder","DevList","Deploy to staging","TEXT","ci","Run GitHub action","N","","","","","3","0","2026-10-28T10:00:00+0000","","2000","America/Denver","false","false","In Progress","1","list","102","101","TASK"
''';

      final result = TickTickParser.parse(fullCsv);
      expect(result.projects.any((p) => p.name == 'DevList' && p.folderName == 'WorkFolder'), true);

      // Main task (101) + 3 checklist subtasks + 1 parentId subtask (102) = 5 tasks
      expect(result.tasks.length, 5);

      final sprintTask = result.tasks.firstWhere((t) => t.rawTaskId == '101');
      expect(sprintTask.title, 'Sprint Feature');
      expect(sprintTask.priority, 'urgent');
      expect(sprintTask.isTimeBlocked, true);
      expect(sprintTask.isChecklist, true);
      expect(sprintTask.tags, ['frontend', 'high-prio']);
      expect(sprintTask.columnName, 'In Progress');
      expect(sprintTask.repeat, 'FREQ=DAILY');

      // Check inline subtasks
      final unitTestSubtask = result.tasks.firstWhere((t) => t.title == 'Write unit tests');
      expect(unitTestSubtask.parentTaskId, sprintTask.id);
      expect(unitTestSubtask.isCompleted, false);

      final branchSubtask = result.tasks.firstWhere((t) => t.title == 'Create branch');
      expect(branchSubtask.parentTaskId, sprintTask.id);
      expect(branchSubtask.isCompleted, true); // ▪ indicates completed

      // Check parentId subtask
      final deploySubtask = result.tasks.firstWhere((t) => t.rawTaskId == '102');
      expect(deploySubtask.parentTaskId, sprintTask.id);
      expect(deploySubtask.isSubtask, true);
    });

    test('supports setting task for today anytime and smart filter window symlinks', () {
      final now = DateTime.now();
      final anytimeTask = TaskItem(
        id: 'task_anytime',
        title: 'Accomplish house tasks',
        projectId: 'proj_work',
        isAllDay: true,
        isTimeBlocked: false,
        scheduledStart: DateTime(now.year, now.month, now.day),
        linkedProjectId: 'proj_house_tasks',
        linkedTag: 'chores',
      );

      expect(anytimeTask.isScheduledForDate(now), true);
      expect(anytimeTask.isAnytimeForDate(now), true);
      expect(anytimeTask.hasLinkedFilter, true);
      expect(anytimeTask.linkedProjectId, 'proj_house_tasks');

      final jsonMap = anytimeTask.toJson();
      expect(jsonMap['isAllDay'], true);
      expect(jsonMap['linkedProjectId'], 'proj_house_tasks');
      expect(jsonMap['linkedTag'], 'chores');

      final deserialized = TaskItem.fromJson(jsonMap);
      expect(deserialized.id, anytimeTask.id);
      expect(deserialized.isAllDay, true);
      expect(deserialized.linkedProjectId, 'proj_house_tasks');
      expect(deserialized.hasLinkedFilter, true);
    });
  });
}


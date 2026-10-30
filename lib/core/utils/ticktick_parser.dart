import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/project_item.dart';
import '../../models/task_item.dart';

class TickTickImportResult {
  final List<ProjectItem> projects;
  final List<TaskItem> tasks;
  final int projectCount;
  final int taskCount;
  final int subtaskCount;

  const TickTickImportResult({
    required this.projects,
    required this.tasks,
    required this.projectCount,
    required this.taskCount,
    required this.subtaskCount,
  });
}

class TickTickParser {
  static const _uuid = Uuid();

  /// Parse either JSON (Open API / CLI) or CSV (Web Export)
  static TickTickImportResult parse(String content, {String? userId}) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return parseJson(trimmed, userId: userId);
    } else {
      return parseCsv(trimmed, userId: userId);
    }
  }

  /// Parses TickTick API / CLI JSON output
  static TickTickImportResult parseJson(String jsonString, {String? userId}) {
    final dynamic decoded = json.decode(jsonString);
    final projects = <ProjectItem>[];
    final tasks = <TaskItem>[];
    int subtaskCount = 0;

    final projectMap = <String, String>{}; // ticktickId -> appProjectId

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item.containsKey('tasks') && item['tasks'] is List) {
            final pObj = item['project'] as Map<String, dynamic>?;
            final pId = _getOrCreateProjectId(pObj, projects, projectMap);
            final pTasks = item['tasks'] as List;
            for (final t in pTasks) {
              if (t is Map<String, dynamic>) {
                final parsed = _parseJsonTask(t, pId, userId: userId);
                tasks.add(parsed.task);
                tasks.addAll(parsed.subtasks);
                subtaskCount += parsed.subtasks.length;
              }
            }
          } else if (item.containsKey('name')) {
            _getOrCreateProjectId(item, projects, projectMap);
          } else if (item.containsKey('title')) {
            final parsed = _parseJsonTask(item, 'proj_inbox', userId: userId);
            tasks.add(parsed.task);
            tasks.addAll(parsed.subtasks);
            subtaskCount += parsed.subtasks.length;
          }
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('tasks') && decoded['tasks'] is List) {
        final pObj = decoded['project'] as Map<String, dynamic>?;
        final pId = _getOrCreateProjectId(pObj, projects, projectMap);
        final tList = decoded['tasks'] as List;
        for (final t in tList) {
          if (t is Map<String, dynamic>) {
            final parsed = _parseJsonTask(t, pId, userId: userId);
            tasks.add(parsed.task);
            tasks.addAll(parsed.subtasks);
            subtaskCount += parsed.subtasks.length;
          }
        }
      } else if (decoded.containsKey('projects') && decoded['projects'] is List) {
        final pList = decoded['projects'] as List;
        for (final p in pList) {
          if (p is Map<String, dynamic>) {
            _getOrCreateProjectId(p, projects, projectMap);
          }
        }
      }
    }

    if (projects.isEmpty) {
      projects.add(
        const ProjectItem(
          id: 'proj_inbox',
          name: 'Inbox',
          colorValue: 0xFF64748B,
          sortOrder: 0,
          isDefault: true,
        ),
      );
    }

    return TickTickImportResult(
      projects: projects,
      tasks: tasks,
      projectCount: projects.length,
      taskCount: tasks.length - subtaskCount,
      subtaskCount: subtaskCount,
    );
  }

  static String _getOrCreateProjectId(
    Map<String, dynamic>? obj,
    List<ProjectItem> projects,
    Map<String, String> projectMap,
  ) {
    if (obj == null) return 'proj_inbox';
    final ttId = obj['id']?.toString() ?? '';
    final name = obj['name']?.toString() ?? 'Imported List';
    if (projectMap.containsKey(ttId)) {
      return projectMap[ttId]!;
    }

    final newId = 'proj_${_cleanId(ttId.isNotEmpty ? ttId : _uuid.v4())}';
    final colorVal = _parseColor(obj['color']);

    final project = ProjectItem(
      id: newId,
      name: name,
      colorValue: colorVal,
      sortOrder: projects.length + 1,
    );
    projects.add(project);
    if (ttId.isNotEmpty) {
      projectMap[ttId] = newId;
    }
    return newId;
  }

  static ({TaskItem task, List<TaskItem> subtasks}) _parseJsonTask(
    Map<String, dynamic> json,
    String defaultProjectId, {
    String? userId,
  }) {
    final rawId = json['id']?.toString() ?? _uuid.v4();
    final taskId = 'task_${_cleanId(rawId)}';
    final title = json['title']?.toString() ?? 'Untitled Task';
    final content = json['content']?.toString() ?? json['desc']?.toString();

    final rawPriority = json['priority'];
    final priority = _mapPriority(rawPriority);

    final status = json['status'];
    final isCompleted = status == 2 || status == -1 || json['completed'] == true;

    DateTime? startDate;
    if (json['startDate'] != null) {
      startDate = _parseDateTime(json['startDate']);
    }
    DateTime? dueDate;
    if (json['dueDate'] != null) {
      dueDate = _parseDateTime(json['dueDate']);
    }

    DateTime? completedAt;
    if (json['completedTime'] != null) {
      completedAt = _parseDateTime(json['completedTime']);
    }

    final isTimeBlocked = startDate != null;
    int estimatedMinutes = 30;
    DateTime? scheduledStart = startDate;
    DateTime? scheduledEnd = dueDate;

    if (scheduledStart != null && scheduledEnd != null) {
      final diff = scheduledEnd.difference(scheduledStart).inMinutes;
      if (diff > 0) estimatedMinutes = diff;
    } else if (scheduledStart != null) {
      scheduledEnd = scheduledStart.add(Duration(minutes: estimatedMinutes));
    }

    final mainTask = TaskItem(
      id: taskId,
      userId: userId ?? '',
      title: title,
      notes: content,
      projectId: defaultProjectId,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      dueDate: dueDate,
      isCompleted: isCompleted,
      completedAt: completedAt,
      isTimeBlocked: isTimeBlocked,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
    );

    final subtasks = <TaskItem>[];
    if (json['items'] is List) {
      final items = json['items'] as List;
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final subId = 'task_${_cleanId(item['id']?.toString() ?? _uuid.v4())}';
          final subTitle = item['title']?.toString() ?? 'Subtask';
          final subStatus = item['status'];
          final subCompleted = subStatus == 2 || item['completed'] == true;

          subtasks.add(
            TaskItem(
              id: subId,
              userId: userId ?? '',
              title: subTitle,
              projectId: defaultProjectId,
              parentTaskId: taskId,
              isCompleted: subCompleted,
              priority: 'none',
              estimatedMinutes: 15,
            ),
          );
        }
      }
    }

    return (task: mainTask, subtasks: subtasks);
  }

  /// Parses TickTick CSV backup export with full 25-column schema awareness
  static TickTickImportResult parseCsv(String csvContent, {String? userId}) {
    final rows = _parseCsvFull(csvContent);
    if (rows.isEmpty) {
      return const TickTickImportResult(
        projects: [],
        tasks: [],
        projectCount: 0,
        taskCount: 0,
        subtaskCount: 0,
      );
    }

    // Locate header row containing "List Name" or "Title"
    int headerRowIdx = -1;
    List<String> header = [];
    for (int i = 0; i < rows.length && i < 25; i++) {
      final candidate = rows[i];
      final cLower = candidate.map((c) => c.toLowerCase().trim()).toList();
      if (cLower.contains('list name') || cLower.contains('title')) {
        headerRowIdx = i;
        header = candidate;
        break;
      }
    }

    if (headerRowIdx == -1) {
      header = rows[0];
      headerRowIdx = 0;
    }

    final headerIndex = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      headerIndex[header[i].toLowerCase().trim()] = i;
    }

    final folderNameIdx = headerIndex['folder name'] ?? -1;
    final listNameIdx = headerIndex['list name'] ?? -1;
    final titleIdx = headerIndex['title'] ?? -1;
    final kindIdx = headerIndex['kind'] ?? -1;
    final tagsIdx = headerIndex['tags'] ?? -1;
    final notesIdx = headerIndex['content'] ?? headerIndex['notes'] ?? -1;
    final isChecklistIdx = headerIndex['is check list'] ?? -1;
    final startIdx = headerIndex['start date'] ?? -1;
    final dueIdx = headerIndex['due date'] ?? -1;
    final reminderIdx = headerIndex['reminder'] ?? -1;
    final repeatIdx = headerIndex['repeat'] ?? -1;
    final priorityIdx = headerIndex['priority'] ?? -1;
    final statusIdx = headerIndex['status'] ?? -1;
    final createdIdx = headerIndex['created time'] ?? -1;
    final completedIdx = headerIndex['completed time'] ?? -1;
    final orderIdx = headerIndex['order'] ?? -1;
    final timezoneIdx = headerIndex['timezone'] ?? -1;
    final isAllDayIdx = headerIndex['is all day'] ?? -1;
    final columnNameIdx = headerIndex['column name'] ?? -1;
    final columnOrderIdx = headerIndex['column order'] ?? -1;
    final viewModeIdx = headerIndex['view mode'] ?? -1;
    final taskIdIdx = headerIndex['taskid'] ?? -1;
    final parentIdIdx = headerIndex['parentid'] ?? -1;
    final projectKindIdx = headerIndex['projectkind'] ?? -1;

    final projects = <ProjectItem>[];
    final projectMap = <String, String>{}; // name -> projectId
    final tasks = <TaskItem>[];
    int subtaskCount = 0;

    // Ensure default Inbox project
    final inboxProject = const ProjectItem(
      id: 'proj_inbox',
      name: 'Inbox',
      colorValue: 0xFF64748B,
      sortOrder: 0,
      isDefault: true,
    );
    projects.add(inboxProject);
    projectMap['inbox'] = inboxProject.id;

    for (int i = headerRowIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (titleIdx >= 0 && titleIdx >= row.length) continue;

      final title = titleIdx >= 0 && titleIdx < row.length ? row[titleIdx].trim() : '';
      if (title.isEmpty) continue;

      final folderName = folderNameIdx >= 0 && folderNameIdx < row.length && row[folderNameIdx].isNotEmpty
          ? row[folderNameIdx].trim()
          : null;

      final listName = listNameIdx >= 0 && listNameIdx < row.length && row[listNameIdx].isNotEmpty
          ? row[listNameIdx].trim()
          : 'Inbox';

      final viewMode = viewModeIdx >= 0 && viewModeIdx < row.length && row[viewModeIdx].isNotEmpty
          ? row[viewModeIdx].trim()
          : null;

      final projectKind = projectKindIdx >= 0 && projectKindIdx < row.length && row[projectKindIdx].isNotEmpty
          ? row[projectKindIdx].trim()
          : null;

      // Find or create project
      String projectId = inboxProject.id;
      final listKey = listName.toLowerCase().trim();
      if (projectMap.containsKey(listKey)) {
        projectId = projectMap[listKey]!;
      } else {
        projectId = 'proj_${_cleanId(listName).substring(0, listName.length > 24 ? 24 : listName.length)}_${projects.length}';
        final newProject = ProjectItem(
          id: projectId,
          name: listName,
          folderName: folderName,
          colorValue: _getColorForIndex(projects.length),
          sortOrder: projects.length,
          viewMode: viewMode,
          projectKind: projectKind,
        );
        projects.add(newProject);
        projectMap[listKey] = projectId;
      }

      final rawNotes = notesIdx >= 0 && notesIdx < row.length && row[notesIdx].isNotEmpty
          ? row[notesIdx].trim()
          : null;

      final kind = kindIdx >= 0 && kindIdx < row.length ? row[kindIdx].toUpperCase().trim() : 'TEXT';
      final isChecklist = (isChecklistIdx >= 0 && isChecklistIdx < row.length && row[isChecklistIdx].toUpperCase().trim() == 'Y') ||
          kind == 'CHECKLIST';

      final rawPriority = priorityIdx >= 0 && priorityIdx < row.length ? row[priorityIdx] : '0';
      final priority = _mapPriority(rawPriority);

      final rawStatus = statusIdx >= 0 && statusIdx < row.length ? row[statusIdx].trim() : '0';
      final isCompleted = rawStatus == '2' || rawStatus == '-1' || rawStatus.toLowerCase() == 'completed';

      final rawTaskId = taskIdIdx >= 0 && taskIdIdx < row.length ? row[taskIdIdx].trim() : '';
      final rawParentId = parentIdIdx >= 0 && parentIdIdx < row.length ? row[parentIdIdx].trim() : '';

      final taskId = rawTaskId.isNotEmpty
          ? 'task_${_cleanId(rawTaskId)}'
          : 'task_${_uuid.v4().substring(0, 8)}';
      final parentTaskId = rawParentId.isNotEmpty ? 'task_${_cleanId(rawParentId)}' : null;

      if (parentTaskId != null) {
        subtaskCount++;
      }

      final isAllDay = isAllDayIdx >= 0 && isAllDayIdx < row.length
          ? row[isAllDayIdx].toLowerCase().trim() == 'true'
          : false;

      DateTime? startDate;
      if (startIdx >= 0 && startIdx < row.length && row[startIdx].isNotEmpty) {
        startDate = _parseDateTime(row[startIdx]);
      }

      DateTime? dueDate;
      if (dueIdx >= 0 && dueIdx < row.length && row[dueIdx].isNotEmpty) {
        dueDate = _parseDateTime(row[dueIdx]);
      }

      DateTime? createdAt;
      if (createdIdx >= 0 && createdIdx < row.length && row[createdIdx].isNotEmpty) {
        createdAt = _parseDateTime(row[createdIdx]);
      }

      DateTime? completedAt;
      if (completedIdx >= 0 && completedIdx < row.length && row[completedIdx].isNotEmpty) {
        completedAt = _parseDateTime(row[completedIdx]);
      }

      final rawTags = tagsIdx >= 0 && tagsIdx < row.length ? row[tagsIdx].trim() : '';
      final tags = rawTags.isNotEmpty
          ? rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      final reminder = reminderIdx >= 0 && reminderIdx < row.length && row[reminderIdx].isNotEmpty
          ? row[reminderIdx].trim()
          : null;

      final repeat = repeatIdx >= 0 && repeatIdx < row.length && row[repeatIdx].isNotEmpty
          ? row[repeatIdx].trim()
          : null;

      final rawOrder = orderIdx >= 0 && orderIdx < row.length ? row[orderIdx].trim() : '';
      final sortOrder = int.tryParse(rawOrder);

      final timezone = timezoneIdx >= 0 && timezoneIdx < row.length && row[timezoneIdx].isNotEmpty
          ? row[timezoneIdx].trim()
          : null;

      final rawColName = columnNameIdx >= 0 && columnNameIdx < row.length ? row[columnNameIdx].trim() : '';
      final columnName = rawColName.isNotEmpty && rawColName != 'Not Sectioned' ? rawColName : null;

      final rawColOrder = columnOrderIdx >= 0 && columnOrderIdx < row.length ? row[columnOrderIdx].trim() : '';
      final columnOrder = int.tryParse(rawColOrder);

      final isTimeBlocked = !isAllDay && startDate != null;
      int estimatedMinutes = 30;
      DateTime? scheduledStart = isTimeBlocked ? startDate : null;
      DateTime? scheduledEnd = isTimeBlocked ? (dueDate ?? startDate.add(Duration(minutes: estimatedMinutes))) : null;

      if (scheduledStart != null && scheduledEnd != null) {
        final diff = scheduledEnd.difference(scheduledStart).inMinutes;
        if (diff > 0) estimatedMinutes = diff;
      }

      // Check for inline checklist items in Content (marked with ▫ for open, ▪ for completed)
      String? cleanNotes = rawNotes;
      final inlineSubtasks = <TaskItem>[];
      if (rawNotes != null && (rawNotes.contains('▫') || rawNotes.contains('▪'))) {
        final buffer = StringBuffer();
        final tokens = <String>[];
        for (int charIdx = 0; charIdx < rawNotes.length; charIdx++) {
          final char = rawNotes[charIdx];
          if (char == '▫' || char == '▪') {
            if (buffer.isNotEmpty) {
              tokens.add(buffer.toString());
              buffer.clear();
            }
            buffer.write(char);
          } else {
            buffer.write(char);
          }
        }
        if (buffer.isNotEmpty) tokens.add(buffer.toString());

        final remainingNotes = <String>[];
        for (final token in tokens) {
          final trimmed = token.trim();
          if (trimmed.startsWith('▫') || trimmed.startsWith('▪')) {
            final isItemCompleted = trimmed.startsWith('▪');
            final itemText = trimmed.substring(1).trim();
            if (itemText.isNotEmpty) {
              subtaskCount++;
              inlineSubtasks.add(
                TaskItem(
                  id: 'task_${taskId}_sub_${inlineSubtasks.length + 1}',
                  userId: userId ?? '',
                  title: itemText,
                  projectId: projectId,
                  folderName: folderName,
                  listName: listName,
                  parentTaskId: taskId,
                  isCompleted: isItemCompleted,
                  completedAt: isItemCompleted ? completedAt : null,
                  priority: 'none',
                  estimatedMinutes: 15,
                  kind: 'CHECKLIST',
                  isChecklist: true,
                ),
              );
            }
          } else if (trimmed.isNotEmpty) {
            remainingNotes.add(trimmed);
          }
        }
        cleanNotes = remainingNotes.isNotEmpty ? remainingNotes.join('\n') : null;
      }

      tasks.add(
        TaskItem(
          id: taskId,
          userId: userId ?? '',
          title: title,
          notes: cleanNotes,
          projectId: projectId,
          folderName: folderName,
          listName: listName,
          parentTaskId: parentTaskId,
          priority: priority,
          estimatedMinutes: estimatedMinutes,
          dueDate: dueDate ?? (isAllDay ? startDate : null),
          isCompleted: isCompleted,
          completedAt: completedAt,
          createdAt: createdAt,
          isTimeBlocked: isTimeBlocked,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          kind: kind,
          isChecklist: isChecklist || inlineSubtasks.isNotEmpty,
          tags: tags,
          isAllDay: isAllDay,
          repeat: repeat,
          reminder: reminder,
          timezone: timezone,
          columnName: columnName,
          columnOrder: columnOrder,
          sortOrder: sortOrder,
          rawTaskId: rawTaskId.isNotEmpty ? rawTaskId : null,
          rawParentId: rawParentId.isNotEmpty ? rawParentId : null,
        ),
      );

      tasks.addAll(inlineSubtasks);
    }

    return TickTickImportResult(
      projects: projects,
      tasks: tasks,
      projectCount: projects.length,
      taskCount: tasks.length - subtaskCount,
      subtaskCount: subtaskCount,
    );
  }

  static String _cleanId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static String _mapPriority(dynamic priority) {
    if (priority == null) return 'none';
    final str = priority.toString().toLowerCase().trim();
    if (str == '5' || str == 'high' || str == 'urgent') return 'urgent';
    if (str == '3' || str == 'medium') return 'medium';
    if (str == '1' || str == 'low') return 'low';
    return 'none';
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      try {
        final normalized = s.replaceAll('/', '-').replaceFirst(' ', 'T');
        return DateTime.parse(normalized);
      } catch (_) {
        return null;
      }
    }
  }

  static int _parseColor(dynamic colorVal) {
    if (colorVal == null) return 0xFF0284C7;
    if (colorVal is int) return colorVal;
    final s = colorVal.toString().replaceAll('#', '');
    if (s.length == 6) {
      return int.tryParse('FF$s', radix: 16) ?? 0xFF0284C7;
    }
    return 0xFF0284C7;
  }

  static int _getColorForIndex(int index) {
    const palette = [
      0xFF0284C7, // Blue
      0xFF6366F1, // Indigo
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFFEC4899, // Pink
      0xFF8B5CF6, // Purple
      0xFF14B8A6, // Teal
      0xFFF97316, // Orange
      0xFF06B6D4, // Cyan
      0xFF84CC16, // Lime
      0xFFE11D48, // Rose
      0xFF64748B, // Slate
    ];
    return palette[index % palette.length];
  }

  /// Full state-machine CSV parser that cleanly handles multi-line cells and escaped quotes
  static List<List<String>> _parseCsvFull(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((c == '\r' || c == '\n') && !inQuotes) {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        if (row.length > 1 || (row.length == 1 && row[0].isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
      } else {
        field.write(c);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }

    return rows;
  }
}

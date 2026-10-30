import '../core/utils/ticktick_embedded_backup.dart';
import '../core/utils/ticktick_parser.dart';
import '../models/project_item.dart';
import '../models/task_item.dart';

class MockData {
  static List<ProjectItem>? _projects;
  static List<TaskItem>? _tasks;

  static void _ensureInitialized() {
    if (_projects != null && _tasks != null) return;
    try {
      final csv = TickTickEmbeddedBackup.getCsv();
      if (csv.isNotEmpty) {
        final result = TickTickParser.parseCsv(csv);
        if (result.projects.isNotEmpty || result.tasks.isNotEmpty) {
          _projects = List.from(result.projects);
          _tasks = List.from(result.tasks);
          return;
        }
      }
    } catch (_) {}

    _projects = List.from(_fallbackProjects);
    _tasks = List.from(_fallbackTasks);
  }

  /// Load imported TickTick data into initial state
  static void loadTickTickData(List<ProjectItem> projects, List<TaskItem> tasks) {
    if (projects.isNotEmpty) {
      _projects = List.from(projects);
    }
    if (tasks.isNotEmpty) {
      _tasks = List.from(tasks);
    }
  }

  static List<ProjectItem> get initialProjects {
    _ensureInitialized();
    return _projects!;
  }

  static List<TaskItem> getInitialTasks() {
    _ensureInitialized();
    return _tasks!;
  }

  static final List<ProjectItem> _fallbackProjects = [
    const ProjectItem(
      id: 'proj_inbox',
      name: 'Inbox',
      colorValue: 0xFF64748B, // Slate
      sortOrder: 0,
      isDefault: true,
    ),
    const ProjectItem(
      id: 'proj_work',
      name: 'Work',
      colorValue: 0xFF0284C7, // Sky Blue
      sortOrder: 1,
    ),
    const ProjectItem(
      id: 'proj_personal',
      name: 'Personal',
      colorValue: 0xFF6366F1, // Indigo
      sortOrder: 2,
    ),
    const ProjectItem(
      id: 'proj_health',
      name: 'Health & Fitness',
      colorValue: 0xFF10B981, // Emerald
      sortOrder: 3,
    ),
    const ProjectItem(
      id: 'proj_learning',
      name: 'Side Projects',
      colorValue: 0xFFF59E0B, // Amber
      sortOrder: 4,
    ),
  ];

  static final List<TaskItem> _fallbackTasks = [
    TaskItem(
      id: 'task_1',
      title: 'Review team weekly goals & roadmap',
      notes: 'Check sprint board and summarize priority deliverables.',
      projectId: 'proj_work',
      estimatedMinutes: 45,
      priority: 'high',
      isTimeBlocked: true,
      scheduledStart: DateTime.now(),
      scheduledEnd: DateTime.now().add(const Duration(minutes: 45)),
    ),
    const TaskItem(
      id: 'task_4',
      title: 'Order groceries and coffee beans',
      projectId: 'proj_personal',
      estimatedMinutes: 15,
      priority: 'low',
      isTimeBlocked: false,
    ),
  ];
}

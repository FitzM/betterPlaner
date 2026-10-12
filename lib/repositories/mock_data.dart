import '../models/project_item.dart';
import '../models/task_item.dart';

class MockData {
  static final List<ProjectItem> initialProjects = [
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

  static List<TaskItem> getInitialTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      TaskItem(
        id: 'task_1',
        title: 'Review team weekly goals & roadmap',
        notes: 'Check sprint board and summarize priority deliverables.',
        projectId: 'proj_work',
        estimatedMinutes: 45,
        priority: 'high',
        isTimeBlocked: true,
        scheduledStart: today.add(const Duration(hours: 9, minutes: 0)), // 9:00 AM
        scheduledEnd: today.add(const Duration(hours: 9, minutes: 45)),   // 9:45 AM
      ),
      TaskItem(
        id: 'task_2',
        title: 'Deep work: Architecture refactor',
        notes: 'Design state management and repository caching.',
        projectId: 'proj_work',
        estimatedMinutes: 90,
        priority: 'urgent',
        isTimeBlocked: true,
        scheduledStart: today.add(const Duration(hours: 10, minutes: 30)), // 10:30 AM
        scheduledEnd: today.add(const Duration(hours: 12, minutes: 0)),    // 12:00 PM
      ),
      TaskItem(
        id: 'task_3',
        title: 'Gym workout: Upper body & cardio',
        projectId: 'proj_health',
        estimatedMinutes: 60,
        priority: 'medium',
        isTimeBlocked: true,
        scheduledStart: today.add(const Duration(hours: 17, minutes: 0)), // 5:00 PM
        scheduledEnd: today.add(const Duration(hours: 18, minutes: 0)),   // 6:00 PM
      ),
      TaskItem(
        id: 'task_4',
        title: 'Order groceries and coffee beans',
        projectId: 'proj_personal',
        estimatedMinutes: 15,
        priority: 'low',
        isTimeBlocked: false, // Unscheduled backlog
      ),
      TaskItem(
        id: 'task_5',
        title: 'Read chapter on distributed systems',
        projectId: 'proj_learning',
        estimatedMinutes: 30,
        priority: 'none',
        isTimeBlocked: false, // Unscheduled backlog
      ),
      TaskItem(
        id: 'task_6',
        title: 'Respond to client inquiries & emails',
        projectId: 'proj_work',
        estimatedMinutes: 30,
        priority: 'high',
        isTimeBlocked: false, // Unscheduled backlog
      ),
      TaskItem(
        id: 'task_7',
        title: 'Plan weekend trip itinerary',
        projectId: 'proj_personal',
        estimatedMinutes: 45,
        priority: 'none',
        isTimeBlocked: false, // Unscheduled backlog
      ),
    ];
  }
}

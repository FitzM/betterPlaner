import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../models/project_item.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import 'draggable_task_card.dart';
import 'quick_task_input.dart';

class TaskBoardPane extends ConsumerStatefulWidget {
  const TaskBoardPane({super.key});

  @override
  ConsumerState<TaskBoardPane> createState() => _TaskBoardPaneState();
}

class _TaskBoardPaneState extends ConsumerState<TaskBoardPane> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectsProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Expanded(
      child: Container(
        color: isDark ? PlanColors.darkBg : PlanColors.lightBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Board Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? PlanColors.darkBg : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showHint = constraints.maxWidth > 580;
                  return Row(
                    children: [
                      const Icon(Icons.view_week_rounded, size: 18, color: PlanColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Task Board',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: PlanColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${projects.length} Projects',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PlanColors.primary,
                          ),
                        ),
                      ),
                      if (showHint) ...[
                        const Spacer(),
                        Flexible(
                          child: Text(
                            'Drag tasks between columns or into the calendar rail',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Horizontal Scrollable Project Columns
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  return Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: projects.map((project) {
                          final projectTasks = tasks.where((t) => t.projectId == project.id).toList();
                          return _buildProjectColumn(
                            context: context,
                            isDark: isDark,
                            project: project,
                            tasks: projectTasks,
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading tasks: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectColumn({
    required BuildContext context,
    required bool isDark,
    required ProjectItem project,
    required List<TaskItem> tasks,
  }) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
        ),
      ),
      child: DragTarget<TaskItem>(
        onWillAcceptWithDetails: (details) => details.data.projectId != project.id,
        onAcceptWithDetails: (details) {
          // Reassign task to this project
          final updated = details.data.copyWith(projectId: project.id);
          ref.read(taskControllerProvider).updateTask(updated);
        },
        builder: (context, candidateData, rejectedData) {
          final isDropHover = candidateData.isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              color: isDropHover
                  ? project.color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isDropHover
                  ? Border.all(color: project.color, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: project.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: project.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeTasks.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: project.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Task Input for this project
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: QuickTaskInput(defaultProjectId: project.id),
                ),
                const SizedBox(height: 6),

                // Task Cards List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: [
                      ...activeTasks.map((t) => DraggableTaskCard(key: ValueKey(t.id), task: t)),
                      if (completedTasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text(
                            'COMPLETED (${completedTasks.length})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...completedTasks.map((t) => DraggableTaskCard(key: ValueKey(t.id), task: t)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

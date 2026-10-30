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
  bool _isAsyncReady = false;

  @override
  void initState() {
    super.initState();
    // Allow Frame 0 to finish processing view mode change before rendering column tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isAsyncReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectsProvider);
    final tasksByProject = ref.watch(tasksByProjectMapProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);

    // Only render columns for real projects that have tasks (plus Inbox)
    final boardProjects = projects.where((p) {
      if (!p.isValidProjectName) return false;
      if (p.isDefault) return true;
      final pTasks = tasksByProject[p.id];
      return pTasks != null && pTasks.isNotEmpty;
    }).toList();

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
                          '${boardProjects.length} Active Columns',
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

            // Horizontal Virtualized Columns with fixed itemExtent for O(1) performance
            Expanded(
              child: !_isAsyncReady
                  ? _BoardSkeleton(isDark: isDark)
                  : tasksAsync.when(
                      data: (_) {
                        if (boardProjects.isEmpty) {
                          return const Center(child: Text('No active projects found'));
                        }
                        return Scrollbar(
                          controller: _scrollController,
                          child: ListView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(12),
                            itemCount: boardProjects.length,
                            itemExtent: 312.0, // Fixed extent avoids measuring off-screen columns
                            // ignore: deprecated_member_use
                            cacheExtent: 312.0, // Lazy buffer: only keep 1 column outside viewport
                            itemBuilder: (context, index) {
                              final project = boardProjects[index];
                              final projectTasks = tasksByProject[project.id] ?? const [];
                              return ProjectBoardColumn(
                                key: ValueKey('col_${project.id}'),
                                project: project,
                                tasks: projectTasks,
                              );
                            },
                          ),
                        );
                      },
                      loading: () => _BoardSkeleton(isDark: isDark),
                      error: (e, _) => Center(child: Text('Error loading tasks: $e')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectBoardColumn extends ConsumerStatefulWidget {
  final ProjectItem project;
  final List<TaskItem> tasks;

  const ProjectBoardColumn({
    super.key,
    required this.project,
    required this.tasks,
  });

  @override
  ConsumerState<ProjectBoardColumn> createState() => _ProjectBoardColumnState();
}

class _ProjectBoardColumnState extends ConsumerState<ProjectBoardColumn> {
  final ScrollController _columnScrollController = ScrollController();
  // Viewport-based lazy loading: start with 6 tasks (what fits in viewport)
  int _columnLimit = 6;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _columnScrollController.addListener(_onColumnScroll);
  }

  void _onColumnScroll() {
    if (!_columnScrollController.hasClients) return;
    final maxScroll = _columnScrollController.position.maxScrollExtent;
    final current = _columnScrollController.position.pixels;
    if (current >= maxScroll - 120) {
      final activeCount = widget.tasks.where((t) => !t.isCompleted).length;
      if (_columnLimit < activeCount) {
        setState(() {
          _columnLimit = (_columnLimit + 8).clamp(6, activeCount);
        });
      }
    }
  }

  @override
  void dispose() {
    _columnScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final project = widget.project;
    final tasks = widget.tasks;

    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    final totalActive = activeTasks.length;
    final visibleActive = totalActive > _columnLimit ? _columnLimit : totalActive;
    final hasMoreActive = totalActive > visibleActive;

    final hasCompleted = completedTasks.isNotEmpty;
    final completedHeaderIndex = visibleActive + (hasMoreActive ? 1 : 0);
    final visibleCompletedCount = _showCompleted ? completedTasks.length.clamp(0, 15) : 0;

    final totalItems = visibleActive +
        (hasMoreActive ? 1 : 0) +
        (hasCompleted ? 1 : 0) +
        visibleCompletedCount;

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
                          '$totalActive',
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

                // Virtualized & Viewport-Paginated Task Cards List
                Expanded(
                  child: totalItems == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No active tasks',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _columnScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            if (index < visibleActive) {
                              final t = activeTasks[index];
                              return DraggableTaskCard(key: ValueKey(t.id), task: t);
                            }
                            if (hasMoreActive && index == visibleActive) {
                              final remaining = totalActive - visibleActive;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _columnLimit += 15;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+ $remaining more tasks (scroll to load)',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: PlanColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (index == completedHeaderIndex) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _showCompleted = !_showCompleted;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _showCompleted
                                              ? Icons.keyboard_arrow_down_rounded
                                              : Icons.keyboard_arrow_right_rounded,
                                          size: 14,
                                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'COMPLETED (${completedTasks.length})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            final completedIndex = index - (completedHeaderIndex + 1);
                            if (_showCompleted &&
                                completedIndex >= 0 &&
                                completedIndex < completedTasks.length) {
                              final t = completedTasks[completedIndex];
                              return DraggableTaskCard(key: ValueKey(t.id), task: t);
                            }
                            return const SizedBox.shrink();
                          },
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

/// Lightweight skeleton placeholder rendered for 1 frame to ensure zero input lag
class _BoardSkeleton extends StatelessWidget {
  final bool isDark;
  const _BoardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemExtent: 312.0,
      itemBuilder: (context, index) {
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < 4; i++) ...[
                Container(
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

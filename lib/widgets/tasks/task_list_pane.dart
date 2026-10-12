import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import 'draggable_task_card.dart';
import 'quick_task_input.dart';

class TaskListPane extends ConsumerStatefulWidget {
  final double? width;
  const TaskListPane({super.key, this.width});

  @override
  ConsumerState<TaskListPane> createState() => _TaskListPaneState();
}

class _TaskListPaneState extends ConsumerState<TaskListPane> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedProjectId = ref.watch(selectedProjectIdProvider);
    final activeFilter = ref.watch(taskFilterProvider);
    final projectMap = ref.watch(projectMapProvider);
    final tasks = ref.watch(filteredTasksProvider);

    // Active project title
    final title = selectedProjectId != null
        ? (projectMap[selectedProjectId]?.name ?? 'Project')
        : activeFilter.label;

    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return Container(
      width: widget.width ?? 340,
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkBg : PlanColors.lightBg,
        border: Border(
          right: BorderSide(
            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeTasks.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 18),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isSearching ? 'Close Search' : 'Search Tasks',
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Search Field (if open)
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: Icon(Icons.search, size: 16),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (val) {
                  ref.read(taskSearchQueryProvider.notifier).setQuery(val);
                },
              ),
            ),

          // Quick Task Input Bar
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: QuickTaskInput(),
          ),

          const SizedBox(height: 10),

          // Scrollable Task List with Unschedule Drop Target
          Expanded(
            child: DragTarget<TaskItem>(
              onWillAcceptWithDetails: (details) => details.data.isTimeBlocked,
              onAcceptWithDetails: (details) {
                if (details.data.isTimeBlocked) {
                  ref.read(taskControllerProvider).unscheduleTask(details.data.id);
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isDroppingToUnschedule = candidateData.isNotEmpty;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isDroppingToUnschedule
                        ? PlanColors.primary.withValues(alpha: 0.06)
                        : Colors.transparent,
                    border: isDroppingToUnschedule
                        ? Border.all(color: PlanColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      tasks.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.task_alt_rounded,
                                      size: 40,
                                      color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No tasks in this list',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add a task above or drag tasks onto the calendar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              children: [
                                // Active Tasks
                                ...activeTasks.map((t) => DraggableTaskCard(key: ValueKey(t.id), task: t)),

                                // Completed Tasks Collapsible Section
                                if (completedTasks.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                        'Completed (${completedTasks.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                        ),
                                      ),
                                      children: completedTasks
                                          .map((t) => DraggableTaskCard(key: ValueKey(t.id), task: t))
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                      // Drop indicator overlay when dragging over
                      if (isDroppingToUnschedule)
                        Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: PlanColors.primary,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_circle_outline_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Drop to unschedule task',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

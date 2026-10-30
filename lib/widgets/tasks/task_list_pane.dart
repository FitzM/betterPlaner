import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../models/task_item.dart';
import '../../models/view_mode.dart';
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
  final ScrollController _scrollController = ScrollController();

  // Viewport-based lazy loading: 12 tasks initially (what fits on screen)
  static const int _batchSize = 12;
  int _activeDisplayLimit = _batchSize;
  int _completedDisplayLimit = _batchSize;
  String? _lastProjectId;
  TaskFilter? _lastFilter;
  bool _isSwitching = false;
  bool _isCompletedExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final tasks = ref.read(filteredTasksProvider);
    final activeCount = tasks.where((t) => !t.isCompleted).length;
    final completedCount = tasks.where((t) => t.isCompleted).length;

    if (_activeDisplayLimit < activeCount || (_isCompletedExpanded && _completedDisplayLimit < completedCount)) {
      setState(() {
        _activeDisplayLimit = (_activeDisplayLimit + _batchSize).clamp(_batchSize, activeCount + _batchSize);
        if (_isCompletedExpanded) {
          _completedDisplayLimit = (_completedDisplayLimit + _batchSize).clamp(_batchSize, completedCount + _batchSize);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    // Reset pagination window when switching projects or filters with 1-frame microtask deferral
    if (_lastProjectId != selectedProjectId || _lastFilter != activeFilter) {
      _lastProjectId = selectedProjectId;
      _lastFilter = activeFilter;
      _activeDisplayLimit = _batchSize;
      _completedDisplayLimit = _batchSize;
      _isCompletedExpanded = false;
      _isSwitching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSwitching = false;
          });
        }
      });
    }

    // Active project title
    final title = selectedProjectId != null
        ? (projectMap[selectedProjectId]?.name ?? 'Project')
        : activeFilter.label;

    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    final totalActiveCount = activeTasks.length;
    final visibleActiveCount = totalActiveCount > _activeDisplayLimit ? _activeDisplayLimit : totalActiveCount;
    final hasMoreActive = totalActiveCount > visibleActiveCount;

    final totalCompletedCount = completedTasks.length;
    final visibleCompletedCount = totalCompletedCount > _completedDisplayLimit ? _completedDisplayLimit : totalCompletedCount;
    final hasMoreCompleted = totalCompletedCount > visibleCompletedCount;

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
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalActiveCount',
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

          // Lazy-loaded Virtualized Task List with Viewport-sized batches
          Expanded(
            child: _isSwitching
                ? _TaskListSkeleton(isDark: isDark)
                : DragTarget<TaskItem>(
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
                                : activeFilter == TaskFilter.completed
                                    ? ListView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        itemCount: visibleCompletedCount + (hasMoreCompleted ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index < visibleCompletedCount) {
                                            final t = completedTasks[index];
                                            return DraggableTaskCard(key: ValueKey(t.id), task: t);
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Center(
                                              child: TextButton.icon(
                                                onPressed: _loadMore,
                                                icon: const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                label: Text(
                                                  'Showing $visibleCompletedCount of $totalCompletedCount completed tasks (click or scroll to load more)',
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : () {
                                        final hasCompletedSection = completedTasks.isNotEmpty;
                                        final moreActiveIndex = hasMoreActive ? visibleActiveCount : -1;
                                        final completedSectionIndex = visibleActiveCount + (hasMoreActive ? 1 : 0);
                                        final totalListItems = visibleActiveCount +
                                            (hasMoreActive ? 1 : 0) +
                                            (hasCompletedSection ? 1 : 0);

                                        return ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          itemCount: totalListItems,
                                          itemBuilder: (context, index) {
                                            if (index < visibleActiveCount) {
                                              final t = activeTasks[index];
                                              return DraggableTaskCard(key: ValueKey(t.id), task: t);
                                            }
                                            if (index == moreActiveIndex) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Center(
                                                  child: TextButton(
                                                    onPressed: _loadMore,
                                                    child: Text(
                                                      'Showing $visibleActiveCount of $totalActiveCount tasks (scroll to load more)',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? PlanColors.darkTextMuted
                                                            : PlanColors.lightTextMuted,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            if (index == completedSectionIndex) {
                                              return Theme(
                                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                child: ExpansionTile(
                                                  tilePadding: EdgeInsets.zero,
                                                  onExpansionChanged: (expanded) {
                                                    setState(() {
                                                      _isCompletedExpanded = expanded;
                                                    });
                                                  },
                                                  title: Text(
                                                    'Completed (${completedTasks.length})',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                                    ),
                                                  ),
                                                  children: _isCompletedExpanded
                                                      ? [
                                                          for (final t in completedTasks.take(_completedDisplayLimit))
                                                            DraggableTaskCard(key: ValueKey(t.id), task: t),
                                                          if (completedTasks.length > _completedDisplayLimit)
                                                            Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                                              child: Center(
                                                                child: TextButton(
                                                                  onPressed: () {
                                                                    setState(() {
                                                                      _completedDisplayLimit += _batchSize;
                                                                    });
                                                                  },
                                                                  child: Text(
                                                                    'Load more completed (${completedTasks.length - _completedDisplayLimit} remaining)',
                                                                    style: const TextStyle(fontSize: 11),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        ]
                                                      : const <Widget>[],
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        );
                                      }(),

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
                                      Icon(Icons.inbox_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Drop here to Unschedule',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

/// Lightweight skeleton placeholder during project selection transitions
class _TaskListSkeleton extends StatelessWidget {
  final bool isDark;
  const _TaskListSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
            ),
          ),
        );
      },
    );
  }
}

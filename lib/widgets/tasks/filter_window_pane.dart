import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';

enum FilterWindowStatus {
  uncompleted,
  completed,
  all,
}

enum FilterWindowSort {
  oldestFirst,
  newestFirst,
  tickTickOrder,
  priority,
  alphabetical,
}

class FilterWindowPane extends ConsumerStatefulWidget {
  final TaskItem eventTask;
  final bool isMainView;
  final ValueChanged<String?>? onProjectFilterChanged;
  final ValueChanged<String?>? onTagFilterChanged;
  final ValueChanged<String?>? onSectionFilterChanged;

  const FilterWindowPane({
    super.key,
    required this.eventTask,
    this.isMainView = false,
    this.onProjectFilterChanged,
    this.onTagFilterChanged,
    this.onSectionFilterChanged,
  });

  @override
  ConsumerState<FilterWindowPane> createState() => _FilterWindowPaneState();
}

class _FilterWindowPaneState extends ConsumerState<FilterWindowPane> {
  final _quickAddController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isAdding = false;
  bool _showSearch = false;

  FilterWindowStatus _statusFilter = FilterWindowStatus.uncompleted;
  FilterWindowSort _sortBy = FilterWindowSort.oldestFirst;

  @override
  void dispose() {
    _quickAddController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _priorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  List<TaskItem> _processTasks(List<TaskItem> rawTasks) {
    var result = List<TaskItem>.from(rawTasks);

    // 1. Status Filter
    switch (_statusFilter) {
      case FilterWindowStatus.uncompleted:
        result = result.where((t) => !t.isCompleted).toList();
        break;
      case FilterWindowStatus.completed:
        result = result.where((t) => t.isCompleted).toList();
        break;
      case FilterWindowStatus.all:
        break;
    }

    // 2. Search Query Filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((t) => t.title.toLowerCase().contains(query)).toList();
    }

    // 3. Sorting
    switch (_sortBy) {
      case FilterWindowSort.oldestFirst:
        result.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = aDate.compareTo(bDate);
          if (cmp != 0) return cmp;
          return (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
        });
        break;
      case FilterWindowSort.newestFirst:
        result.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = bDate.compareTo(aDate);
          if (cmp != 0) return cmp;
          return (b.sortOrder ?? 0).compareTo(a.sortOrder ?? 0);
        });
        break;
      case FilterWindowSort.tickTickOrder:
        result.sort((a, b) {
          final aOrder = a.sortOrder ?? 9999999;
          final bOrder = b.sortOrder ?? 9999999;
          final cmp = aOrder.compareTo(bOrder);
          if (cmp != 0) return cmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case FilterWindowSort.priority:
        result.sort((a, b) {
          final cmp = _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority));
          if (cmp != 0) return cmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case FilterWindowSort.alphabetical:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return result;
  }

  Future<void> _addNewTaskToProject(String targetProjectId) async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await ref.read(taskControllerProvider).addTask(
            title: title,
            projectId: targetProjectId,
            estimatedMinutes: 30,
          );
      _quickAddController.clear();
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectsStreamProvider).value ?? [];
    final projectMap = ref.watch(projectMapProvider);
    final allLinkedTasks = ref.watch(filterWindowTasksProvider(widget.eventTask));

    final targetProject = widget.eventTask.linkedProjectId != null
        ? projectMap[widget.eventTask.linkedProjectId]
        : null;
    final targetColor = targetProject?.color ?? PlanColors.primary;

    final completedCount = allLinkedTasks.where((t) => t.isCompleted).length;
    final totalCount = allLinkedTasks.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    final displayedTasks = _processTasks(allLinkedTasks);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.isMainView ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Source List Selector & Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: targetColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.link_rounded, size: 15, color: targetColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: widget.eventTask.linkedProjectId,
                  isExpanded: true,
                  hint: Text(
                    'Select a Project List to Link',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Disable Filter Window)', style: TextStyle(fontSize: 12)),
                    ),
                    ...projects.map((p) {
                      return DropdownMenuItem<String?>(
                        value: p.id,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: p.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: widget.onProjectFilterChanged,
                ),
              ),
            ),
            if (widget.eventTask.linkedProjectId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: targetColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completedCount/$totalCount Done',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: targetColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                  size: 16,
                  color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Search tasks in list',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchController.clear();
                  });
                },
              ),
            ],
          ],
        ),

        // Progress line
        if (widget.eventTask.linkedProjectId != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder).withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(targetColor),
            ),
          ),
          const SizedBox(height: 10),

          // Search Field (if enabled)
          if (_showSearch) ...[
            Container(
              height: 32,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filter tasks by keyword...',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 14),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 12),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],

          // Filter & Sort Control Toolbar
          Row(
            children: [
              // Status segment: Uncompleted / Completed / All
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? PlanColors.darkCard : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatusTab(
                        label: 'Active',
                        status: FilterWindowStatus.uncompleted,
                        count: totalCount - completedCount,
                        isDark: isDark,
                        targetColor: targetColor,
                      ),
                      _buildStatusTab(
                        label: 'Done',
                        status: FilterWindowStatus.completed,
                        count: completedCount,
                        isDark: isDark,
                        targetColor: targetColor,
                      ),
                      _buildStatusTab(
                        label: 'All',
                        status: FilterWindowStatus.all,
                        count: totalCount,
                        isDark: isDark,
                        targetColor: targetColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort dropdown
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? PlanColors.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<FilterWindowSort>(
                    value: _sortBy,
                    icon: const Icon(Icons.sort_rounded, size: 14),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: FilterWindowSort.oldestFirst,
                        child: Text('Oldest First'),
                      ),
                      DropdownMenuItem(
                        value: FilterWindowSort.newestFirst,
                        child: Text('Newest First'),
                      ),
                      DropdownMenuItem(
                        value: FilterWindowSort.tickTickOrder,
                        child: Text('TickTick Order'),
                      ),
                      DropdownMenuItem(
                        value: FilterWindowSort.priority,
                        child: Text('Priority (High)'),
                      ),
                      DropdownMenuItem(
                        value: FilterWindowSort.alphabetical,
                        child: Text('Title (A-Z)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Task List
          if (displayedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _searchController.text.isNotEmpty
                      ? 'No tasks match "${_searchController.text.trim()}".'
                      : _statusFilter == FilterWindowStatus.completed
                          ? 'No completed tasks yet.'
                          : _statusFilter == FilterWindowStatus.uncompleted
                              ? 'All caught up! No active tasks in this list.'
                              : 'No tasks currently in ${targetProject?.name ?? "this list"}.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (widget.isMainView)
            Expanded(
              child: _buildTaskList(displayedTasks, isDark, targetColor),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _buildTaskList(displayedTasks, isDark, targetColor),
            ),

          const SizedBox(height: 8),

          // Inline Quick-Add Row
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? PlanColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _quickAddController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add task to ${targetProject?.name ?? "linked list"}...',
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) {
                      if (widget.eventTask.linkedProjectId != null) {
                        _addNewTaskToProject(widget.eventTask.linkedProjectId!);
                      }
                    },
                  ),
                ),
                if (_isAdding)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(Icons.arrow_upward_rounded, size: 14, color: targetColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      if (widget.eventTask.linkedProjectId != null) {
                        _addNewTaskToProject(widget.eventTask.linkedProjectId!);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    if (widget.isMainView) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: targetColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }

  Widget _buildStatusTab({
    required String label,
    required FilterWindowStatus status,
    required int count,
    required bool isDark,
    required Color targetColor,
  }) {
    final isSelected = _statusFilter == status;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = status),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? PlanColors.darkBorder : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : PlanColors.lightTextPrimary)
                      : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? targetColor
                      : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<TaskItem> tasks, bool isDark, Color targetColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: !widget.isMainView,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder).withValues(alpha: 0.4),
        ),
        itemBuilder: (context, index) {
          final item = tasks[index];
          return _buildTaskRow(item, isDark, targetColor);
        },
      ),
    );
  }

  Widget _buildTaskRow(TaskItem item, bool isDark, Color targetColor) {
    return InkWell(
      onTap: () {
        // Clicking open in the inspector or toggle completion
        ref.read(taskControllerProvider).toggleComplete(item.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            // Checkbox
            InkWell(
              onTap: () => ref.read(taskControllerProvider).toggleComplete(item.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isCompleted
                        ? Colors.orange
                        : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                    width: 1.5,
                  ),
                  color: item.isCompleted ? Colors.orange : Colors.transparent,
                ),
                child: item.isCompleted
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),

            // Title
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                  color: item.isCompleted
                      ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                      : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Priority indicator (if not none)
            if (item.priority != 'none') ...[
              const SizedBox(width: 6),
              Icon(
                Icons.flag_rounded,
                size: 13,
                color: _getPriorityColor(item.priority),
              ),
            ],

            // Tags / Duration badge
            if (item.tags.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.tags.first,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                  ),
                ),
              ),
            ],

            if (item.estimatedMinutes > 0) ...[
              const SizedBox(width: 6),
              Text(
                TimeUtils.formatDuration(item.estimatedMinutes),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                ),
              ),
            ],

            // Quick inspect button
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.open_in_new_rounded,
                size: 12,
                color: (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted).withValues(alpha: 0.7),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              tooltip: 'Inspect task',
              onPressed: () {
                ref.read(activeInspectorSessionProvider.notifier).openTask(
                      item.id,
                      source: widget.isMainView ? InspectorSource.taskBar : InspectorSource.calendar,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}

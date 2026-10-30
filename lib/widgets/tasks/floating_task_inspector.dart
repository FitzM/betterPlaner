import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/layout_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import 'compact_time_picker_popup.dart';
import 'filter_window_pane.dart';

class FloatingTaskInspector extends ConsumerStatefulWidget {
  final TaskItem task;
  final VoidCallback onClose;

  const FloatingTaskInspector({
    super.key,
    required this.task,
    required this.onClose,
  });

  @override
  ConsumerState<FloatingTaskInspector> createState() => _FloatingTaskInspectorState();
}

class _FloatingTaskInspectorState extends ConsumerState<FloatingTaskInspector> {
  // Floating position and size
  double? _left;
  double? _top;
  double _width = 460;
  double _height = 600;

  late TextEditingController _titleController;
  late TextEditingController _notesController;
  final _newSubtaskController = TextEditingController();

  String? _positionedForTaskId;
  bool _userHasDragged = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _positionedForTaskId = widget.task.id;
  }

  @override
  void didUpdateWidget(covariant FloatingTaskInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _titleController.text = widget.task.title;
      _notesController.text = widget.task.notes ?? '';
      _userHasDragged = false;
      _positionedForTaskId = widget.task.id;
    }
  }

  void _calculatePosition({
    required ActiveInspectorSession? session,
    required Size screenSize,
  }) {
    // If the user has manually dragged the window for this task, preserve their dragged coordinates
    if (_userHasDragged && _left != null && _top != null) {
      _left = _left!.clamp(0.0, screenSize.width - 100);
      _top = _top!.clamp(0.0, screenSize.height - 100);
      return;
    }

    _width = _width.clamp(360.0, (screenSize.width - 40).clamp(360.0, 750.0));
    _height = _height.clamp(380.0, (screenSize.height - 40).clamp(380.0, 850.0));

    final anchor = session?.anchorRect;
    final source = session?.source ?? InspectorSource.taskBar;

    if (anchor != null) {
      if (source == InspectorSource.taskBar) {
        // Place directly to the right of the task bar card (TickTick style)
        double idealLeft = anchor.right + 12;
        // If placing it on the right would push it off-screen, place to the left of the item
        if (idealLeft + _width > screenSize.width - 16) {
          idealLeft = (anchor.left - _width - 12).clamp(16.0, screenSize.width - _width - 16);
        }
        _left = idealLeft;
        // Vertically align near the clicked card
        _top = (anchor.top - 20).clamp(16.0, (screenSize.height - _height - 24).clamp(16.0, screenSize.height));
      } else {
        // From calendar: place near the calendar event
        double idealLeft = anchor.right + 12;
        if (idealLeft + _width > screenSize.width - 16) {
          idealLeft = anchor.left - _width - 12;
        }
        if (idealLeft < 16) {
          idealLeft = (screenSize.width - _width - 24).clamp(16.0, screenSize.width - _width - 16);
        }
        _left = idealLeft;
        _top = (anchor.top - 20).clamp(16.0, (screenSize.height - _height - 24).clamp(16.0, screenSize.height));
      }
    } else {
      // Fallback if no anchor rect: use layout column widths
      if (source == InspectorSource.taskBar) {
        final sidebarWidth = ref.read(sidebarWidthProvider);
        final taskPaneWidth = ref.read(taskPaneWidthProvider);
        _left = (sidebarWidth + taskPaneWidth + 12).clamp(16.0, screenSize.width - _width - 16);
        _top = 48.0;
      } else {
        _left = (screenSize.width - _width - 32).clamp(16.0, screenSize.width - _width - 16);
        _top = 48.0;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final text = _titleController.text.trim();
    if (text.isNotEmpty && text != widget.task.title) {
      ref.read(taskControllerProvider).updateTask(widget.task.copyWith(title: text));
    }
  }

  void _saveNotes() {
    final text = _notesController.text.trim();
    final newNotes = text.isEmpty ? null : text;
    if (newNotes != widget.task.notes) {
      ref.read(taskControllerProvider).updateTask(widget.task.copyWith(notes: newNotes));
    }
  }

  Future<void> _pickDateTime() async {
    final result = await CompactTimePickerPopup.show(
      context,
      initialDate: widget.task.scheduledStart ?? widget.task.dueDate ?? DateTime.now(),
      initialIsAllDay: widget.task.isAllDay,
      initialIsTimeBlocked: widget.task.isTimeBlocked,
      initialStart: widget.task.scheduledStart,
      initialEnd: widget.task.scheduledEnd,
      initialDurationMinutes: widget.task.estimatedMinutes,
    );

    if (result == null) return;

    final controller = ref.read(taskControllerProvider);
    if (!result.isTimeBlocked && !result.isAllDay) {
      // Unscheduled
      await controller.updateTask(widget.task.copyWith(
        clearScheduledTimes: true,
        isTimeBlocked: false,
        isAllDay: false,
        dueDate: null,
      ));
    } else if (result.isAllDay) {
      // All day / Anytime for date
      await controller.setTaskForDateAnytime(widget.task.id, result.date ?? DateTime.now());
    } else {
      // Time-blocked
      await controller.updateTask(widget.task.copyWith(
        isTimeBlocked: true,
        isAllDay: false,
        scheduledStart: result.start,
        scheduledEnd: result.end,
        dueDate: result.date,
        estimatedMinutes: result.durationMinutes,
      ));
    }
  }

  void _setPriority(String priority) {
    ref.read(taskControllerProvider).updateTask(widget.task.copyWith(priority: priority));
  }

  void _setLinkedProject(String? projectId) {
    if (projectId == null) {
      ref.read(taskControllerProvider).updateTask(widget.task.copyWith(
            clearLinkedFilter: true,
          ));
    } else {
      ref.read(taskControllerProvider).setTaskFilterWindow(
            taskId: widget.task.id,
            linkedProjectId: projectId,
          );
    }
  }

  String _formatDateChipText() {
    if (widget.task.isAllDay && widget.task.scheduledStart != null) {
      final now = DateTime.now();
      final isToday = widget.task.scheduledStart!.year == now.year &&
          widget.task.scheduledStart!.month == now.month &&
          widget.task.scheduledStart!.day == now.day;
      if (isToday) return 'Today (Anytime)';
      return DateFormat('EEE, MMM d').format(widget.task.scheduledStart!);
    }

    if (widget.task.isTimeBlocked && widget.task.scheduledStart != null) {
      final start = widget.task.scheduledStart!;
      final end = widget.task.scheduledEnd ?? start.add(Duration(minutes: widget.task.estimatedMinutes));
      final timeStr = TimeUtils.formatRange(start, end);
      final now = DateTime.now();
      final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
      if (isToday) return 'Today, $timeStr';
      return '${DateFormat('MMM d').format(start)}, $timeStr';
    }

    if (widget.task.dueDate != null) {
      return DateFormat('EEE, MMM d').format(widget.task.dueDate!);
    }

    return 'Due Date';
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectMap = ref.watch(projectMapProvider);
    final projects = ref.watch(projectsStreamProvider).value ?? [];
    final currentProject = projectMap[widget.task.projectId];
    final projectColor = currentProject?.color ?? PlanColors.primary;

    final subtasks = ref.watch(subtasksForParentProvider(widget.task.id));

    final session = ref.watch(activeInspectorSessionProvider);
    if (_positionedForTaskId != widget.task.id) {
      _positionedForTaskId = widget.task.id;
      _userHasDragged = false;
    }
    _calculatePosition(session: session, screenSize: screenSize);

    final dateChipText = _formatDateChipText();
    final hasSchedule = widget.task.isTimeBlocked || widget.task.isAllDay || widget.task.dueDate != null;

    return Positioned(
      left: _left,
      top: _top,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.black.withValues(alpha: 0.28),
        color: Colors.transparent,
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: isDark ? PlanColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header Toolbar & Drag Handle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _userHasDragged = true;
                    _left = (_left ?? 0) + details.delta.dx;
                    _top = (_top ?? 0) + details.delta.dy;
                  });
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Drag indicator handle
                      MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Task Checkbox (Complete / Uncomplete)
                      InkWell(
                        onTap: () => ref.read(taskControllerProvider).toggleComplete(widget.task.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.task.isCompleted
                                  ? projectColor
                                  : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                              width: 1.5,
                            ),
                            color: widget.task.isCompleted ? projectColor : Colors.transparent,
                          ),
                          child: widget.task.isCompleted
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Thin divider
                      Container(
                        width: 1,
                        height: 16,
                        color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                      ),
                      const SizedBox(width: 10),

                      // Compact Date & Duration Chip (TickTick style)
                      InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasSchedule
                                ? PlanColors.primary.withValues(alpha: 0.12)
                                : (isDark ? PlanColors.darkBg : const Color(0xFFEDF2F7)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasSchedule
                                  ? PlanColors.primary.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.task.isAllDay
                                    ? Icons.wb_sunny_rounded
                                    : Icons.calendar_today_rounded,
                                size: 12.5,
                                color: hasSchedule
                                    ? PlanColors.primary
                                    : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                dateChipText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: hasSchedule ? FontWeight.w700 : FontWeight.w500,
                                  color: hasSchedule
                                      ? PlanColors.primary
                                      : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Priority Flag Button & Popup
                      PopupMenuButton<String>(
                        tooltip: 'Set Priority',
                        initialValue: widget.task.priority,
                        onSelected: _setPriority,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'none', child: Text('None')),
                          const PopupMenuItem(
                            value: 'low',
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, size: 14, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text('Low'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'medium',
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, size: 14, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Medium'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'high',
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, size: 14, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('High'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'urgent',
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, size: 14, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Urgent'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: widget.task.priority != 'none'
                                ? _getPriorityColor(widget.task.priority).withValues(alpha: 0.15)
                                : Colors.transparent,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            size: 16,
                            color: _getPriorityColor(widget.task.priority),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Smart Filter Window Toggle Icon
                      IconButton(
                        tooltip: widget.task.hasLinkedFilter
                            ? 'Smart Filter Window (Enabled)'
                            : 'Convert to Smart Filter Window',
                        icon: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: widget.task.hasLinkedFilter
                              ? PlanColors.primary
                              : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          if (widget.task.hasLinkedFilter) {
                            _setLinkedProject(null);
                          } else {
                            // Link to current project or first available project
                            _setLinkedProject(widget.task.projectId);
                          }
                        },
                      ),
                      const SizedBox(width: 6),

                      // Close Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Close Inspector',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),

              // Title Area (Large bold inline editable text field)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _saveTitle();
                  },
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                      color: widget.task.isCompleted
                          ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                          : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Task Title',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _saveTitle(),
                  ),
                ),
              ),

              // Divider under title
              Divider(
                height: 1,
                color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder).withValues(alpha: 0.5),
              ),

              // MAIN VIEW BODY
              Expanded(
                child: widget.task.hasLinkedFilter
                    // Smart Filter Window IS THE MAIN VIEW
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: FilterWindowPane(
                          eventTask: widget.task,
                          isMainView: true,
                          onProjectFilterChanged: (newProjId) {
                            _setLinkedProject(newProjId);
                          },
                        ),
                      )
                    // Normal Task: Notes & Subtasks
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Convert to Filter Window Prompt
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: PlanColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: PlanColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tips_and_updates_rounded, size: 16, color: PlanColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Want this event to link to a project list (e.g. 🏠 House tasks)?',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _setLinkedProject(widget.task.projectId),
                                    child: const Text('Link List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Notes field
                            Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Focus(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus) _saveNotes();
                              },
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 80),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? PlanColors.darkBg : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                  ),
                                ),
                                child: TextField(
                                  controller: _notesController,
                                  maxLines: null,
                                  style: const TextStyle(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: 'Write something or type / for commands...',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Subtasks Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SUBTASKS (${subtasks.where((s) => s.isCompleted).length}/${subtasks.length})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            if (subtasks.isNotEmpty) ...[
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                  ),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: subtasks.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                  ),
                                  itemBuilder: (context, index) {
                                    final sub = subtasks[index];
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      leading: InkWell(
                                        onTap: () => ref.read(taskControllerProvider).toggleComplete(sub.id),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 15,
                                          height: 15,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sub.isCompleted ? projectColor : Colors.grey,
                                              width: 1.5,
                                            ),
                                            color: sub.isCompleted ? projectColor : Colors.transparent,
                                          ),
                                          child: sub.isCompleted
                                              ? const Icon(Icons.check, size: 9, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      title: Text(
                                        sub.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                          color: sub.isCompleted
                                              ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                                              : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close, size: 12),
                                        onPressed: () => ref.read(taskControllerProvider).deleteTask(sub.id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Add subtask input
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _newSubtaskController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: 'Add subtask...',
                                        hintStyle: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      onSubmitted: (val) async {
                                        if (val.trim().isNotEmpty) {
                                          await ref.read(taskControllerProvider).addSubtask(
                                                parentTaskId: widget.task.id,
                                                title: val.trim(),
                                                projectId: widget.task.projectId,
                                              );
                                          _newSubtaskController.clear();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  color: PlanColors.primary,
                                  onPressed: () async {
                                    final val = _newSubtaskController.text.trim();
                                    if (val.isNotEmpty) {
                                      await ref.read(taskControllerProvider).addSubtask(
                                            parentTaskId: widget.task.id,
                                            title: val,
                                            projectId: widget.task.projectId,
                                          );
                                      _newSubtaskController.clear();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),

              // Bottom Footer (Project Selector, Delete, and Resize Handle)
              Container(
                height: 42,
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder).withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Project tag dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: projectColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.task.projectId,
                          isDense: true,
                          items: projects.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: p.color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newProj) {
                            if (newProj != null && newProj != widget.task.projectId) {
                              ref.read(taskControllerProvider).updateTask(
                                    widget.task.copyWith(projectId: newProj),
                                  );
                            }
                          },
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Delete Task Button
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                      tooltip: 'Delete Task',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Task?'),
                            content: Text('Are you sure you want to delete "${widget.task.title}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.of(c).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(taskControllerProvider).deleteTask(widget.task.id);
                          widget.onClose();
                        }
                      },
                    ),

                    // Resize Grip Handle at bottom-right corner
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _width += details.delta.dx;
                            _height += details.delta.dy;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.south_east_rounded,
                            size: 13,
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


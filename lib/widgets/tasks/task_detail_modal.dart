import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import 'compact_time_picker_popup.dart';
import 'filter_window_pane.dart';

class TaskDetailModal extends ConsumerStatefulWidget {
  final TaskItem? task;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final String? initialProjectId;
  final String? parentTaskId;

  const TaskDetailModal({
    super.key,
    this.task,
    this.initialStart,
    this.initialEnd,
    this.initialProjectId,
    this.parentTaskId,
  });

  static Future<void> show(
    BuildContext context, {
    TaskItem? task,
    DateTime? initialStart,
    DateTime? initialEnd,
    String? initialProjectId,
    String? parentTaskId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TaskDetailModal(
        task: task,
        initialStart: initialStart,
        initialEnd: initialEnd,
        initialProjectId: initialProjectId,
        parentTaskId: parentTaskId,
      ),
    );
  }

  @override
  ConsumerState<TaskDetailModal> createState() => _TaskDetailModalState();
}

class _TaskDetailModalState extends ConsumerState<TaskDetailModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _newSubtaskController;

  late String _selectedProjectId;
  late int _estimatedMinutes;
  late String _priority;
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;
  DateTime? _dueDate;
  late bool _isTimeBlocked;
  late bool _isAllDay;
  late bool _isCompleted;
  String? _parentTaskId;

  // Filter Window (Symlink) fields
  bool _isFilterWindowEnabled = false;
  String? _linkedProjectId;
  String? _linkedTag;
  String? _linkedSection;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _newSubtaskController = TextEditingController();

    _selectedProjectId = task?.projectId ?? widget.initialProjectId ?? 'proj_inbox';
    _estimatedMinutes = task?.estimatedMinutes ??
        (widget.initialStart != null && widget.initialEnd != null
            ? widget.initialEnd!.difference(widget.initialStart!).inMinutes
            : 30);
    _priority = task?.priority ?? 'none';

    _scheduledStart = task?.scheduledStart ?? widget.initialStart;
    _scheduledEnd = task?.scheduledEnd ?? widget.initialEnd;
    _dueDate = task?.dueDate;
    _isAllDay = task?.isAllDay ??
        (widget.initialStart != null && widget.initialEnd != null && widget.initialStart == widget.initialEnd);
    _isTimeBlocked = task?.isTimeBlocked ?? (_scheduledStart != null && !_isAllDay);
    _isCompleted = task?.isCompleted ?? false;
    _parentTaskId = task?.parentTaskId ?? widget.parentTaskId;

    _isFilterWindowEnabled = task?.hasLinkedFilter ?? false;
    _linkedProjectId = task?.linkedProjectId;
    _linkedTag = task?.linkedTag;
    _linkedSection = task?.linkedSection;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final controller = ref.read(taskControllerProvider);

    DateTime? finalStart = _scheduledStart;
    DateTime? finalEnd = _scheduledEnd;
    DateTime? finalDue;

    if (_isAllDay) {
      final baseDate = _scheduledStart ?? DateTime.now();
      finalStart = DateTime(baseDate.year, baseDate.month, baseDate.day);
      finalEnd = DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 59, 59);
      finalDue = finalStart;
    } else if (_isTimeBlocked && finalStart != null) {
      finalEnd ??= finalStart.add(Duration(minutes: _estimatedMinutes));
      finalDue = finalStart;
    }

    if (widget.task == null) {
      // Create new task
      await controller.addTask(
        title: title,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        projectId: _selectedProjectId,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        dueDate: finalDue,
        parentTaskId: _parentTaskId,
        scheduledStart: finalStart,
        scheduledEnd: finalEnd,
        isTimeBlocked: _isTimeBlocked && !_isAllDay,
        isAllDay: _isAllDay,
        linkedProjectId: _isFilterWindowEnabled ? _linkedProjectId : null,
        linkedTag: _isFilterWindowEnabled ? _linkedTag : null,
        linkedSection: _isFilterWindowEnabled ? _linkedSection : null,
      );
    } else {
      // Update existing task
      final updated = widget.task!.copyWith(
        title: title,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        projectId: _selectedProjectId,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        dueDate: finalDue,
        parentTaskId: _parentTaskId,
        isCompleted: _isCompleted,
        isTimeBlocked: _isTimeBlocked && !_isAllDay,
        isAllDay: _isAllDay,
        scheduledStart: finalStart,
        scheduledEnd: finalEnd,
        clearScheduledTimes: !_isTimeBlocked && !_isAllDay,
        linkedProjectId: _isFilterWindowEnabled ? _linkedProjectId : null,
        linkedTag: _isFilterWindowEnabled ? _linkedTag : null,
        linkedSection: _isFilterWindowEnabled ? _linkedSection : null,
        clearLinkedFilter: !_isFilterWindowEnabled,
      );
      await controller.updateTask(updated);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleAddSubtask() async {
    final subtaskTitle = _newSubtaskController.text.trim();
    if (subtaskTitle.isEmpty) return;

    if (widget.task != null) {
      await ref.read(taskControllerProvider).addSubtask(
            parentTaskId: widget.task!.id,
            title: subtaskTitle,
            projectId: _selectedProjectId,
          );
      _newSubtaskController.clear();
      setState(() {});
    }
  }

  Future<void> _pickDateTime() async {
    final result = await CompactTimePickerPopup.show(
      context,
      initialDate: _scheduledStart ?? _dueDate ?? DateTime.now(),
      initialIsAllDay: _isAllDay,
      initialIsTimeBlocked: _isTimeBlocked,
      initialStart: _scheduledStart,
      initialEnd: _scheduledEnd,
      initialDurationMinutes: _estimatedMinutes,
    );

    if (result == null) return;

    setState(() {
      if (!result.isTimeBlocked && !result.isAllDay) {
        _isTimeBlocked = false;
        _isAllDay = false;
        _scheduledStart = null;
        _scheduledEnd = null;
        _dueDate = null;
      } else if (result.isAllDay) {
        _isAllDay = true;
        _isTimeBlocked = false;
        _scheduledStart = result.date ?? DateTime.now();
        _scheduledEnd = null;
        _dueDate = result.date;
      } else {
        _isTimeBlocked = true;
        _isAllDay = false;
        _scheduledStart = result.start;
        _scheduledEnd = result.end;
        _estimatedMinutes = result.durationMinutes;
        _dueDate = result.date;
      }
    });
  }

  String _getScheduleSummaryText() {
    if (_isAllDay && _scheduledStart != null) {
      final now = DateTime.now();
      final isToday = _scheduledStart!.year == now.year &&
          _scheduledStart!.month == now.month &&
          _scheduledStart!.day == now.day;
      if (isToday) return 'Today (Anytime)';
      return '${DateFormat("EEE, MMM d").format(_scheduledStart!)} (Anytime)';
    }

    if (_isTimeBlocked && _scheduledStart != null) {
      final end = _scheduledEnd ?? _scheduledStart!.add(Duration(minutes: _estimatedMinutes));
      final timeRange = TimeUtils.formatRange(_scheduledStart!, end);
      final now = DateTime.now();
      final isToday = _scheduledStart!.year == now.year &&
          _scheduledStart!.month == now.month &&
          _scheduledStart!.day == now.day;
      if (isToday) return 'Today, $timeRange (${_estimatedMinutes}m)';
      return '${DateFormat("MMM d").format(_scheduledStart!)}, $timeRange (${_estimatedMinutes}m)';
    }

    if (_dueDate != null) {
      return 'Due ${DateFormat("MMM d").format(_dueDate!)}';
    }

    return 'Unscheduled (Click to set time)';
  }

  TaskItem _buildPreviewTask() {
    return (widget.task ?? TaskItem(
      id: 'preview_task',
      title: _titleController.text.trim().isEmpty ? 'Event' : _titleController.text.trim(),
      projectId: _selectedProjectId,
    )).copyWith(
      linkedProjectId: _linkedProjectId,
      linkedTag: _linkedTag,
      linkedSection: _linkedSection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectsProvider);
    final parentTask = _parentTaskId != null
        ? ref.watch(parentTaskProvider(_parentTaskId))
        : null;

    final subtasks = widget.task != null
        ? ref.watch(subtasksForParentProvider(widget.task!.id))
        : <TaskItem>[];

    return Dialog(
      backgroundColor: isDark ? PlanColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Parent link (if subtask) + Close button
              Row(
                children: [
                  if (_parentTaskId != null) ...[
                    InkWell(
                      onTap: () {
                        if (parentTask != null) {
                          Navigator.of(context).pop();
                          TaskDetailModal.show(context, task: parentTask);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: PlanColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.subdirectory_arrow_right_rounded,
                                size: 14, color: PlanColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Part of: ${parentTask?.title ?? "Parent Task"}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PlanColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ] else ...[
                    Text(
                      widget.task == null ? 'Create Task / Event' : 'Task Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable form body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Title Input
                      TextField(
                        controller: _titleController,
                        autofocus: widget.task == null,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What needs to be done? (e.g. Accomplish house tasks)',
                          hintStyle: TextStyle(
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _saveTask(),
                      ),
                      const SizedBox(height: 16),

                      // Project & Priority row
                      Row(
                        children: [
                          // Project selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PROJECT LIST',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedProjectId,
                                      isExpanded: true,
                                      items: projects.map((p) {
                                        return DropdownMenuItem<String>(
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
                                              Text(p.name, style: const TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedProjectId = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Priority selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _priority,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'none', child: Text('None', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'low', child: Text('Low', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'medium', child: Text('Medium', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'high', child: Text('High', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'urgent', child: Text('Urgent', style: TextStyle(fontSize: 13))),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _priority = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Compact Date & Duration Settings (TickTick style)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? PlanColors.darkBg : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'WHEN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickDateTime,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (_isTimeBlocked || _isAllDay)
                                        ? PlanColors.primary.withValues(alpha: 0.12)
                                        : (isDark ? PlanColors.darkCard : Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (_isTimeBlocked || _isAllDay)
                                          ? PlanColors.primary.withValues(alpha: 0.35)
                                          : (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isAllDay
                                            ? Icons.wb_sunny_rounded
                                            : (_isTimeBlocked
                                                ? Icons.schedule_rounded
                                                : Icons.calendar_today_rounded),
                                        size: 14,
                                        color: (_isTimeBlocked || _isAllDay)
                                            ? PlanColors.primary
                                            : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getScheduleSummaryText(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: (_isTimeBlocked || _isAllDay) ? FontWeight.w700 : FontWeight.w500,
                                            color: (_isTimeBlocked || _isAllDay)
                                                ? PlanColors.primary
                                                : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.edit_calendar_rounded,
                                        size: 15,
                                        color: (_isTimeBlocked || _isAllDay)
                                            ? PlanColors.primary
                                            : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_isTimeBlocked || _isAllDay) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                tooltip: 'Clear schedule (Unschedule)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () {
                                  setState(() {
                                    _isTimeBlocked = false;
                                    _isAllDay = false;
                                    _scheduledStart = null;
                                    _scheduledEnd = null;
                                    _dueDate = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Smart Filter Window ("Symlink Group") Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 16, color: PlanColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'SMART FILTER WINDOW (SYMLINK GROUP)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _isFilterWindowEnabled,
                            activeThumbColor: PlanColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _isFilterWindowEnabled = val;
                                if (val && (_linkedProjectId == null || _linkedProjectId!.isEmpty)) {
                                  // Default to house tasks or first non-inbox project
                                  final houseProj = projects.where((p) => p.name.toLowerCase().contains('house')).firstOrNull;
                                  _linkedProjectId = houseProj?.id ?? (projects.isNotEmpty ? projects.first.id : 'proj_inbox');
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Point this event to a project list (e.g. 🏠House Tasks) to complete items directly from this event UI without making them subtasks.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                        ),
                      ),
                      if (_isFilterWindowEnabled) ...[
                        const SizedBox(height: 10),
                        FilterWindowPane(
                          eventTask: _buildPreviewTask(),
                          onProjectFilterChanged: (newProjId) {
                            setState(() => _linkedProjectId = newProjId);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Notes Input
                      Text(
                        'NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add description or extra details...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Standard Subtasks Section (Shown for existing tasks)
                      if (widget.task != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SUBTASKS (${subtasks.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (subtasks.isNotEmpty)
                              Text(
                                '${subtasks.where((s) => s.isCompleted).length}/${subtasks.length} done',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // List of existing subtasks
                        if (subtasks.isNotEmpty)
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
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    TaskDetailModal.show(context, task: sub);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Completion checkbox
                                        InkWell(
                                          onTap: () => ref.read(taskControllerProvider).toggleComplete(sub.id),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: sub.isCompleted
                                                    ? PlanColors.primary
                                                    : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                                                width: 1.5,
                                              ),
                                              color: sub.isCompleted ? PlanColors.primary : Colors.transparent,
                                            ),
                                            child: sub.isCompleted
                                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Subtask title
                                        Expanded(
                                          child: Text(
                                            sub.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                              color: sub.isCompleted
                                                  ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                                                  : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                            ),
                                          ),
                                        ),

                                        // Scheduled tag if time-blocked
                                        if (sub.isTimeBlocked && sub.scheduledStart != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: PlanColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              DateFormat('MMM d, h:mm a').format(sub.scheduledStart!),
                                              style: const TextStyle(fontSize: 10, color: PlanColors.primary),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Inline rapid subtask input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newSubtaskController,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '+ Add subtask (press Enter)...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onSubmitted: (_) => _handleAddSubtask(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: PlanColors.primary),
                              onPressed: _handleAddSubtask,
                              tooltip: 'Add subtask',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.task != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Delete Task',
                      onPressed: () {
                        ref.read(taskControllerProvider).deleteTask(widget.task!.id);
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PlanColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(widget.task == null ? 'Create' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

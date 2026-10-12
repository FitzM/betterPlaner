import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';

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
  late bool _isTimeBlocked;
  late bool _isCompleted;
  String? _parentTaskId;

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
    _isTimeBlocked = task?.isTimeBlocked ?? (_scheduledStart != null);
    _isCompleted = task?.isCompleted ?? false;
    _parentTaskId = task?.parentTaskId ?? widget.parentTaskId;
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

    if (widget.task == null) {
      // Create new task
      await controller.addTask(
        title: title,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        projectId: _selectedProjectId,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        parentTaskId: _parentTaskId,
        scheduledStart: _scheduledStart,
        scheduledEnd: _scheduledEnd,
        isTimeBlocked: _isTimeBlocked,
      );
    } else {
      // Update existing task
      final updated = widget.task!.copyWith(
        title: title,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        projectId: _selectedProjectId,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        parentTaskId: _parentTaskId,
        isCompleted: _isCompleted,
        isTimeBlocked: _isTimeBlocked,
        scheduledStart: _scheduledStart,
        scheduledEnd: _scheduledEnd,
        clearScheduledTimes: !_isTimeBlocked,
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
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
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
                      widget.task == null ? 'Create Task' : 'Task Details',
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
                          hintText: 'What needs to be done?',
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
                                  'PROJECT',
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

                      // Schedule & Duration Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? PlanColors.darkBg : PlanColors.lightSidebar,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 16, color: PlanColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isTimeBlocked && _scheduledStart != null
                                          ? 'Scheduled: ${TimeUtils.formatRange(_scheduledStart!, _scheduledEnd ?? _scheduledStart!.add(Duration(minutes: _estimatedMinutes)))}'
                                          : 'Estimated Duration: ${_estimatedMinutes}m',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isTimeBlocked)
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isTimeBlocked = false;
                                        _scheduledStart = null;
                                        _scheduledEnd = null;
                                      });
                                    },
                                    child: const Text(
                                      'Unschedule',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Duration quick buttons
                            Wrap(
                              spacing: 6,
                              children: [15, 30, 45, 60, 90].map((mins) {
                                final isSelected = _estimatedMinutes == mins;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _estimatedMinutes = mins;
                                      if (_scheduledStart != null) {
                                        _scheduledEnd = _scheduledStart!.add(Duration(minutes: mins));
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? PlanColors.primary
                                          : (isDark ? PlanColors.darkCard : Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected
                                          ? PlanColors.primary
                                          : (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                                      ),
                                    ),
                                    child: Text(
                                      TimeUtils.formatDuration(mins),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? Colors.white : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
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
                          hintText: 'Add description or checklist...',
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

                      // Subtasks Section (Shown for existing tasks)
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

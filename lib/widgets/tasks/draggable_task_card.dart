import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';

class DraggableTaskCard extends ConsumerWidget {
  final TaskItem task;

  const DraggableTaskCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final project = ref.watch(projectMapProvider.select((m) => m[task.projectId]));
    final projectColor = project?.color ?? PlanColors.projectPalette[0];

    final parentTask = task.parentTaskId != null && task.parentTaskId!.isNotEmpty
        ? ref.watch(taskMapProvider.select((m) => m[task.parentTaskId!]))
        : null;
    final subtasks = task.isChecklist
        ? (ref.watch(subtaskMapProvider.select((m) => m[task.id])) ?? const <TaskItem>[])
        : const <TaskItem>[];

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
            ),
          ),
          const SizedBox(width: 8),

          // Completion Checkbox
          InkWell(
            onTap: () => ref.read(taskControllerProvider).toggleComplete(task.id),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted
                      ? PlanColors.primary
                      : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                  width: 1.8,
                ),
                color: task.isCompleted ? PlanColors.primary : Colors.transparent,
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // Title & Project Tag (Clickable to open floating inspector overlay)
          Expanded(
            child: Builder(
              builder: (cardContext) => InkWell(
                onTap: () {
                  final renderBox = cardContext.findRenderObject() as RenderBox?;
                  Rect? anchorRect;
                  if (renderBox != null && renderBox.hasSize) {
                    final offset = renderBox.localToGlobal(Offset.zero);
                    anchorRect = offset & renderBox.size;
                  }
                  ref.read(activeInspectorSessionProvider.notifier).openTask(
                        task.id,
                        source: InspectorSource.taskBar,
                        anchorRect: anchorRect,
                      );
                },
                borderRadius: BorderRadius.circular(4),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted
                          ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                          : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Project tag pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: projectColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: projectColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                project?.name ?? 'Inbox',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: projectColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Duration chip
                      Text(
                        TimeUtils.formatDuration(task.estimatedMinutes),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                        ),
                      ),

                      // Scheduled indicator
                      if (task.isTimeBlocked && task.scheduledStart != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: PlanColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 10, color: PlanColors.primary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  TimeUtils.formatTime(task.scheduledStart!),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: PlanColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (task.isAnytimeForDate(DateTime.now()))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.wb_sunny_rounded, size: 10, color: Colors.orange),
                              SizedBox(width: 3),
                              Text(
                                'Today (Anytime)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Filter Window symlink indicator
                      if (task.hasLinkedFilter)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: PlanColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.link_rounded, size: 10, color: PlanColors.primary),
                              SizedBox(width: 3),
                              Text(
                                'Filter Window',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: PlanColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Subtask of parent indicator
                      if (parentTask != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: PlanColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 10, color: PlanColors.primary),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  parentTask.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: PlanColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Subtasks count badge
                      if (subtasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_rounded, size: 11, color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                              const SizedBox(width: 3),
                              Text(
                                '${subtasks.where((s) => s.isCompleted).length}/${subtasks.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

          // Set for Today (Anytime) button
          IconButton(
            icon: Icon(
              task.isAnytimeForDate(DateTime.now())
                  ? Icons.wb_sunny_rounded
                  : Icons.wb_sunny_outlined,
              size: 15,
              color: task.isAnytimeForDate(DateTime.now())
                  ? Colors.orange
                  : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
            ),
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: task.isAnytimeForDate(DateTime.now())
                ? 'Remove from Today'
                : 'Set for Today (Anytime)',
            onPressed: () {
              if (task.isAnytimeForDate(DateTime.now())) {
                ref.read(taskControllerProvider).unscheduleTask(task.id);
              } else {
                ref.read(taskControllerProvider).setTaskForDateAnytime(task.id, DateTime.now());
              }
            },
          ),
          const SizedBox(width: 6),

          // Delete or Unschedule button
          if (task.isTimeBlocked)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Unschedule',
              onPressed: () => ref.read(taskControllerProvider).unscheduleTask(task.id),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete Task',
              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
              onPressed: () => ref.read(taskControllerProvider).deleteTask(task.id),
            ),
        ],
      ),
    );

    // Draggable wrapper
    return Draggable<TaskItem>(
      data: task,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? PlanColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PlanColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: projectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardContent,
      ),
      child: cardContent,
    );
  }
}

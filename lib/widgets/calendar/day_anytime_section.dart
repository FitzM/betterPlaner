import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../tasks/task_detail_modal.dart';

class DayAnytimeSection extends ConsumerStatefulWidget {
  final DateTime date;
  final double width;

  const DayAnytimeSection({
    super.key,
    required this.date,
    required this.width,
  });

  @override
  ConsumerState<DayAnytimeSection> createState() => _DayAnytimeSectionState();
}

class _DayAnytimeSectionState extends ConsumerState<DayAnytimeSection> {
  bool _isHoveringDrop = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anytimeTasks = ref.watch(anytimeTasksForDateFamily(widget.date));
    final projectMap = ref.watch(projectMapProvider);
    final isToday = TimeUtils.isToday(widget.date);

    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (_) {
        if (!_isHoveringDrop) setState(() => _isHoveringDrop = true);
      },
      onLeave: (_) {
        if (_isHoveringDrop) setState(() => _isHoveringDrop = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isHoveringDrop = false);
        ref.read(taskControllerProvider).setTaskForDateAnytime(details.data.id, widget.date);
      },
      builder: (context, candidateData, rejectedData) {
        final isDropping = _isHoveringDrop || candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          decoration: BoxDecoration(
            color: isDropping
                ? PlanColors.primary.withValues(alpha: 0.12)
                : (isDark ? PlanColors.darkBg.withValues(alpha: 0.8) : const Color(0xFFF8FAFC)),
            border: Border(
              bottom: BorderSide(
                color: isDropping
                    ? PlanColors.primary
                    : (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                width: isDropping ? 1.5 : 1.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 11,
                        color: isToday
                            ? PlanColors.primary
                            : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDropping
                            ? 'DROP TO SET ANYTIME'
                            : (anytimeTasks.isEmpty ? 'ANYTIME' : 'ANYTIME (${anytimeTasks.length})'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: isDropping
                              ? PlanColors.primary
                              : (isToday
                                  ? PlanColors.primary
                                  : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      TaskDetailModal.show(
                        context,
                        initialStart: widget.date,
                        initialEnd: widget.date,
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 13,
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Tasks chips
              if (anytimeTasks.isNotEmpty) ...[
                const SizedBox(height: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: anytimeTasks.map((task) {
                        final project = projectMap[task.projectId];
                        final projectColor = project?.color ?? PlanColors.primary;
                        final hasFilter = task.hasLinkedFilter;
                        final linkedProject = hasFilter && task.linkedProjectId != null
                            ? projectMap[task.linkedProjectId]
                            : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Draggable<TaskItem>(
                            data: task,
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.transparent,
                              child: Container(
                                width: 220,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? PlanColors.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: projectColor, width: 1.5),
                                ),
                                child: Text(
                                  task.title,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            child: Builder(
                              builder: (chipContext) => InkWell(
                                onTap: () {
                                  final renderBox = chipContext.findRenderObject() as RenderBox?;
                                  Rect? anchorRect;
                                  if (renderBox != null && renderBox.hasSize) {
                                    final offset = renderBox.localToGlobal(Offset.zero);
                                    anchorRect = offset & renderBox.size;
                                  }
                                  ref.read(activeInspectorSessionProvider.notifier).openTask(
                                        task.id,
                                        source: InspectorSource.calendar,
                                        anchorRect: anchorRect,
                                      );
                                },
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? PlanColors.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Complete checkbox
                                    InkWell(
                                      onTap: () => ref.read(taskControllerProvider).toggleComplete(task.id),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: task.isCompleted
                                                ? projectColor
                                                : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                                            width: 1.4,
                                          ),
                                          color: task.isCompleted ? projectColor : Colors.transparent,
                                        ),
                                        child: task.isCompleted
                                            ? const Icon(Icons.check, size: 8, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Task Title
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                          color: task.isCompleted
                                              ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                                              : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Filter window symlink badge
                                    if (hasFilter) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (linkedProject?.color ?? PlanColors.primary).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.link_rounded,
                                              size: 9,
                                              color: linkedProject?.color ?? PlanColors.primary,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              linkedProject?.name ?? 'Filter',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: linkedProject?.color ?? PlanColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ] else if (isDropping) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Drop task here for Anytime Today',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: PlanColors.primary,
                    ),
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


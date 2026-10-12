import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../tasks/task_detail_modal.dart';

class ScheduledTaskBlock extends ConsumerStatefulWidget {
  final TaskItem task;
  final double hourHeight;

  const ScheduledTaskBlock({
    super.key,
    required this.task,
    this.hourHeight = TimeUtils.defaultHourHeight,
  });

  @override
  ConsumerState<ScheduledTaskBlock> createState() => _ScheduledTaskBlockState();
}

class _ScheduledTaskBlockState extends ConsumerState<ScheduledTaskBlock> {
  double _resizeDeltaBottomY = 0;
  bool _isResizingBottom = false;

  double _resizeDeltaTopY = 0;
  bool _isResizingTop = false;

  bool get _isResizing => _isResizingBottom || _isResizingTop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectMap = ref.watch(projectMapProvider);
    final project = projectMap[widget.task.projectId];
    final projectColor = project?.color ?? PlanColors.projectPalette[0];
    final snapStep = ref.watch(settingsProvider).timeSnapMinutes;

    final start = widget.task.scheduledStart ?? DateTime.now();
    final initialDuration = widget.task.estimatedMinutes > 0 ? widget.task.estimatedMinutes : 30;
    final end = widget.task.scheduledEnd ?? start.add(Duration(minutes: initialDuration));

    final baseTop = TimeUtils.calculateYOffset(start, hourHeight: widget.hourHeight);
    final baseHeight = TimeUtils.calculateBlockHeight(initialDuration, hourHeight: widget.hourHeight);

    double effectiveTop = baseTop;
    double effectiveHeight = baseHeight;
    DateTime effectiveStart = start;
    DateTime effectiveEnd = end;

    if (_isResizingBottom) {
      final candidateHeight = (baseHeight + _resizeDeltaBottomY).clamp(
        TimeUtils.calculateBlockHeight(5, hourHeight: widget.hourHeight),
        widget.hourHeight * 24,
      );
      final candidateMinutes = ((candidateHeight / widget.hourHeight) * 60).round();
      final snappedMinutes = TimeUtils.snapToNearestMinutes(candidateMinutes, step: snapStep).clamp(5, 24 * 60);
      effectiveHeight = TimeUtils.calculateBlockHeight(snappedMinutes, hourHeight: widget.hourHeight);
      effectiveEnd = start.add(Duration(minutes: snappedMinutes));
    } else if (_isResizingTop) {
      final minDurationPx = TimeUtils.calculateBlockHeight(5, hourHeight: widget.hourHeight);
      final maxTop = baseTop + baseHeight - minDurationPx;
      final candidateTop = (baseTop + _resizeDeltaTopY).clamp(0.0, maxTop);
      final candidateMinutes = ((candidateTop / widget.hourHeight) * 60).round();
      final snappedMinutes = TimeUtils.snapToNearestMinutes(candidateMinutes, step: snapStep);
      final snappedStart = DateTime(
        start.year,
        start.month,
        start.day,
        (snappedMinutes ~/ 60).clamp(0, 23),
        (snappedMinutes % 60).clamp(0, 59),
      );
      if (snappedStart.isBefore(end)) {
        effectiveStart = snappedStart;
        effectiveTop = TimeUtils.calculateYOffset(effectiveStart, hourHeight: widget.hourHeight);
        final newDuration = end.difference(effectiveStart).inMinutes;
        effectiveHeight = TimeUtils.calculateBlockHeight(newDuration, hourHeight: widget.hourHeight);
      }
    }

    final showTopHandle = effectiveHeight >= 50;
    final isCompact = effectiveHeight < 52;

    Widget buildCard({bool isGhost = false}) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? projectColor.withValues(alpha: isGhost ? 0.1 : 0.2)
              : projectColor.withValues(alpha: isGhost ? 0.05 : 0.13),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: projectColor.withValues(alpha: _isResizing ? 0.9 : 0.5),
            width: _isResizing ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isResizing)
              BoxShadow(
                color: projectColor.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            // Left Project Color Bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: projectColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
            ),

            // Top Resize Handle
            if (showTopHandle)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      setState(() {
                        _isResizingTop = true;
                        _resizeDeltaTopY = 0;
                      });
                    },
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _resizeDeltaTopY += details.delta.dy;
                      });
                    },
                    onVerticalDragEnd: (_) {
                      ref.read(taskControllerProvider).scheduleTask(
                            taskId: widget.task.id,
                            start: effectiveStart,
                            end: end,
                          );
                      setState(() {
                        _isResizingTop = false;
                        _resizeDeltaTopY = 0;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: projectColor.withValues(alpha: _isResizingTop ? 0.9 : 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Content Area
            Positioned.fill(
              left: 8,
              top: isCompact ? 2 : (showTopHandle ? 7 : 3),
              right: 4,
              bottom: isCompact ? 2 : 5,
              child: ClipRect(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox
                    if (effectiveHeight >= 22)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => ref.read(taskControllerProvider).toggleComplete(widget.task.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 14,
                            height: 14,
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
                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),

                    // Task Info (Tapping opens modal)
                    Expanded(
                      child: InkWell(
                        onTap: () => TaskDetailModal.show(context, task: widget.task),
                        borderRadius: BorderRadius.circular(4),
                        child: isCompact
                            ? Row(
                                children: [
                                  if (widget.task.isSubtask) ...[
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 11,
                                      color: PlanColors.primary,
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Text(
                                    '${TimeUtils.formatRange(effectiveStart, effectiveEnd)}  ',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: projectColor,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      widget.task.title,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                                        color: widget.task.isCompleted
                                            ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                                            : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Live Time Range reflecting drag/resize
                                  Text(
                                    TimeUtils.formatRange(effectiveStart, effectiveEnd),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: projectColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Title with optional subtask indicator
                                  Row(
                                    children: [
                                      if (widget.task.isSubtask) ...[
                                        const Icon(
                                          Icons.subdirectory_arrow_right_rounded,
                                          size: 11,
                                          color: PlanColors.primary,
                                        ),
                                        const SizedBox(width: 2),
                                      ],
                                      Expanded(
                                        child: Text(
                                          widget.task.title,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                                            color: widget.task.isCompleted
                                                ? (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted)
                                                : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                                          ),
                                          maxLines: effectiveHeight > 60 ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // Unschedule Button
                    if (effectiveHeight >= 28)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 13),
                        splashRadius: 12,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Unschedule',
                        color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                        onPressed: () => ref.read(taskControllerProvider).unscheduleTask(widget.task.id),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Resize Handle
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) {
                    setState(() {
                      _isResizingBottom = true;
                      _resizeDeltaBottomY = 0;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _resizeDeltaBottomY += details.delta.dy;
                    });
                  },
                  onVerticalDragEnd: (_) {
                    ref.read(taskControllerProvider).scheduleTask(
                          taskId: widget.task.id,
                          start: start,
                          end: effectiveEnd,
                        );
                    setState(() {
                      _isResizingBottom = false;
                      _resizeDeltaBottomY = 0;
                    });
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: projectColor.withValues(alpha: _isResizingBottom ? 0.9 : 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildTimePill(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: PlanColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Positioned(
      top: effectiveTop,
      left: 4,
      right: 4,
      height: effectiveHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Draggable<TaskItem>(
            data: widget.task,
            maxSimultaneousDrags: _isResizing ? 0 : 1,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                height: effectiveHeight.clamp(40.0, 100.0),
                decoration: BoxDecoration(
                  color: projectColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.task.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimeUtils.formatRange(effectiveStart, effectiveEnd)} (${TimeUtils.formatDuration(effectiveEnd.difference(effectiveStart).inMinutes)})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: buildCard(isGhost: true),
            ),
            child: MouseRegion(
              cursor: _isResizing ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.grab,
              child: buildCard(),
            ),
          ),

          // Floating time badges during real-time resize
          if (_isResizingBottom)
            Positioned(
              bottom: -24,
              left: 8,
              child: buildTimePill('End: ${TimeUtils.formatTime(effectiveEnd)} (${TimeUtils.formatDuration(effectiveEnd.difference(start).inMinutes)})'),
            ),
          if (_isResizingTop)
            Positioned(
              top: -24,
              left: 8,
              child: buildTimePill('Start: ${TimeUtils.formatTime(effectiveStart)} (${TimeUtils.formatDuration(end.difference(effectiveStart).inMinutes)})'),
            ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/task_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../tasks/task_detail_modal.dart';
import 'day_anytime_section.dart';
import 'scheduled_task_block.dart';

class TimeSlotDropTarget extends ConsumerStatefulWidget {
  final DateTime date;
  final double hourHeight;
  final double? width;

  const TimeSlotDropTarget({
    super.key,
    required this.date,
    this.hourHeight = TimeUtils.defaultHourHeight,
    this.width,
  });

  @override
  ConsumerState<TimeSlotDropTarget> createState() => _TimeSlotDropTargetState();
}

class _TimeSlotDropTargetState extends ConsumerState<TimeSlotDropTarget> {
  final GlobalKey _gridKey = GlobalKey();
  DateTime? _localHoverTime;
  int _localHoverDuration = 30;
  TaskItem? _hoverTask;

  bool _isDragSelecting = false;
  double _dragStartY = 0;
  double _dragCurrentY = 0;

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragSelecting = true;
      _dragStartY = details.localPosition.dy;
      _dragCurrentY = details.localPosition.dy;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragSelecting) return;
    setState(() {
      _dragCurrentY = details.localPosition.dy;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragSelecting) return;
    final delta = (_dragCurrentY - _dragStartY).abs();
    final settings = ref.read(settingsProvider);

    if (delta <= 4) {
      // Single click: create block of default duration centered on clicked point
      final clickedTime = TimeUtils.calculateTimeFromYOffset(
        _dragStartY,
        widget.date,
        hourHeight: widget.hourHeight,
        snapMinutes: 5,
      );
      final range = TimeUtils.calculateCenteredRange(
        clickedTime,
        settings.defaultTaskDuration,
        snapMinutes: 5,
      );
      TaskDetailModal.show(
        context,
        initialStart: range.start,
        initialEnd: range.end,
      );
    } else {
      // Drag selection: create block with exact 5-minute snapped range
      final startSnapped = TimeUtils.calculateTimeFromYOffset(
        min(_dragStartY, _dragCurrentY),
        widget.date,
        hourHeight: widget.hourHeight,
        snapMinutes: 5,
      );
      final endSnapped = TimeUtils.calculateTimeFromYOffset(
        max(_dragStartY, _dragCurrentY),
        widget.date,
        hourHeight: widget.hourHeight,
        snapMinutes: 5,
      );
      final effectiveEnd = endSnapped.isAfter(startSnapped)
          ? endSnapped
          : startSnapped.add(const Duration(minutes: 5));

      TaskDetailModal.show(
        context,
        initialStart: startSnapped,
        initialEnd: effectiveEnd,
      );
    }

    setState(() {
      _isDragSelecting = false;
      _dragStartY = 0;
      _dragCurrentY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = TimeUtils.isToday(widget.date);
    final totalHeight = TimeUtils.totalHours * widget.hourHeight;

    final scheduledTasks = ref.watch(scheduledTasksForDateFamily(widget.date));

    // Calculate current time indicator offset if today
    final now = DateTime.now();
    final currentTimeY = isToday
        ? TimeUtils.calculateYOffset(now, hourHeight: widget.hourHeight)
        : null;

    // Drag-select range computation for live preview
    DateTime? dragSelectStart;
    DateTime? dragSelectEnd;
    if (_isDragSelecting && (_dragCurrentY - _dragStartY).abs() > 4) {
      dragSelectStart = TimeUtils.calculateTimeFromYOffset(
        min(_dragStartY, _dragCurrentY),
        widget.date,
        hourHeight: widget.hourHeight,
        snapMinutes: 5,
      );
      final rawEnd = TimeUtils.calculateTimeFromYOffset(
        max(_dragStartY, _dragCurrentY),
        widget.date,
        hourHeight: widget.hourHeight,
        snapMinutes: 5,
      );
      dragSelectEnd = rawEnd.isAfter(dragSelectStart)
          ? rawEnd
          : dragSelectStart.add(const Duration(minutes: 5));
    }

    final content = Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkBg : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Day Column Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday
                  ? (isDark ? PlanColors.darkCardHover : PlanColors.lightSidebar)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  TimeUtils.formatDayOfWeek(widget.date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isToday
                        ? PlanColors.primary
                        : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isToday ? PlanColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    TimeUtils.formatDayOfMonth(widget.date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Anytime / All-Day Today Section
          DayAnytimeSection(
            date: widget.date,
            width: widget.width ?? 300.0,
          ),

          // Time Slots, DragTarget & Click-to-Create Area
          SizedBox(
            key: _gridKey,
            height: totalHeight,
            child: DragTarget<TaskItem>(
              onWillAcceptWithDetails: (details) => true,
              onMove: (details) {
                final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final localPos = renderBox.globalToLocal(details.offset);
                  final gridY = localPos.dy.clamp(0.0, totalHeight - 10);
                  final snapMinutes = ref.read(settingsProvider).timeSnapMinutes;
                  final snappedTime = TimeUtils.calculateTimeFromYOffset(
                    gridY,
                    widget.date,
                    hourHeight: widget.hourHeight,
                    snapMinutes: snapMinutes,
                  );
                  setState(() {
                    _localHoverTime = snappedTime;
                    _localHoverDuration = details.data.estimatedMinutes > 0 ? details.data.estimatedMinutes : 30;
                    _hoverTask = details.data;
                  });
                }
              },
              onLeave: (_) {
                setState(() {
                  _localHoverTime = null;
                  _hoverTask = null;
                });
              },
              onAcceptWithDetails: (details) {
                final task = details.data;
                final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final localPos = renderBox.globalToLocal(details.offset);
                  final gridY = localPos.dy.clamp(0.0, totalHeight - 10);
                  final snapMinutes = ref.read(settingsProvider).timeSnapMinutes;
                  final startTime = TimeUtils.calculateTimeFromYOffset(
                    gridY,
                    widget.date,
                    hourHeight: widget.hourHeight,
                    snapMinutes: snapMinutes,
                  );
                  final duration = task.estimatedMinutes > 0 ? task.estimatedMinutes : 30;
                  final endTime = startTime.add(Duration(minutes: duration));

                  ref.read(taskControllerProvider).scheduleTask(
                        taskId: task.id,
                        start: startTime,
                        end: endTime,
                      );
                }

                setState(() {
                  _localHoverTime = null;
                  _hoverTask = null;
                });
              },
              builder: (context, candidateData, rejectedData) {
                final projectMap = ref.watch(projectMapProvider);
                final hoverProject = _hoverTask != null ? projectMap[_hoverTask!.projectId] : null;
                final hoverColor = hoverProject?.color ?? PlanColors.primary;

                return Stack(
                  children: [
                    // Grid background lines & Click/Drag canvas
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _handlePanStart,
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: Column(
                        children: List.generate(TimeUtils.totalHours, (index) {
                          return Container(
                            height: widget.hourHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder)
                                      .withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: Divider(
                                height: 1,
                                thickness: 0.5,
                                color: (isDark ? PlanColors.darkBorder : PlanColors.lightBorder)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Ghost Hover Preview (when task is dragged over)
                    if (_localHoverTime != null)
                      Positioned(
                        top: TimeUtils.calculateYOffset(_localHoverTime!, hourHeight: widget.hourHeight),
                        left: 4,
                        right: 4,
                        height: TimeUtils.calculateBlockHeight(_localHoverDuration, hourHeight: widget.hourHeight),
                        child: Container(
                          decoration: BoxDecoration(
                            color: hoverColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hoverColor,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: hoverColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 12, color: hoverColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${TimeUtils.formatRange(_localHoverTime!, _localHoverTime!.add(Duration(minutes: _localHoverDuration)))} (${TimeUtils.formatDuration(_localHoverDuration)})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: hoverColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (_hoverTask != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _hoverTask!.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Live Drag-Select Preview Box (5-minute increments)
                    if (dragSelectStart != null && dragSelectEnd != null)
                      Positioned(
                        top: TimeUtils.calculateYOffset(dragSelectStart, hourHeight: widget.hourHeight),
                        left: 4,
                        right: 4,
                        height: TimeUtils.calculateBlockHeight(
                          dragSelectEnd.difference(dragSelectStart).inMinutes,
                          hourHeight: widget.hourHeight,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: PlanColors.primary.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: PlanColors.primary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PlanColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 12, color: PlanColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${TimeUtils.formatRange(dragSelectStart, dragSelectEnd)} (${TimeUtils.formatDuration(dragSelectEnd.difference(dragSelectStart).inMinutes)})',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: PlanColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Scheduled Task Blocks
                    ...scheduledTasks.map((t) {
                      return ScheduledTaskBlock(
                        key: ValueKey(t.id),
                        task: t,
                        hourHeight: widget.hourHeight,
                      );
                    }),

                    // Real-time Current Time Line
                    if (currentTimeY != null)
                      Positioned(
                        top: currentTimeY,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: PlanColors.currentTimeIndicator,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                color: PlanColors.currentTimeIndicator,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.width != null) {
      return content;
    }
    return Expanded(child: content);
  }
}

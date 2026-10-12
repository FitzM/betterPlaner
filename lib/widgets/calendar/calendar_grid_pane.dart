import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/view_mode.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/layout_providers.dart';
import '../common/resizable_divider.dart';
import 'calendar_header.dart';
import 'time_ruler.dart';
import 'time_slot_drop_target.dart';

class CalendarGridPane extends ConsumerStatefulWidget {
  final double? width;
  const CalendarGridPane({super.key, this.width});

  @override
  ConsumerState<CalendarGridPane> createState() => _CalendarGridPaneState();
}

class _CalendarGridPaneState extends ConsumerState<CalendarGridPane> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _hasScrolledToMorning = false;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeDates = ref.watch(activeCalendarDatesProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(viewModeProvider);
    final dayWidths = ref.watch(dayColumnWidthsProvider);
    final visibleHours = ref.watch(calendarZoomProvider);
    final layoutMode = ref.watch(dashboardLayoutModeProvider);

    // In multi-column task board mode, the calendar acts as a focused 1-column schedule rail
    final effectiveDates = layoutMode == DashboardLayoutMode.multiColumnBoard
        ? [selectedDate]
        : activeDates;
    final isSingleColumn = layoutMode == DashboardLayoutMode.multiColumnBoard ||
        viewMode == CalendarViewMode.day;

    final content = Container(
      width: widget.width,
      color: isDark ? PlanColors.darkBg : Colors.white,
      child: Column(
          children: [
            // Calendar Top Header with date navigation & view buttons
            const CalendarHeader(),

            // Calendar Scrollable Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth - 58.0; // Subtract TimeRuler width
                  final dynamicHourHeight = TimeUtils.calculateHourHeight(
                    constraints.maxHeight > 100 ? constraints.maxHeight : 600.0,
                    visibleHours,
                  );

                  // Auto-scroll to 8:00 AM once when initial layout is ready
                  if (!_hasScrolledToMorning) {
                    _hasScrolledToMorning = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_verticalScrollController.hasClients) {
                        final initialOffset = 8 * dynamicHourHeight;
                        _verticalScrollController.jumpTo(
                          initialOffset.clamp(
                            0.0,
                            _verticalScrollController.position.maxScrollExtent,
                          ),
                        );
                      }
                    });
                  }

                  // Calculate base width per column when not customized
                  final double baseWidth;
                  if (isSingleColumn) {
                    baseWidth = availableWidth.clamp(280.0, double.infinity);
                  } else if (viewMode == CalendarViewMode.threeDay) {
                    baseWidth = (availableWidth / 3.0).clamp(220.0, 1000.0);
                  } else {
                    baseWidth = (availableWidth / 7.0).clamp(160.0, 600.0);
                  }

                  final totalGridHeight = (TimeUtils.totalHours * dynamicHourHeight) + 60.0;

                  return Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed;
                        if (isCtrlOrMeta) {
                          // Scroll down = zoom out (+ hours), scroll up = zoom in (- hours)
                          final delta = pointerSignal.scrollDelta.dy > 0 ? 0.75 : -0.75;
                          ref.read(calendarZoomProvider.notifier).zoomByDelta(delta);
                        }
                      }
                    },
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fixed width time ruler on the left (sticky vertically with grid)
                          TimeRuler(hourHeight: dynamicHourHeight),

                          // Horizontally scrollable day column(s) with individual resize dividers
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < effectiveDates.length; i++) ...[
                                    () {
                                      final date = effectiveDates[i];
                                      final key = DateFormat('yyyy-MM-dd').format(date);
                                      final width = isSingleColumn
                                          ? availableWidth
                                          : (dayWidths[key] ?? baseWidth);

                                      return TimeSlotDropTarget(
                                        key: ValueKey(date.toIso8601String()),
                                        date: date,
                                        hourHeight: dynamicHourHeight,
                                        width: width,
                                      );
                                    }(),
                                    // Resizable divider between and after day columns in multi-day views
                                    if (!isSingleColumn)
                                      ResizableDivider(
                                        height: totalGridHeight,
                                        onDelta: (dx) {
                                          final date = effectiveDates[i];
                                          final key = DateFormat('yyyy-MM-dd').format(date);
                                          ref
                                              .read(dayColumnWidthsProvider.notifier)
                                              .adjustWidth(key, dx, initialWidth: baseWidth);
                                        },
                                        onDoubleTap: () {
                                          ref.read(dayColumnWidthsProvider.notifier).reset();
                                        },
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

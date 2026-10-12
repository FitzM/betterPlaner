import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../models/view_mode.dart';
import '../../providers/calendar_providers.dart';

class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(viewModeProvider);
    final activeDates = ref.watch(activeCalendarDatesProvider);
    final visibleHours = ref.watch(calendarZoomProvider);
    final layoutMode = ref.watch(dashboardLayoutModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 780;
        final isNarrow = constraints.maxWidth < 620;
        final isVeryNarrow = constraints.maxWidth < 420;

        String titleText;
        if (viewMode == CalendarViewMode.day) {
          if (isVeryNarrow) {
            titleText = DateFormat('MMM d').format(selectedDate);
          } else if (isNarrow) {
            titleText = DateFormat('EEE, MMM d').format(selectedDate);
          } else {
            titleText = DateFormat('EEEE, MMMM d, y').format(selectedDate);
          }
        } else if (viewMode == CalendarViewMode.threeDay) {
          final end = activeDates.last;
          if (isVeryNarrow) {
            titleText = '${DateFormat('MMM d').format(selectedDate)}–${DateFormat('d').format(end)}';
          } else {
            titleText = '${DateFormat('MMM d').format(selectedDate)} – ${DateFormat('MMM d').format(end)}';
          }
        } else {
          final start = activeDates.first;
          final end = activeDates.last;
          if (isVeryNarrow) {
            titleText = '${DateFormat('MMM d').format(start)}–${DateFormat('d').format(end)}';
          } else {
            titleText = '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';
          }
        }

        final hPadding = isVeryNarrow ? 8.0 : (isNarrow ? 12.0 : 16.0);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? PlanColors.darkBg : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Navigation controls
              Expanded(
                child: Row(
                  children: [
                    // Today Button / Icon
                    if (!isNarrow) ...[
                      OutlinedButton(
                        onPressed: () {
                          final now = DateTime.now();
                          ref.read(selectedDateProvider.notifier).setDate(
                                DateTime(now.year, now.month, now.day),
                              );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(
                            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      Tooltip(
                        message: 'Today',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            final now = DateTime.now();
                            ref.read(selectedDateProvider.notifier).setDate(
                                  DateTime(now.year, now.month, now.day),
                                );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.today_rounded, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    // Prev / Next arrows
                    Tooltip(
                      message: 'Previous',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          final step = viewMode.dayCount;
                          ref.read(selectedDateProvider.notifier).setDate(
                                selectedDate.subtract(Duration(days: step)),
                              );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left_rounded, size: 18),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Next',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          final step = viewMode.dayCount;
                          ref.read(selectedDateProvider.notifier).setDate(
                                selectedDate.add(Duration(days: step)),
                              );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_right_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Date Text with safe truncation
                    Expanded(
                      child: Text(
                        titleText,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: isVeryNarrow ? 12 : (isNarrow ? 13 : 15),
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Zoom Controls ([-] 9h [+])
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? PlanColors.darkCard : PlanColors.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Zoom Out (All 24h)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => ref.read(calendarZoomProvider.notifier).zoomOut(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: Icon(Icons.remove, size: 13),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Reset Zoom (9h)',
                      child: InkWell(
                        onTap: () => ref.read(calendarZoomProvider.notifier).reset(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            '${visibleHours.toStringAsFixed(visibleHours == visibleHours.roundToDouble() ? 0 : 1)}h',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Zoom In (Down to 3h)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => ref.read(calendarZoomProvider.notifier).zoomIn(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: Icon(Icons.add, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Layout Mode Switcher (Split View vs Board View)
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? PlanColors.darkCard : PlanColors.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: DashboardLayoutMode.values.map((mode) {
                    final isSelected = layoutMode == mode;
                    return Tooltip(
                      message: mode.label,
                      child: InkWell(
                        onTap: () => ref.read(dashboardLayoutModeProvider.notifier).setMode(mode),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? PlanColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mode == DashboardLayoutMode.splitCalendar
                                    ? Icons.view_sidebar_outlined
                                    : Icons.view_week_outlined,
                                size: 13,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                              ),
                              if (!isCompact) ...[
                                const SizedBox(width: 4),
                                Text(
                                  mode.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // View Mode Selector (Day, 3-Day, Week)
              if (layoutMode == DashboardLayoutMode.splitCalendar) ...[
                const SizedBox(width: 6),
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? PlanColors.darkCard : PlanColors.lightBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: CalendarViewMode.values.map((mode) {
                      final isSelected = viewMode == mode;
                      return InkWell(
                        onTap: () => ref.read(viewModeProvider.notifier).setMode(mode),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? PlanColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

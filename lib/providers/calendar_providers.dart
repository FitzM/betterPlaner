import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/view_mode.dart';

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) => state = date;
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

class ViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.day;

  void setMode(CalendarViewMode mode) => state = mode;
}

final viewModeProvider =
    NotifierProvider<ViewModeNotifier, CalendarViewMode>(ViewModeNotifier.new);

class CalendarZoomNotifier extends Notifier<double> {
  static const double minVisibleHours = 3.0; // Max zoom in (3 hours visible)
  static const double maxVisibleHours = 24.0; // Max zoom out (full 24h visible)
  static const double defaultVisibleHours = 9.0;
  static const double minHours = minVisibleHours;
  static const double maxHours = maxVisibleHours;
  static const double defaultHours = defaultVisibleHours;

  @override
  double build() => defaultVisibleHours;

  void zoomIn() {
    state = (state - 1.5).clamp(minVisibleHours, maxVisibleHours);
  }

  void zoomOut() {
    state = (state + 1.5).clamp(minVisibleHours, maxVisibleHours);
  }

  void zoomByDelta(double delta) {
    state = (state + delta).clamp(minVisibleHours, maxVisibleHours);
  }

  void setVisibleHours(double hours) {
    state = hours.clamp(minVisibleHours, maxVisibleHours);
  }

  void reset() => state = defaultVisibleHours;
}

final calendarZoomProvider =
    NotifierProvider<CalendarZoomNotifier, double>(CalendarZoomNotifier.new);

class DashboardLayoutModeNotifier extends Notifier<DashboardLayoutMode> {
  @override
  DashboardLayoutMode build() => DashboardLayoutMode.splitCalendar;

  void setMode(DashboardLayoutMode mode) => state = mode;

  void toggle() {
    state = state == DashboardLayoutMode.splitCalendar
        ? DashboardLayoutMode.multiColumnBoard
        : DashboardLayoutMode.splitCalendar;
  }
}

final dashboardLayoutModeProvider =
    NotifierProvider<DashboardLayoutModeNotifier, DashboardLayoutMode>(
        DashboardLayoutModeNotifier.new);

class DragHoverSlot {
  final DateTime targetTime;
  final int durationMinutes;

  const DragHoverSlot({
    required this.targetTime,
    required this.durationMinutes,
  });
}

class DragHoverSlotNotifier extends Notifier<DragHoverSlot?> {
  @override
  DragHoverSlot? build() => null;

  void setSlot(DragHoverSlot? slot) => state = slot;
}

final dragHoverSlotProvider =
    NotifierProvider<DragHoverSlotNotifier, DragHoverSlot?>(
        DragHoverSlotNotifier.new);

/// Provides the list of days shown on the calendar based on selectedDate and viewMode
final activeCalendarDatesProvider = Provider<List<DateTime>>((ref) {
  final baseDate = ref.watch(selectedDateProvider);
  final viewMode = ref.watch(viewModeProvider);

  switch (viewMode) {
    case CalendarViewMode.day:
      return [baseDate];
    case CalendarViewMode.threeDay:
      return List.generate(3, (i) => baseDate.add(Duration(days: i)));
    case CalendarViewMode.week:
      final weekday = baseDate.weekday; // 1 = Monday, 7 = Sunday
      final monday = baseDate.subtract(Duration(days: weekday - 1));
      return List.generate(7, (i) => monday.add(Duration(days: i)));
  }
});

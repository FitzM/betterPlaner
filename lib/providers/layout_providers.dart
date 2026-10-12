import 'package:flutter_riverpod/flutter_riverpod.dart';

class SidebarWidthNotifier extends Notifier<double> {
  static const double defaultWidth = 240.0;
  static const double minWidth = 160.0;
  static const double maxWidth = 450.0;

  @override
  double build() => defaultWidth;

  void adjust(double delta) {
    state = (state + delta).clamp(minWidth, maxWidth);
  }

  void reset() => state = defaultWidth;
}

final sidebarWidthProvider =
    NotifierProvider<SidebarWidthNotifier, double>(SidebarWidthNotifier.new);

class TaskPaneWidthNotifier extends Notifier<double> {
  static const double defaultWidth = 340.0;
  static const double minWidth = 240.0;
  static const double maxWidth = 650.0;

  @override
  double build() => defaultWidth;

  void adjust(double delta) {
    state = (state + delta).clamp(minWidth, maxWidth);
  }

  void reset() => state = defaultWidth;
}

final taskPaneWidthProvider =
    NotifierProvider<TaskPaneWidthNotifier, double>(TaskPaneWidthNotifier.new);

class DayColumnWidthsNotifier extends Notifier<Map<String, double>> {
  static const double defaultDayWidth = 300.0;
  static const double minDayWidth = 160.0;
  static const double maxDayWidth = 1200.0;

  @override
  Map<String, double> build() => {};

  void adjustWidth(
    String dateKey,
    double delta, {
    double initialWidth = defaultDayWidth,
  }) {
    final current = state[dateKey] ?? initialWidth;
    final updated = (current + delta).clamp(minDayWidth, maxDayWidth);
    state = {
      ...state,
      dateKey: updated,
    };
  }

  void reset() => state = {};
}

final dayColumnWidthsProvider =
    NotifierProvider<DayColumnWidthsNotifier, Map<String, double>>(
        DayColumnWidthsNotifier.new);

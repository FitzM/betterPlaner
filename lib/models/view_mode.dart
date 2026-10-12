enum CalendarViewMode {
  day,
  threeDay,
  week;

  String get label {
    switch (this) {
      case CalendarViewMode.day:
        return 'Day';
      case CalendarViewMode.threeDay:
        return '3 Days';
      case CalendarViewMode.week:
        return 'Week';
    }
  }

  int get dayCount {
    switch (this) {
      case CalendarViewMode.day:
        return 1;
      case CalendarViewMode.threeDay:
        return 3;
      case CalendarViewMode.week:
        return 7;
    }
  }
}

enum DashboardLayoutMode {
  splitCalendar,
  multiColumnBoard;

  String get label {
    switch (this) {
      case DashboardLayoutMode.splitCalendar:
        return 'Split View';
      case DashboardLayoutMode.multiColumnBoard:
        return 'Board View';
    }
  }
}

enum TaskFilter {
  all,
  today,
  unscheduled,
  upcoming,
  completed;

  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All Tasks';
      case TaskFilter.today:
        return 'Today';
      case TaskFilter.unscheduled:
        return 'Unscheduled';
      case TaskFilter.upcoming:
        return 'Next 7 Days';
      case TaskFilter.completed:
        return 'Completed';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeUtils {
  static const int startHour = 0; // 12:00 AM (Midnight)
  static const int endHour = 24; // 12:00 AM (Next Midnight)
  static const int totalHours = endHour - startHour; // 24 hours
  static const double defaultHourHeight = 64.0;

  static String formatDateHeader(DateTime date) {
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  static String formatDayOfWeek(DateTime date) {
    return DateFormat('EEE').format(date);
  }

  static String formatDayOfMonth(DateTime date) {
    return DateFormat('d').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  static String formatTimeOfDay(TimeOfDay time, BuildContext context) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  static String formatHour(int hour) {
    final normalized = hour % 24;
    final period = (normalized >= 12 && normalized < 24) ? 'PM' : 'AM';
    final displayHour = normalized == 0 ? 12 : (normalized > 12 ? normalized - 12 : normalized);
    return '$displayHour $period';
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMins}m';
  }

  static String formatRange(DateTime start, DateTime end) {
    final startStr = DateFormat('h:mm a').format(start);
    final endStr = DateFormat('h:mm a').format(end);
    return '$startStr – $endStr';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Snaps a minute value to nearest step (e.g. 5 or 15 minutes)
  static int snapToNearestMinutes(int minutes, {int step = 5}) {
    return ((minutes / step).round()) * step;
  }

  /// Calculates y-offset from calendar top for a given DateTime
  static double calculateYOffset(DateTime time, {double hourHeight = defaultHourHeight}) {
    final hoursFromStart = (time.hour - startHour) + (time.minute / 60.0);
    return hoursFromStart * hourHeight;
  }

  /// Calculates DateTime on targetDate from y-offset
  static DateTime calculateTimeFromYOffset(
    double y,
    DateTime targetDate, {
    double hourHeight = defaultHourHeight,
    int snapMinutes = 5,
  }) {
    final totalMinutesFromStart = ((y / hourHeight) * 60).round();
    final clampedMinutes = totalMinutesFromStart.clamp(0, totalHours * 60);
    final snappedMinutes = ((clampedMinutes / snapMinutes).round()) * snapMinutes;

    final hour = (startHour + (snappedMinutes ~/ 60)).clamp(0, 23);
    final minute = (snappedMinutes % 60).clamp(0, 59);

    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );
  }

  /// Calculates height in pixels for a given duration
  static double calculateBlockHeight(int durationMinutes, {double hourHeight = defaultHourHeight}) {
    const minMinutes = 5;
    final effectiveMinutes = durationMinutes < minMinutes ? minMinutes : durationMinutes;
    return (effectiveMinutes / 60.0) * hourHeight;
  }

  /// Calculates a time range centered around clickedTime with specified duration,
  /// snapped to snapMinutes and clamped within the 24-hour day.
  static ({DateTime start, DateTime end}) calculateCenteredRange(
    DateTime clickedTime,
    int durationMinutes, {
    int snapMinutes = 5,
  }) {
    final totalDayMinutes = clickedTime.hour * 60 + clickedTime.minute;
    final half = durationMinutes ~/ 2;
    final rawStartMinutes = totalDayMinutes - half;
    final snappedStart = ((rawStartMinutes / snapMinutes).round()) * snapMinutes;
    final maxStart = 24 * 60 - durationMinutes;
    final clampedStart = snappedStart.clamp(0, maxStart);

    final startHour = clampedStart ~/ 60;
    final startMinute = clampedStart % 60;

    final start = DateTime(
      clickedTime.year,
      clickedTime.month,
      clickedTime.day,
      startHour.clamp(0, 23),
      startMinute.clamp(0, 59),
    );
    final end = start.add(Duration(minutes: durationMinutes));

    return (start: start, end: end);
  }

  /// Calculates dynamic hour height based on viewport height and visible hours
  static double calculateHourHeight(double viewportHeight, double visibleHours) {
    if (visibleHours <= 0) return defaultHourHeight;
    return (viewportHeight / visibleHours).clamp(24.0, 320.0);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:getplan_better/core/utils/time_utils.dart';

void main() {
  group('TimeUtils Tests', () {
    test('formatDuration formats minutes properly', () {
      expect(TimeUtils.formatDuration(15), '15m');
      expect(TimeUtils.formatDuration(30), '30m');
      expect(TimeUtils.formatDuration(60), '1h');
      expect(TimeUtils.formatDuration(90), '1h 30m');
      expect(TimeUtils.formatDuration(120), '2h');
    });

    test('snapToNearestMinutes snaps to step', () {
      expect(TimeUtils.snapToNearestMinutes(0, step: 5), 0);
      expect(TimeUtils.snapToNearestMinutes(7, step: 5), 5);
      expect(TimeUtils.snapToNearestMinutes(8, step: 5), 10);
      expect(TimeUtils.snapToNearestMinutes(14, step: 15), 15);
      expect(TimeUtils.snapToNearestMinutes(22, step: 15), 15);
      expect(TimeUtils.snapToNearestMinutes(23, step: 15), 30);
    });

    test('calculateYOffset calculates correct top offset for hour from midnight (startHour=0)', () {
      // Midnight (0:00) is offset 0
      final midnight = DateTime(2026, 10, 2, 0, 0);
      expect(TimeUtils.calculateYOffset(midnight, hourHeight: 64.0), 0.0);

      // 6:00 AM is 6 hours after midnight (offset 384.0)
      final sixAm = DateTime(2026, 10, 2, 6, 0);
      expect(TimeUtils.calculateYOffset(sixAm, hourHeight: 64.0), 384.0);

      // 7:30 AM is 7.5 hours after midnight (offset 480.0)
      final sevenThirty = DateTime(2026, 10, 2, 7, 30);
      expect(TimeUtils.calculateYOffset(sevenThirty, hourHeight: 64.0), 480.0);
    });

    test('calculateTimeFromYOffset calculates correct DateTime', () {
      final baseDate = DateTime(2026, 10, 2);

      // y = 0 -> 0:00 (Midnight)
      final timeAtZero = TimeUtils.calculateTimeFromYOffset(0, baseDate, hourHeight: 64.0);
      expect(timeAtZero.hour, 0);
      expect(timeAtZero.minute, 0);

      // y = 64.0 * 7 -> 7:00 AM
      final timeAt7h = TimeUtils.calculateTimeFromYOffset(64.0 * 7, baseDate, hourHeight: 64.0);
      expect(timeAt7h.hour, 7);
      expect(timeAt7h.minute, 0);

      // y = 64.0 * 7.5 -> 7:30 AM
      final timeAt7h30 = TimeUtils.calculateTimeFromYOffset(64.0 * 7.5, baseDate, hourHeight: 64.0);
      expect(timeAt7h30.hour, 7);
      expect(timeAt7h30.minute, 30);
    });

    test('calculateBlockHeight returns proportional height with 5m minimum', () {
      expect(TimeUtils.calculateBlockHeight(30, hourHeight: 60.0), 30.0);
      expect(TimeUtils.calculateBlockHeight(60, hourHeight: 60.0), 60.0);
      expect(TimeUtils.calculateBlockHeight(90, hourHeight: 60.0), 90.0);
      expect(TimeUtils.calculateBlockHeight(5, hourHeight: 60.0), 5.0);
      expect(TimeUtils.calculateBlockHeight(2, hourHeight: 60.0), 5.0); // clamped to min 5m
    });

    test('calculateCenteredRange centers, snaps to 5-min, and clamps range', () {
      final baseDate = DateTime(2026, 10, 2, 10, 14); // 10:14 AM
      // Default 30 min duration centered around 10:14 -> 10:14 - 15m = 9:59 -> snaps to 10:00
      final range = TimeUtils.calculateCenteredRange(baseDate, 30, snapMinutes: 5);
      expect(range.start.hour, 10);
      expect(range.start.minute, 0);
      expect(range.end.hour, 10);
      expect(range.end.minute, 30);

      // Near midnight start clamping
      final earlyTime = DateTime(2026, 10, 2, 0, 5);
      final earlyRange = TimeUtils.calculateCenteredRange(earlyTime, 30, snapMinutes: 5);
      expect(earlyRange.start.hour, 0);
      expect(earlyRange.start.minute, 0);
      expect(earlyRange.end.hour, 0);
      expect(earlyRange.end.minute, 30);

      // Near end of day clamping
      final lateTime = DateTime(2026, 10, 2, 23, 55);
      final lateRange = TimeUtils.calculateCenteredRange(lateTime, 30, snapMinutes: 5);
      expect(lateRange.start.hour, 23);
      expect(lateRange.start.minute, 30);
      expect(lateRange.end.difference(lateRange.start).inMinutes, 30);
    });
  });
}

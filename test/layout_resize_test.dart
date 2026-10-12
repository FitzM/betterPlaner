import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getplan_better/app.dart';
import 'package:getplan_better/models/view_mode.dart';
import 'package:getplan_better/providers/calendar_providers.dart';
import 'package:getplan_better/providers/layout_providers.dart';
import 'package:getplan_better/widgets/calendar/time_slot_drop_target.dart';
import 'package:getplan_better/widgets/common/resizable_divider.dart';

void main() {
  group('Layout Providers Unit Tests', () {
    test('SidebarWidthNotifier adjusts, clamps, and resets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sidebarWidthProvider), 240.0);

      // Adjust larger
      container.read(sidebarWidthProvider.notifier).adjust(50.0);
      expect(container.read(sidebarWidthProvider), 290.0);

      // Clamp max
      container.read(sidebarWidthProvider.notifier).adjust(500.0);
      expect(container.read(sidebarWidthProvider), SidebarWidthNotifier.maxWidth);

      // Clamp min
      container.read(sidebarWidthProvider.notifier).adjust(-1000.0);
      expect(container.read(sidebarWidthProvider), SidebarWidthNotifier.minWidth);

      // Reset
      container.read(sidebarWidthProvider.notifier).reset();
      expect(container.read(sidebarWidthProvider), SidebarWidthNotifier.defaultWidth);
    });

    test('TaskPaneWidthNotifier adjusts, clamps, and resets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(taskPaneWidthProvider), 340.0);

      container.read(taskPaneWidthProvider.notifier).adjust(60.0);
      expect(container.read(taskPaneWidthProvider), 400.0);

      container.read(taskPaneWidthProvider.notifier).adjust(1000.0);
      expect(container.read(taskPaneWidthProvider), TaskPaneWidthNotifier.maxWidth);

      container.read(taskPaneWidthProvider.notifier).reset();
      expect(container.read(taskPaneWidthProvider), TaskPaneWidthNotifier.defaultWidth);
    });

    test('DayColumnWidthsNotifier allows Day 1 of 3-day view to be wider than Day 2 and 3', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const day1Key = '2026-10-01';
      const day2Key = '2026-10-02';
      const day3Key = '2026-10-03';

      // Base width is 250px
      const baseWidth = 250.0;

      // Adjust Day 1 by +150px
      container.read(dayColumnWidthsProvider.notifier).adjustWidth(
            day1Key,
            150.0,
            initialWidth: baseWidth,
          );

      final widths = container.read(dayColumnWidthsProvider);
      expect(widths[day1Key], 400.0);
      expect(widths[day2Key], isNull); // Falls back to baseWidth
      expect(widths[day3Key], isNull); // Falls back to baseWidth

      // Day 1 is now 400px, which is wider than Day 2 and 3 (250px)
      final effectiveDay1 = widths[day1Key] ?? baseWidth;
      final effectiveDay2 = widths[day2Key] ?? baseWidth;
      final effectiveDay3 = widths[day3Key] ?? baseWidth;

      expect(effectiveDay1, greaterThan(effectiveDay2));
      expect(effectiveDay1, greaterThan(effectiveDay3));
      expect(effectiveDay1, 400.0);
      expect(effectiveDay2, 250.0);
      expect(effectiveDay3, 250.0);

      // Reset works
      container.read(dayColumnWidthsProvider.notifier).reset();
      expect(container.read(dayColumnWidthsProvider), isEmpty);
    });
  });

  group('Resizable UI Widget Tests', () {
    testWidgets('Dashboard renders ResizableDividers between panels and allows dragging sidebar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Find ResizableDividers
      final dividers = find.byType(ResizableDivider);
      expect(dividers, findsWidgets);

      // Initial sidebar width
      expect(container.read(sidebarWidthProvider), 240.0);

      // First divider is between sidebar and task pane
      final firstDivider = dividers.first;
      await tester.drag(firstDivider, const Offset(60.0, 0.0));
      await tester.pumpAndSettle();

      // Sidebar width should have increased
      expect(container.read(sidebarWidthProvider), greaterThan(240.0));

      // Reset
      container.read(sidebarWidthProvider.notifier).reset();
      expect(container.read(sidebarWidthProvider), 240.0);
    });

    testWidgets('3-Day Calendar View renders dividers for each day column and allows resizing Day 1',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set view mode to 3-day
      container.read(viewModeProvider.notifier).state = CalendarViewMode.threeDay;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 3 day drop targets are rendered
      final dayTargets = find.byType(TimeSlotDropTarget);
      expect(dayTargets, findsNWidgets(3));

      // Dividers exist between day columns
      final dividers = find.byType(ResizableDivider);
      // At least 2 between sidebar & task pane + calendar day dividers
      expect(dividers, findsWidgets);

      // Find all dividers in the calendar grid pane
      final dayDividers = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(ResizableDivider),
      );
      expect(dayDividers, findsWidgets);

      // Drag the first day divider to widen Day 1
      await tester.drag(dayDividers.first, const Offset(100.0, 0.0));
      await tester.pumpAndSettle();

      final widths = container.read(dayColumnWidthsProvider);
      expect(widths.isNotEmpty, isTrue);
      // The adjusted width of Day 1 should be stored and positive
      final firstKey = widths.keys.first;
      expect(widths[firstKey], greaterThan(220.0));
    });
  });
}

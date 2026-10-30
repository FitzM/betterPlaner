import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getplan_better/app.dart';
import 'package:getplan_better/models/view_mode.dart';
import 'package:getplan_better/providers/calendar_providers.dart';
import 'package:getplan_better/widgets/calendar/calendar_grid_pane.dart';
import 'package:getplan_better/widgets/tasks/task_board_pane.dart';

void main() {
  testWidgets('Dashboard renders TaskBoardPane and 1-column Calendar rail in multiColumnBoard mode',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Set layout mode to multiColumnBoard
    container.read(dashboardLayoutModeProvider.notifier).setMode(DashboardLayoutMode.multiColumnBoard);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PlanApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify TaskBoardPane is rendered
    expect(find.byType(TaskBoardPane), findsOneWidget);

    // Verify project columns exist in TaskBoardPane
    expect(find.text('Inbox'), findsWidgets);

    // Verify 1-column calendar rail is rendered on the right
    expect(find.byType(CalendarGridPane), findsOneWidget);

    // Toggle back to splitCalendar
    container.read(dashboardLayoutModeProvider.notifier).setMode(DashboardLayoutMode.splitCalendar);
    await tester.pumpAndSettle();

    // Verify TaskBoardPane is replaced by standard split view
    expect(find.byType(TaskBoardPane), findsNothing);
    expect(find.byType(CalendarGridPane), findsOneWidget);
  });
}

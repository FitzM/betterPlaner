import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getplan_better/app.dart';

void main() {
  testWidgets('App renders GetPlan dashboard without errors', (WidgetTester tester) async {
    // Set desktop window size
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: PlanApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify GetPlan branding, projects section, and Today filter
    expect(find.text('GetPlan'), findsOneWidget);
    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('VIEWS'), findsOneWidget);
  });
}

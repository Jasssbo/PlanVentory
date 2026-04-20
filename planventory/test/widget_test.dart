// Basic widget test for PlanVentory app

import 'package:flutter_test/flutter_test.dart';

import 'package:planventory/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PlanVentoryApp());

    // Wait for async initialization
    await tester.pumpAndSettle();

    // Verify app title appears
    expect(find.text('PlanVentory'), findsWidgets);
  });
}

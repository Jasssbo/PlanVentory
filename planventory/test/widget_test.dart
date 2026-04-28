// Basic smoke tests for PlanVentory app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planventory/main.dart';
import 'package:planventory/services/services.dart';

void main() {
  setUpAll(() async {
    // Use the in-memory FFI database factory so tests run without a device
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await DatabaseService.initializeDatabaseFactory();
  });

  testWidgets('App starts and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanVentoryApp());
    // Allow the initial frame + async providers to settle
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App shows a loading indicator or main scaffold',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PlanVentoryApp());
    await tester.pump();
    // Either a loading spinner (DB init) or the main scaffold must be present
    final hasLoader = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
    expect(hasLoader || hasScaffold, isTrue);
  });
}

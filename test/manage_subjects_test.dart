import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spa_sdp/data/database_helper.dart';
import 'package:spa_sdp/screens/admin/manage_subjects_page.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('ManageSubjectsPage renders subjects on initial load without error', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.database;
      await tester.pumpWidget(
        const MaterialApp(
          home: ManageSubjectsPage(),
        ),
      );
      // Wait for real async DB call
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No subjects added yet.'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}

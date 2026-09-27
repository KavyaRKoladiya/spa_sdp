import 'package:flutter_test/flutter_test.dart';
import 'package:spa_sdp/main.dart';

void main() {
  testWidgets('StudyPlannerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyPlannerApp());
    await tester.pumpAndSettle();

    // Verify index page is shown
    expect(find.text('Study Planner'), findsWidgets);
  });
}

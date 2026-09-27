import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spa_sdp/data/database_helper.dart';
import 'package:spa_sdp/data/mock_data.dart';
import 'package:spa_sdp/models/models.dart';
import 'package:spa_sdp/screens/student/student_timer_page.dart';

void main() {
  setUp(() async {
    MockData.studySessions.clear();
    MockData.currentStudent = Student(
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      password: 'password123',
      semester: 'Semester 1',
    );
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('study_sessions');
    } catch (_) {}
  });

  group('StudySession Model Tests', () {
    test('StudySession serialization toMap and fromMap works correctly', () {
      final now = DateTime.now();
      final session = StudySession(
        id: 101,
        studentEmail: 'john@example.com',
        studentName: 'John Doe',
        subjectName: 'Mathematics I',
        subjectId: 'CS101',
        durationSeconds: 1500,
        date: now,
        notes: 'Studied limits and derivatives',
      );

      final map = session.toMap();
      expect(map['id'], 101);
      expect(map['studentEmail'], 'john@example.com');
      expect(map['subjectName'], 'Mathematics I');
      expect(map['durationSeconds'], 1500);
      expect(map['notes'], 'Studied limits and derivatives');

      final deserialized = StudySession.fromMap(map);
      expect(deserialized.id, 101);
      expect(deserialized.studentEmail, 'john@example.com');
      expect(deserialized.studentName, 'John Doe');
      expect(deserialized.subjectName, 'Mathematics I');
      expect(deserialized.durationSeconds, 1500);
      expect(deserialized.notes, 'Studied limits and derivatives');
    });
  });

  group('Study History Per-Student Isolation Tests', () {
    test('Students only retrieve their own study sessions', () async {
      // Create session for student A
      final sessionA = StudySession(
        studentEmail: 'studentA@example.com',
        studentName: 'Student A',
        subjectName: 'Data Structures',
        durationSeconds: 1800,
        date: DateTime.now(),
        notes: 'Binary Trees',
      );

      // Create session for student B
      final sessionB = StudySession(
        studentEmail: 'studentB@example.com',
        studentName: 'Student B',
        subjectName: 'Operating Systems',
        durationSeconds: 2400,
        date: DateTime.now(),
        notes: 'Processes and Threads',
      );

      await DatabaseHelper.instance.insertStudySession(sessionA);
      await DatabaseHelper.instance.insertStudySession(sessionB);

      final historyA = await DatabaseHelper.instance
          .getStudySessionsByStudent('studentA@example.com');
      final historyB = await DatabaseHelper.instance
          .getStudySessionsByStudent('studentB@example.com');

      expect(historyA.length, 1);
      expect(historyA.first.studentEmail, 'studentA@example.com');
      expect(historyA.first.subjectName, 'Data Structures');

      expect(historyB.length, 1);
      expect(historyB.first.studentEmail, 'studentB@example.com');
      expect(historyB.first.subjectName, 'Operating Systems');
    });
  });

  group('StudentTimerPage Widget Tests', () {
    testWidgets('Renders Study Timer tabs and controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4A90E2),
              secondary: const Color(0xFF50E3C2),
            ),
          ),
          home: const StudentTimerPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify page title and tabs
      expect(find.text('Study Timer & Tracker'), findsOneWidget);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('History & Stats'), findsOneWidget);

      // Verify Stopwatch and Focus segmented options
      expect(find.text('Stopwatch (Count Up)'), findsOneWidget);
      expect(find.text('Focus (Countdown)'), findsOneWidget);

      // Verify Subject selector is present with student's semester
      expect(find.text('Semester 1 Subjects'), findsOneWidget);

      // Verify Start Studying button is present
      expect(find.text('Start Studying'), findsOneWidget);

      // Advance pending timers from database query
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('Only loads subjects for current student semester by default',
        (WidgetTester tester) async {
      MockData.currentStudentSemester = 'Semester 5';
      MockData.currentStudent = Student(
        id: 5,
        name: 'Sem 5 Student',
        email: 'sem5@example.com',
        password: 'password',
        semester: 'Semester 5',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4A90E2),
              secondary: const Color(0xFF50E3C2),
            ),
          ),
          home: const StudentTimerPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header shows Semester 5 Subjects
      expect(find.text('Semester 5 Subjects'), findsOneWidget);

      // Advance pending timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('Can navigate back out of StudentTimerPage without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentTimerPage()),
                  );
                },
                child: const Text('Open Timer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Timer'));
      await tester.pumpAndSettle();

      expect(find.byType(StudentTimerPage), findsOneWidget);

      // Pop the timer page (e.g. back button in AppBar)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(StudentTimerPage), findsNothing);
      expect(find.text('Open Timer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
    });
  });
}


import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spa_sdp/data/database_helper.dart';
import 'package:spa_sdp/data/quiz_sync_service.dart';
import 'package:spa_sdp/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('QuizItem & QuizResult Model Tests', () {
    test('QuizItem converts to and from map with syncUrl and totalMarks', () {
      final quiz = QuizItem(
        id: 1,
        title: 'Math Quiz 1',
        link: 'https://docs.google.com/forms/d/123/viewform',
        subjectId: 'CS101',
        semester: 'Semester 1',
        chapter: 'Derivatives',
        syncUrl: 'https://script.google.com/macros/s/xyz/exec',
        totalMarks: 20.0,
      );

      final map = quiz.toMap();
      expect(map['title'], 'Math Quiz 1');
      expect(map['syncUrl'], 'https://script.google.com/macros/s/xyz/exec');
      expect(map['totalMarks'], 20.0);

      final fromMap = QuizItem.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.title, 'Math Quiz 1');
      expect(fromMap.syncUrl, 'https://script.google.com/macros/s/xyz/exec');
      expect(fromMap.totalMarks, 20.0);
    });

    test('QuizResult calculates percentage and status correctly', () {
      final attempt = QuizResult(
        quizId: 10,
        studentEmail: 'student@test.com',
        studentName: 'Test Student',
        status: 'attempted',
        attemptedAt: DateTime.now(),
      );

      expect(attempt.isAttempted, true);
      expect(attempt.isSynced, false);
      expect(attempt.percentage, 0.0);

      final synced = QuizResult(
        id: 5,
        quizId: 10,
        studentEmail: 'student@test.com',
        studentName: 'Test Student',
        status: 'synced',
        score: 8.0,
        totalMarks: 10.0,
        attemptedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        synchronizedAt: DateTime.now(),
      );

      expect(synced.isSynced, true);
      expect(synced.score, 8.0);
      expect(synced.totalMarks, 10.0);
      expect(synced.percentage, 80.0);
    });
  });

  group('QuizSyncService Unit Tests', () {
    test('Successfully parses numeric score from Google Apps Script', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'getScore');
        expect(request.url.queryParameters['email'], 'student@example.com');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'found': true,
            'score': 9,
            'totalMarks': 10,
            'submittedAt': '2026-10-03T10:00:00.000Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = QuizSyncService(client: mockClient);
      final result = await service.fetchScore(
        syncUrl: 'https://script.google.com/macros/s/xyz/exec',
        studentEmail: 'student@example.com',
      );

      expect(result.isSuccess, true);
      expect(result.found, true);
      expect(result.score, 9.0);
      expect(result.totalMarks, 10.0);
    });

    test('Successfully parses string score like "8 / 10"', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'found': true,
            'score': '8 / 10',
          }),
          200,
        );
      });

      final service = QuizSyncService(client: mockClient);
      final result = await service.fetchScore(
        syncUrl: 'https://script.google.com/macros/s/xyz/exec',
        studentEmail: 'student@example.com',
      );

      expect(result.isSuccess, true);
      expect(result.found, true);
      expect(result.score, 8.0);
      expect(result.totalMarks, 10.0);
    });

    test('Handles not found response cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'found': false,
            'message': 'No submission found for this student yet.',
          }),
          200,
        );
      });

      final service = QuizSyncService(client: mockClient);
      final result = await service.fetchScore(
        syncUrl: 'https://script.google.com/macros/s/xyz/exec',
        studentEmail: 'newstudent@example.com',
      );

      expect(result.isSuccess, true);
      expect(result.found, false);
      expect(result.message, contains('No submission found'));
    });

    test('Handles server HTTP errors without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = QuizSyncService(client: mockClient);
      final result = await service.fetchScore(
        syncUrl: 'https://script.google.com/macros/s/xyz/exec',
        studentEmail: 'student@example.com',
      );

      expect(result.isSuccess, false);
      expect(result.message, contains('500'));
    });
  });

  group('DatabaseHelper Quiz Results SQLite Integration Tests', () {
    test('Records attempt and then updates with synced result', () async {
      final dbHelper = DatabaseHelper.instance;

      // 0. Insert a test subject and test quiz to satisfy foreign keys
      final testSubject = Subject(
        id: 'TEST_SUBJ_99',
        name: 'Test Subject',
        credits: 3,
        semester: 'Semester 1',
      );
      await dbHelper.insertSubject(testSubject);

      final testQuiz = QuizItem(
        title: 'Integration Test Quiz',
        link: 'https://docs.google.com/forms/d/e/test/viewform',
        subjectId: 'TEST_SUBJ_99',
        semester: 'Semester 1',
        chapter: 'Unit Test Chapter',
        syncUrl: 'https://script.google.com/macros/s/test/exec',
        totalMarks: 10.0,
      );
      await dbHelper.insertQuiz(testQuiz);

      final allQuizzes = await dbHelper.getQuizzes();
      final insertedQuiz = allQuizzes.firstWhere((q) => q.title == 'Integration Test Quiz');
      final testQuizId = insertedQuiz.id!;
      final testEmail = 'quiz_test_student@example.com';

      // 1. Record Attempt
      final attempt = await dbHelper.recordQuizAttempt(
        quizId: testQuizId,
        studentEmail: testEmail,
        studentName: 'Quiz Tester',
      );

      expect(attempt.quizId, testQuizId);
      expect(attempt.status, 'attempted');
      expect(attempt.isSynced, false);

      // Verify retrieval
      final fetchedAttempt = await dbHelper.getQuizResult(testQuizId, testEmail);
      expect(fetchedAttempt, isNotNull);
      expect(fetchedAttempt!.status, 'attempted');

      // 2. Record Sync Result
      final synced = await dbHelper.recordQuizSyncResult(
        quizId: testQuizId,
        studentEmail: testEmail,
        studentName: 'Quiz Tester',
        score: 9.0,
        totalMarks: 10.0,
        notes: 'Great job',
      );

      expect(synced.status, 'synced');
      expect(synced.score, 9.0);
      expect(synced.totalMarks, 10.0);
      expect(synced.isSynced, true);

      // 3. Ensure a second attempt does NOT overwrite the synced result
      final afterAttempt = await dbHelper.recordQuizAttempt(
        quizId: testQuizId,
        studentEmail: testEmail,
        studentName: 'Quiz Tester',
      );
      expect(afterAttempt.isSynced, true);
      expect(afterAttempt.score, 9.0);

      // 4. Retrieve student results
      final studentResults = await dbHelper.getQuizResultsForStudent(testEmail);
      expect(studentResults.any((r) => r.quizId == testQuizId), true);

      // 5. Retrieve quiz results for quiz
      final quizResults = await dbHelper.getQuizResultsForQuiz(testQuizId);
      expect(quizResults.any((r) => r.studentEmail == testEmail), true);

      // 6. Clean up
      await dbHelper.deleteQuiz(testQuizId);
      await dbHelper.deleteSubject('TEST_SUBJ_99');
    });
  });
}

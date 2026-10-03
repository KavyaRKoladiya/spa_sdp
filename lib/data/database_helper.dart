import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import 'mock_data.dart'; // Used as a fallback for Web

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on Web in this configuration.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('study_planner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Enable FFI for desktop platforms. Do not access io.Platform on Web.
    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          studentEmail TEXT NOT NULL,
          studentName TEXT NOT NULL,
          subjectName TEXT NOT NULL,
          subjectId TEXT,
          durationSeconds INTEGER NOT NULL,
          date TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE materials ADD COLUMN filePath TEXT');
      } catch (_) {}

      // Seed subjects if empty
      try {
        final countMaps = await db.rawQuery('SELECT COUNT(*) as cnt FROM subjects');
        final count = countMaps.isNotEmpty ? countMaps.first['cnt'] as int? : 0;
        if (count == null || count == 0) {
          for (final subject in MockData.subjects) {
            await db.insert('subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN syncUrl TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN totalMarks REAL');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quiz_results (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quizId INTEGER NOT NULL,
          studentEmail TEXT NOT NULL,
          studentName TEXT NOT NULL,
          status TEXT NOT NULL,
          score REAL,
          totalMarks REAL,
          attemptedAt TEXT NOT NULL,
          synchronizedAt TEXT,
          notes TEXT,
          FOREIGN KEY (quizId) REFERENCES quizzes (id) ON DELETE CASCADE,
          UNIQUE (quizId, studentEmail)
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        semester TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        credits INTEGER NOT NULL,
        semester TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        fileName TEXT NOT NULL,
        filePath TEXT,
        subjectId TEXT NOT NULL,
        semester TEXT NOT NULL,
        chapter TEXT NOT NULL,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE quizzes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        subjectId TEXT NOT NULL,
        semester TEXT NOT NULL,
        chapter TEXT NOT NULL,
        syncUrl TEXT,
        totalMarks REAL,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentEmail TEXT NOT NULL,
        studentName TEXT NOT NULL,
        subjectName TEXT NOT NULL,
        subjectId TEXT,
        durationSeconds INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quizId INTEGER NOT NULL,
        studentEmail TEXT NOT NULL,
        studentName TEXT NOT NULL,
        status TEXT NOT NULL,
        score REAL,
        totalMarks REAL,
        attemptedAt TEXT NOT NULL,
        synchronizedAt TEXT,
        notes TEXT,
        FOREIGN KEY (quizId) REFERENCES quizzes (id) ON DELETE CASCADE,
        UNIQUE (quizId, studentEmail)
      )
    ''');

    // Pre-populate default subjects from MockData
    for (final subject in MockData.subjects) {
      await db.insert('subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // --- Students ---
  Future<Student> insertStudent(Student student) async {
    if (kIsWeb) {
      student = Student(id: DateTime.now().millisecondsSinceEpoch, name: student.name, email: student.email, password: student.password, semester: student.semester);
      MockData.students.add(student);
      return student;
    }
    final db = await instance.database;
    final id = await db.insert('students', student.toMap());
    return Student(
      id: id,
      name: student.name,
      email: student.email,
      password: student.password,
      semester: student.semester,
    );
  }

  Future<Student?> getStudentByEmail(String email) async {
    if (kIsWeb) {
      try {
        return MockData.students.firstWhere((s) => s.email == email);
      } catch (e) {
        return null;
      }
    }
    final db = await instance.database;
    final maps = await db.query('students', where: 'email = ?', whereArgs: [email]);
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  // --- Subjects ---
  Future<void> insertSubject(Subject subject) async {
    if (kIsWeb) {
      MockData.subjects.add(subject);
      return;
    }
    final db = await instance.database;
    await db.insert('subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Subject>> getSubjects() async {
    if (kIsWeb) return MockData.subjects;
    final db = await instance.database;
    final maps = await db.query('subjects');
    return maps.map((map) => Subject.fromMap(map)).toList();
  }

  Future<List<Subject>> getSubjectsBySemester(String semester) async {
    if (kIsWeb) {
      return MockData.subjects
          .where((s) => s.semester.trim().toLowerCase() == semester.trim().toLowerCase())
          .toList();
    }
    final db = await instance.database;
    final maps = await db.query(
      'subjects',
      where: 'LOWER(TRIM(semester)) = ?',
      whereArgs: [semester.trim().toLowerCase()],
    );
    return maps.map((map) => Subject.fromMap(map)).toList();
  }

  
  Future<void> deleteSubject(String id) async {
    if (kIsWeb) {
      MockData.subjects.removeWhere((s) => s.id == id);
      MockData.materials.removeWhere((m) => m.subjectId == id);
      MockData.quizzes.removeWhere((q) => q.subjectId == id);
      return;
    }
    final db = await instance.database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // --- Materials ---
  Future<void> insertMaterial(MaterialItem material) async {
    if (kIsWeb) {
      material = MaterialItem(
        id: DateTime.now().millisecondsSinceEpoch,
        title: material.title,
        type: material.type,
        fileName: material.fileName,
        filePath: material.filePath,
        subjectId: material.subjectId,
        semester: material.semester,
        chapter: material.chapter,
      );
      MockData.materials.add(material);
      return;
    }
    final db = await instance.database;
    await db.insert('materials', material.toMap());
  }

  Future<List<MaterialItem>> getMaterials() async {
    if (kIsWeb) return MockData.materials;
    final db = await instance.database;
    final maps = await db.query('materials');
    return maps.map((map) => MaterialItem.fromMap(map)).toList();
  }

  Future<List<MaterialItem>> getMaterialsBySemester(String semester) async {
    if (kIsWeb) return MockData.materials.where((m) => m.semester == semester).toList();
    final db = await instance.database;
    final maps = await db.query('materials', where: 'semester = ?', whereArgs: [semester]);
    return maps.map((map) => MaterialItem.fromMap(map)).toList();
  }

  Future<void> deleteMaterial(int id) async {
    if (kIsWeb) {
      MockData.materials.removeWhere((m) => m.id == id);
      return;
    }
    final db = await instance.database;
    try {
      final maps = await db.query('materials', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        final path = maps.first['filePath'] as String?;
        if (path != null && path.isNotEmpty) {
          final file = io.File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  // --- Quizzes ---
  Future<void> insertQuiz(QuizItem quiz) async {
    if (kIsWeb) {
      quiz = QuizItem(
        id: DateTime.now().millisecondsSinceEpoch,
        title: quiz.title,
        link: quiz.link,
        subjectId: quiz.subjectId,
        semester: quiz.semester,
        chapter: quiz.chapter,
        syncUrl: quiz.syncUrl,
        totalMarks: quiz.totalMarks,
      );
      MockData.quizzes.add(quiz);
      return;
    }
    final db = await instance.database;
    await db.insert('quizzes', quiz.toMap());
  }

  Future<List<QuizItem>> getQuizzes() async {
    if (kIsWeb) return MockData.quizzes;
    final db = await instance.database;
    final maps = await db.query('quizzes');
    return maps.map((map) => QuizItem.fromMap(map)).toList();
  }

  Future<List<QuizItem>> getQuizzesBySemester(String semester) async {
    if (kIsWeb) return MockData.quizzes.where((q) => q.semester == semester).toList();
    final db = await instance.database;
    final maps = await db.query('quizzes', where: 'semester = ?', whereArgs: [semester]);
    return maps.map((map) => QuizItem.fromMap(map)).toList();
  }

  Future<void> deleteQuiz(int id) async {
    if (kIsWeb) {
      MockData.quizzes.removeWhere((q) => q.id == id);
      MockData.quizResults.removeWhere((r) => r.quizId == id);
      return;
    }
    final db = await instance.database;
    try {
      await db.delete('quiz_results', where: 'quizId = ?', whereArgs: [id]);
    } catch (_) {}
    await db.delete('quizzes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Study Sessions ---
  Future<StudySession> insertStudySession(StudySession session) async {
    if (kIsWeb) {
      final newSession = StudySession(
        id: DateTime.now().millisecondsSinceEpoch,
        studentEmail: session.studentEmail,
        studentName: session.studentName,
        subjectName: session.subjectName,
        subjectId: session.subjectId,
        durationSeconds: session.durationSeconds,
        date: session.date,
        notes: session.notes,
      );
      MockData.studySessions.insert(0, newSession);
      return newSession;
    }
    final db = await instance.database;
    final id = await db.insert('study_sessions', session.toMap());
    return StudySession(
      id: id,
      studentEmail: session.studentEmail,
      studentName: session.studentName,
      subjectName: session.subjectName,
      subjectId: session.subjectId,
      durationSeconds: session.durationSeconds,
      date: session.date,
      notes: session.notes,
    );
  }

  Future<List<StudySession>> getStudySessionsByStudent(String studentEmail) async {
    if (kIsWeb) {
      final list = MockData.studySessions
          .where((s) => s.studentEmail.trim().toLowerCase() == studentEmail.trim().toLowerCase())
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
    final db = await instance.database;
    final maps = await db.query(
      'study_sessions',
      where: 'LOWER(TRIM(studentEmail)) = ?',
      whereArgs: [studentEmail.trim().toLowerCase()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => StudySession.fromMap(map)).toList();
  }

  Future<void> deleteStudySession(int id) async {
    if (kIsWeb) {
      MockData.studySessions.removeWhere((s) => s.id == id);
      return;
    }
    final db = await instance.database;
    await db.delete('study_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // --- Quiz Results & Attempt Tracking ---
  Future<QuizResult?> getQuizResult(int quizId, String studentEmail) async {
    final cleanEmail = studentEmail.trim().toLowerCase();
    if (kIsWeb) {
      try {
        return MockData.quizResults.firstWhere(
          (r) => r.quizId == quizId && r.studentEmail.trim().toLowerCase() == cleanEmail,
        );
      } catch (_) {
        return null;
      }
    }
    final db = await instance.database;
    final maps = await db.query(
      'quiz_results',
      where: 'quizId = ? AND LOWER(TRIM(studentEmail)) = ?',
      whereArgs: [quizId, cleanEmail],
    );
    if (maps.isNotEmpty) {
      return QuizResult.fromMap(maps.first);
    }
    return null;
  }

  Future<List<QuizResult>> getQuizResultsForStudent(String studentEmail) async {
    final cleanEmail = studentEmail.trim().toLowerCase();
    if (kIsWeb) {
      return MockData.quizResults
          .where((r) => r.studentEmail.trim().toLowerCase() == cleanEmail)
          .toList();
    }
    final db = await instance.database;
    final maps = await db.query(
      'quiz_results',
      where: 'LOWER(TRIM(studentEmail)) = ?',
      whereArgs: [cleanEmail],
      orderBy: 'attemptedAt DESC',
    );
    return maps.map((map) => QuizResult.fromMap(map)).toList();
  }

  Future<List<QuizResult>> getQuizResultsForQuiz(int quizId) async {
    if (kIsWeb) {
      return MockData.quizResults.where((r) => r.quizId == quizId).toList();
    }
    final db = await instance.database;
    final maps = await db.query(
      'quiz_results',
      where: 'quizId = ?',
      whereArgs: [quizId],
      orderBy: 'attemptedAt DESC',
    );
    return maps.map((map) => QuizResult.fromMap(map)).toList();
  }

  Future<QuizResult> recordQuizAttempt({
    required int quizId,
    required String studentEmail,
    required String studentName,
  }) async {
    final cleanEmail = studentEmail.trim().toLowerCase();
    final existing = await getQuizResult(quizId, cleanEmail);

    // If already synced, keep the synced result so we don't erase the score!
    if (existing != null && existing.isSynced) {
      return existing;
    }

    final now = DateTime.now();
    if (kIsWeb) {
      if (existing != null) {
        final updated = existing.copyWith(
          studentName: studentName,
          status: 'attempted',
          attemptedAt: now,
        );
        final index = MockData.quizResults.indexWhere((r) => r.id == existing.id);
        if (index != -1) MockData.quizResults[index] = updated;
        return updated;
      } else {
        final newResult = QuizResult(
          id: DateTime.now().millisecondsSinceEpoch,
          quizId: quizId,
          studentEmail: cleanEmail,
          studentName: studentName,
          status: 'attempted',
          attemptedAt: now,
        );
        MockData.quizResults.add(newResult);
        return newResult;
      }
    }

    final db = await instance.database;
    if (existing != null) {
      await db.update(
        'quiz_results',
        {
          'studentName': studentName,
          'status': 'attempted',
          'attemptedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.copyWith(
        studentName: studentName,
        status: 'attempted',
        attemptedAt: now,
      );
    } else {
      final newResult = QuizResult(
        quizId: quizId,
        studentEmail: cleanEmail,
        studentName: studentName,
        status: 'attempted',
        attemptedAt: now,
      );
      final id = await db.insert('quiz_results', newResult.toMap());
      return newResult.copyWith(id: id);
    }
  }

  Future<QuizResult> recordQuizSyncResult({
    required int quizId,
    required String studentEmail,
    required String studentName,
    required double score,
    required double totalMarks,
    String? notes,
  }) async {
    final cleanEmail = studentEmail.trim().toLowerCase();
    final existing = await getQuizResult(quizId, cleanEmail);
    final now = DateTime.now();

    if (kIsWeb) {
      if (existing != null) {
        final updated = existing.copyWith(
          studentName: studentName,
          status: 'synced',
          score: score,
          totalMarks: totalMarks,
          synchronizedAt: now,
          notes: notes,
        );
        final index = MockData.quizResults.indexWhere((r) => r.id == existing.id);
        if (index != -1) MockData.quizResults[index] = updated;
        return updated;
      } else {
        final newResult = QuizResult(
          id: DateTime.now().millisecondsSinceEpoch,
          quizId: quizId,
          studentEmail: cleanEmail,
          studentName: studentName,
          status: 'synced',
          score: score,
          totalMarks: totalMarks,
          attemptedAt: now,
          synchronizedAt: now,
          notes: notes,
        );
        MockData.quizResults.add(newResult);
        return newResult;
      }
    }

    final db = await instance.database;
    if (existing != null) {
      await db.update(
        'quiz_results',
        {
          'studentName': studentName,
          'status': 'synced',
          'score': score,
          'totalMarks': totalMarks,
          'synchronizedAt': now.toIso8601String(),
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.copyWith(
        studentName: studentName,
        status: 'synced',
        score: score,
        totalMarks: totalMarks,
        synchronizedAt: now,
        notes: notes,
      );
    } else {
      final newResult = QuizResult(
        quizId: quizId,
        studentEmail: cleanEmail,
        studentName: studentName,
        status: 'synced',
        score: score,
        totalMarks: totalMarks,
        attemptedAt: now,
        synchronizedAt: now,
        notes: notes,
      );
      final id = await db.insert('quiz_results', newResult.toMap());
      return newResult.copyWith(id: id);
    }
  }

  Future<void> deleteQuizResult(int id) async {
    if (kIsWeb) {
      MockData.quizResults.removeWhere((r) => r.id == id);
      return;
    }
    final db = await instance.database;
    await db.delete('quiz_results', where: 'id = ?', whereArgs: [id]);
  }
}


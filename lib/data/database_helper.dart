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
        version: 1,
        onCreate: _createDB,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
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
      material = MaterialItem(id: DateTime.now().millisecondsSinceEpoch, title: material.title, type: material.type, fileName: material.fileName, subjectId: material.subjectId, semester: material.semester, chapter: material.chapter);
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
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  // --- Quizzes ---
  Future<void> insertQuiz(QuizItem quiz) async {
    if (kIsWeb) {
      quiz = QuizItem(id: DateTime.now().millisecondsSinceEpoch, title: quiz.title, link: quiz.link, subjectId: quiz.subjectId, semester: quiz.semester, chapter: quiz.chapter);
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
      return;
    }
    final db = await instance.database;
    await db.delete('quizzes', where: 'id = ?', whereArgs: [id]);
  }
}

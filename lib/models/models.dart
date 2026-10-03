class Student {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String semester;

  Student({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.semester,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'semester': semester,
      };

  static Student fromMap(Map<String, dynamic> map) => Student(
        id: map['id'],
        name: map['name'],
        email: map['email'],
        password: map['password'],
        semester: map['semester'],
      );
}

class Subject {
  final String id;
  final String name;
  final int credits;
  final String semester;

  Subject({
    required this.id,
    required this.name,
    required this.credits,
    required this.semester,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'credits': credits,
        'semester': semester,
      };

  static Subject fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'],
        name: map['name'],
        credits: map['credits'],
        semester: map['semester'],
      );
}

class MaterialItem {
  final int? id;
  final String title;
  final String type;
  final String fileName;
  final String? filePath;
  final String subjectId;
  final String semester;
  final String chapter;

  MaterialItem({
    this.id,
    required this.title,
    this.type = 'PDF',
    required this.fileName,
    this.filePath,
    required this.subjectId,
    required this.semester,
    required this.chapter,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'fileName': fileName,
        'filePath': filePath,
        'subjectId': subjectId,
        'semester': semester,
        'chapter': chapter,
      };

  static MaterialItem fromMap(Map<String, dynamic> map) => MaterialItem(
        id: map['id'],
        title: map['title'],
        type: map['type'] ?? 'PDF',
        fileName: map['fileName'],
        filePath: map['filePath'],
        subjectId: map['subjectId'],
        semester: map['semester'],
        chapter: map['chapter'],
      );
}

class QuizItem {
  final int? id;
  final String title;
  final String link;
  final String subjectId;
  final String semester;
  final String chapter;
  final String? syncUrl;
  final double? totalMarks;

  QuizItem({
    this.id,
    required this.title,
    required this.link,
    required this.subjectId,
    required this.semester,
    required this.chapter,
    this.syncUrl,
    this.totalMarks,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'link': link,
        'subjectId': subjectId,
        'semester': semester,
        'chapter': chapter,
        'syncUrl': syncUrl,
        'totalMarks': totalMarks,
      };

  static QuizItem fromMap(Map<String, dynamic> map) => QuizItem(
        id: map['id'],
        title: map['title'],
        link: map['link'],
        subjectId: map['subjectId'],
        semester: map['semester'],
        chapter: map['chapter'],
        syncUrl: map['syncUrl'],
        totalMarks: map['totalMarks'] != null
            ? (map['totalMarks'] is num
                ? (map['totalMarks'] as num).toDouble()
                : double.tryParse(map['totalMarks'].toString()))
            : null,
      );
}

class QuizResult {
  final int? id;
  final int quizId;
  final String studentEmail;
  final String studentName;
  final String status; // 'attempted', 'synced'
  final double? score;
  final double? totalMarks;
  final DateTime attemptedAt;
  final DateTime? synchronizedAt;
  final String? notes;

  QuizResult({
    this.id,
    required this.quizId,
    required this.studentEmail,
    required this.studentName,
    required this.status,
    this.score,
    this.totalMarks,
    required this.attemptedAt,
    this.synchronizedAt,
    this.notes,
  });

  bool get isSynced => status == 'synced' && score != null;
  bool get isAttempted => status == 'attempted';

  double get percentage =>
      (totalMarks != null && totalMarks! > 0 && score != null)
          ? (score! / totalMarks!) * 100
          : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'quizId': quizId,
        'studentEmail': studentEmail,
        'studentName': studentName,
        'status': status,
        'score': score,
        'totalMarks': totalMarks,
        'attemptedAt': attemptedAt.toIso8601String(),
        'synchronizedAt': synchronizedAt?.toIso8601String(),
        'notes': notes,
      };

  static QuizResult fromMap(Map<String, dynamic> map) => QuizResult(
        id: map['id'],
        quizId: map['quizId'] is int
            ? map['quizId']
            : int.tryParse(map['quizId']?.toString() ?? '0') ?? 0,
        studentEmail: map['studentEmail'] ?? '',
        studentName: map['studentName'] ?? '',
        status: map['status'] ?? 'attempted',
        score: map['score'] != null
            ? (map['score'] is num
                ? (map['score'] as num).toDouble()
                : double.tryParse(map['score'].toString()))
            : null,
        totalMarks: map['totalMarks'] != null
            ? (map['totalMarks'] is num
                ? (map['totalMarks'] as num).toDouble()
                : double.tryParse(map['totalMarks'].toString()))
            : null,
        attemptedAt: DateTime.tryParse(map['attemptedAt']?.toString() ?? '') ??
            DateTime.now(),
        synchronizedAt: map['synchronizedAt'] != null
            ? DateTime.tryParse(map['synchronizedAt'].toString())
            : null,
        notes: map['notes'],
      );

  QuizResult copyWith({
    int? id,
    int? quizId,
    String? studentEmail,
    String? studentName,
    String? status,
    double? score,
    double? totalMarks,
    DateTime? attemptedAt,
    DateTime? synchronizedAt,
    String? notes,
  }) {
    return QuizResult(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      studentEmail: studentEmail ?? this.studentEmail,
      studentName: studentName ?? this.studentName,
      status: status ?? this.status,
      score: score ?? this.score,
      totalMarks: totalMarks ?? this.totalMarks,
      attemptedAt: attemptedAt ?? this.attemptedAt,
      synchronizedAt: synchronizedAt ?? this.synchronizedAt,
      notes: notes ?? this.notes,
    );
  }
}

class StudySession {
  final int? id;
  final String studentEmail;
  final String studentName;
  final String subjectName;
  final String? subjectId;
  final int durationSeconds;
  final DateTime date;
  final String? notes;

  StudySession({
    this.id,
    required this.studentEmail,
    required this.studentName,
    required this.subjectName,
    this.subjectId,
    required this.durationSeconds,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentEmail': studentEmail,
        'studentName': studentName,
        'subjectName': subjectName,
        'subjectId': subjectId,
        'durationSeconds': durationSeconds,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  static StudySession fromMap(Map<String, dynamic> map) => StudySession(
        id: map['id'],
        studentEmail: map['studentEmail'] ?? '',
        studentName: map['studentName'] ?? '',
        subjectName: map['subjectName'] ?? '',
        subjectId: map['subjectId'],
        durationSeconds: map['durationSeconds'] is int
            ? map['durationSeconds']
            : int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0,
        date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        notes: map['notes'],
      );
}


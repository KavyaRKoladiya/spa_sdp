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
  final String subjectId;
  final String semester;
  final String chapter;

  MaterialItem({
    this.id,
    required this.title,
    required this.type,
    required this.fileName,
    required this.subjectId,
    required this.semester,
    required this.chapter,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'fileName': fileName,
        'subjectId': subjectId,
        'semester': semester,
        'chapter': chapter,
      };

  static MaterialItem fromMap(Map<String, dynamic> map) => MaterialItem(
        id: map['id'],
        title: map['title'],
        type: map['type'],
        fileName: map['fileName'],
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

  QuizItem({
    this.id,
    required this.title,
    required this.link,
    required this.subjectId,
    required this.semester,
    required this.chapter,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'link': link,
        'subjectId': subjectId,
        'semester': semester,
        'chapter': chapter,
      };

  static QuizItem fromMap(Map<String, dynamic> map) => QuizItem(
        id: map['id'],
        title: map['title'],
        link: map['link'],
        subjectId: map['subjectId'],
        semester: map['semester'],
        chapter: map['chapter'],
      );
}

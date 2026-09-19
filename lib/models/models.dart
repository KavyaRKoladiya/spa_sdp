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
}

class MaterialItem {
  final String title;
  final String type;
  final String fileName;
  final String subjectId;
  final String semester;
  final String chapter;

  MaterialItem({
    required this.title,
    required this.type,
    required this.fileName,
    required this.subjectId,
    required this.semester,
    required this.chapter,
  });
}

class QuizItem {
  final String title;
  final String link;
  final String subjectId;
  final String semester;
  final String chapter;

  QuizItem({
    required this.title,
    required this.link,
    required this.subjectId,
    required this.semester,
    required this.chapter,
  });
}

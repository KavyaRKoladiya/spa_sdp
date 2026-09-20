import '../models/models.dart';

class MockData {
  // We keep this to track the logged-in user's semester across screens
  static String currentStudentSemester = 'Semester 1';
  static Student? currentStudent;

  static List<Student> students = [];
  static List<Subject> subjects = [];
  static List<MaterialItem> materials = [];
  static List<QuizItem> quizzes = [];

  static final List<String> semesters = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8'
  ];
}

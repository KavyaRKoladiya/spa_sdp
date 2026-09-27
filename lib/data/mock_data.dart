import '../models/models.dart';

class MockData {
  // We keep this to track the logged-in user's semester across screens
  static String currentStudentSemester = 'Semester 1';
  static Student? currentStudent;

  static List<Student> students = [];
  static List<Subject> subjects = [
    Subject(id: 'CS101', name: 'Mathematics I', credits: 4, semester: 'Semester 1'),
    Subject(id: 'CS102', name: 'Programming in C', credits: 4, semester: 'Semester 1'),
    Subject(id: 'CS103', name: 'Basic Electrical Eng.', credits: 3, semester: 'Semester 1'),
    Subject(id: 'CS201', name: 'Data Structures', credits: 4, semester: 'Semester 2'),
    Subject(id: 'CS202', name: 'Digital Logic & Design', credits: 3, semester: 'Semester 2'),
    Subject(id: 'CS301', name: 'Object Oriented Programming (Java)', credits: 4, semester: 'Semester 3'),
    Subject(id: 'CS302', name: 'Database Management Systems', credits: 4, semester: 'Semester 3'),
    Subject(id: 'CS401', name: 'Operating Systems', credits: 4, semester: 'Semester 4'),
    Subject(id: 'CS402', name: 'Computer Networks', credits: 4, semester: 'Semester 4'),
    Subject(id: 'CS501', name: 'Software Engineering', credits: 4, semester: 'Semester 5'),
    Subject(id: 'CS502', name: 'Analysis & Design of Algorithms', credits: 4, semester: 'Semester 5'),
    Subject(id: 'CS503', name: 'Web Technology', credits: 3, semester: 'Semester 5'),
    Subject(id: 'CS601', name: 'Machine Learning', credits: 4, semester: 'Semester 6'),
    Subject(id: 'CS701', name: 'Artificial Intelligence', credits: 4, semester: 'Semester 7'),
    Subject(id: 'CS801', name: 'Cloud Computing & Distributed Systems', credits: 4, semester: 'Semester 8'),
  ];
  static List<MaterialItem> materials = [];
  static List<QuizItem> quizzes = [];
  static List<StudySession> studySessions = [];

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


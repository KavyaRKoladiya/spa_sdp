import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';
import '../../data/database_helper.dart';
import '../../models/models.dart';

class StudentQuizzesPage extends StatefulWidget {
  const StudentQuizzesPage({super.key});

  @override
  State<StudentQuizzesPage> createState() => _StudentQuizzesPageState();
}

class _StudentQuizzesPageState extends State<StudentQuizzesPage> {
  List<QuizItem> _myQuizzes = [];
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final quizzes = await DatabaseHelper.instance.getQuizzesBySemester(MockData.currentStudentSemester);
    final subjects = await DatabaseHelper.instance.getSubjects();
    setState(() {
      _myQuizzes = quizzes;
      _subjects = subjects;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String urlString, BuildContext context) async {
    // Add http:// prefix if missing so url_launcher handles it correctly
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myQuizzes.isEmpty
          ? Center(
              child: Text(
                'No quizzes available for ${MockData.currentStudentSemester}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myQuizzes.length,
              itemBuilder: (context, index) {
                final quiz = _myQuizzes[index];
                
                // Get subject name
                final subjectName = _subjects
                    .firstWhere((s) => s.id == quiz.subjectId, orElse: () => Subject(id: '', name: 'Unknown Subject', credits: 0, semester: ''))
                    .name;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: const Icon(Icons.quiz, color: Colors.orange),
                    ),
                    title: Text(
                      quiz.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('$subjectName - ${quiz.chapter}'),
                        const SizedBox(height: 4),
                        Text(
                          quiz.link, // Just show the link for now
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () {
                        // Open google form link
                        _launchUrl(quiz.link, context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Attempt'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

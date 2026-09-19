import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';

class StudentQuizzesPage extends StatelessWidget {
  const StudentQuizzesPage({super.key});

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
    // Filter quizzes by the student's current semester
    final myQuizzes = MockData.quizzes
        .where((q) => q.semester == MockData.currentStudentSemester)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: myQuizzes.isEmpty
          ? Center(
              child: Text(
                'No quizzes available for ${MockData.currentStudentSemester}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myQuizzes.length,
              itemBuilder: (context, index) {
                final quiz = myQuizzes[index];
                
                // Get subject name
                final subjectName = MockData.subjects
                    .firstWhere((s) => s.id == quiz.subjectId, orElse: () => MockData.subjects.first)
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

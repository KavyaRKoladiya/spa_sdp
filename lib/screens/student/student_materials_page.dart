import 'package:flutter/material.dart';
import '../../data/mock_data.dart';

class StudentMaterialsPage extends StatelessWidget {
  const StudentMaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Filter materials by the student's current semester
    final myMaterials = MockData.materials
        .where((m) => m.semester == MockData.currentStudentSemester)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: myMaterials.isEmpty
          ? Center(
              child: Text(
                'No materials available for ${MockData.currentStudentSemester}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myMaterials.length,
              itemBuilder: (context, index) {
                final item = myMaterials[index];
                IconData icon;
                switch (item.type) {
                  case 'PDF':
                    icon = Icons.picture_as_pdf;
                    break;
                  case 'Word Document':
                    icon = Icons.description;
                    break;
                  case 'PPT':
                    icon = Icons.slideshow;
                    break;
                  case 'Text Document':
                    icon = Icons.text_snippet;
                    break;
                  default:
                    icon = Icons.insert_drive_file;
                }

                // Get subject name
                final subjectName = MockData.subjects
                    .firstWhere((s) => s.id == item.subjectId, orElse: () => MockData.subjects.first)
                    .name;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('$subjectName - ${item.chapter}'),
                        const SizedBox(height: 4),
                        Text(
                          item.fileName,
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      // In a real app, you would open the downloaded file here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening ${item.fileName}...')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

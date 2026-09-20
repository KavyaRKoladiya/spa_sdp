import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../data/database_helper.dart';
import '../../models/models.dart';

class StudentMaterialsPage extends StatefulWidget {
  const StudentMaterialsPage({super.key});

  @override
  State<StudentMaterialsPage> createState() => _StudentMaterialsPageState();
}

class _StudentMaterialsPageState extends State<StudentMaterialsPage> {
  List<MaterialItem> _myMaterials = [];
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final materials = await DatabaseHelper.instance.getMaterialsBySemester(MockData.currentStudentSemester);
    final subjects = await DatabaseHelper.instance.getSubjects();
    setState(() {
      _myMaterials = materials;
      _subjects = subjects;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _myMaterials.isEmpty
          ? Center(
              child: Text(
                'No materials available for ${MockData.currentStudentSemester}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myMaterials.length,
              itemBuilder: (context, index) {
                final item = _myMaterials[index];
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
                final subjectName = _subjects
                    .firstWhere((s) => s.id == item.subjectId, orElse: () => Subject(id: '', name: 'Unknown Subject', credits: 0, semester: ''))
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

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';

class ManageSubjectsPage extends StatefulWidget {
  const ManageSubjectsPage({super.key});

  @override
  State<ManageSubjectsPage> createState() => _ManageSubjectsPageState();
}

class _ManageSubjectsPageState extends State<ManageSubjectsPage> {
  void _addSubjectDialog() {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final creditsController = TextEditingController();
    String? selectedSemester = MockData.semesters.first;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Subject'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSemester,
                    decoration: const InputDecoration(labelText: 'Semester'),
                    items: MockData.semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => selectedSemester = val,
                  ),
                  TextFormField(
                    controller: idController,
                    decoration: const InputDecoration(labelText: 'Subject ID'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Subject Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: creditsController,
                    decoration: const InputDecoration(labelText: 'Credits'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    MockData.subjects.add(Subject(
                      id: idController.text,
                      name: nameController.text,
                      credits: int.parse(creditsController.text),
                      semester: selectedSemester!,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subjects'),
      ),
      body: MockData.subjects.isEmpty
          ? const Center(child: Text('No subjects added yet.'))
          : ListView.builder(
              itemCount: MockData.subjects.length,
              itemBuilder: (context, index) {
                final subject = MockData.subjects[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(subject.credits.toString())),
                  title: Text('${subject.name} (${subject.id})'),
                  subtitle: Text(subject.semester),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: const Text('Are you sure you want to delete this subject? Related materials and quizzes will also be deleted.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    MockData.subjects.removeAt(index);
                                    MockData.materials.removeWhere((m) => m.subjectId == subject.id);
                                    MockData.quizzes.removeWhere((q) => q.subjectId == subject.id);
                                  });
                                  Navigator.pop(context); // Close dialog
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubjectDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

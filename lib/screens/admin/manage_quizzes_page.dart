import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../data/database_helper.dart';

class ManageQuizzesPage extends StatefulWidget {
  const ManageQuizzesPage({super.key});

  @override
  State<ManageQuizzesPage> createState() => _ManageQuizzesPageState();
}

class _ManageQuizzesPageState extends State<ManageQuizzesPage> {
  List<QuizItem> _quizzes = [];
  List<Subject> _allSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final quizzes = await DatabaseHelper.instance.getQuizzes();
      final subjects = await DatabaseHelper.instance.getSubjects();
      setState(() {
        _quizzes = quizzes;
        _allSubjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }
  void _addQuizDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    final chapterController = TextEditingController();
    String? selectedSemester = MockData.semesters.first;
    String? selectedSubjectId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter subjects based on selected semester
            final availableSubjects = _allSubjects
                .where((s) => s.semester == selectedSemester)
                .toList();
            if (availableSubjects.isNotEmpty && 
                !availableSubjects.any((s) => s.id == selectedSubjectId)) {
              selectedSubjectId = availableSubjects.first.id;
            } else if (availableSubjects.isEmpty) {
              selectedSubjectId = null;
            }

            return AlertDialog(
              title: const Text('Add Quiz'),
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
                        onChanged: (val) {
                          setDialogState(() {
                            selectedSemester = val;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: availableSubjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) => selectedSubjectId = val,
                        validator: (v) => v == null ? 'Please select a subject' : null,
                      ),
                      TextFormField(
                        controller: chapterController,
                        decoration: const InputDecoration(labelText: 'Chapter/Topic'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Quiz Title'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: linkController,
                        decoration: const InputDecoration(labelText: 'Google Form Link'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newQuiz = QuizItem(
                        title: titleController.text,
                        link: linkController.text,
                        subjectId: selectedSubjectId!,
                        semester: selectedSemester!,
                        chapter: chapterController.text,
                      );
                      
                      await DatabaseHelper.instance.insertQuiz(newQuiz);
                      _loadData();
                      
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Quizzes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizzes.isEmpty
          ? const Center(child: Text('No quizzes added yet.'))
          : ListView.builder(
              itemCount: _quizzes.length,
              itemBuilder: (context, index) {
                final quiz = _quizzes[index];
                return ListTile(
                  leading: const Icon(Icons.quiz),
                  title: Text(quiz.title),
                  subtitle: Text('${quiz.subjectId} - ${quiz.chapter}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(quiz.semester),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text('Are you sure you want to delete this quiz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await DatabaseHelper.instance.deleteQuiz(quiz.id!);
                                      _loadData();
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuizDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

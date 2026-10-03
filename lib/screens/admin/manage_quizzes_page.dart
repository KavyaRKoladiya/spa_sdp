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
      if (mounted) {
        setState(() {
          _quizzes = quizzes;
          _allSubjects = subjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    final syncUrlController = TextEditingController();
    final totalMarksController = TextEditingController(text: '10');
    String? selectedSemester = MockData.semesters.first;
    String? selectedSubjectId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                        // ignore: deprecated_member_use
                        value: selectedSemester,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        items: MockData.semesters
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedSemester = val;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: availableSubjects
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (val) => selectedSubjectId = val,
                        validator: (v) => v == null ? 'Please select a subject' : null,
                      ),
                      TextFormField(
                        controller: chapterController,
                        decoration: const InputDecoration(labelText: 'Chapter/Topic'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Quiz Title'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: linkController,
                        decoration: const InputDecoration(
                          labelText: 'Google Form Link',
                          hintText: 'https://docs.google.com/forms/d/...',
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: syncUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Google Apps Script Sync URL (Optional)',
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          helperText: 'Web App URL to fetch scores automatically',
                          helperMaxLines: 2,
                        ),
                      ),
                      TextFormField(
                        controller: totalMarksController,
                        decoration: const InputDecoration(
                          labelText: 'Total Marks',
                          hintText: '10',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final totalMarks =
                          double.tryParse(totalMarksController.text.trim()) ?? 10.0;
                      final syncUrl = syncUrlController.text.trim().isNotEmpty
                          ? syncUrlController.text.trim()
                          : null;

                      final newQuiz = QuizItem(
                        title: titleController.text.trim(),
                        link: linkController.text.trim(),
                        subjectId: selectedSubjectId!,
                        semester: selectedSemester!,
                        chapter: chapterController.text.trim(),
                        syncUrl: syncUrl,
                        totalMarks: totalMarks,
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
          },
        );
      },
    );
  }

  void _editSyncUrlDialog(QuizItem quiz) {
    final controller = TextEditingController(text: quiz.syncUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Sync URL: ${quiz.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Google Apps Script Web App URL deployed from the response Google Sheet:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Apps Script Web App URL',
                hintText: 'https://script.google.com/macros/s/.../exec',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              final updated = QuizItem(
                id: quiz.id,
                title: quiz.title,
                link: quiz.link,
                subjectId: quiz.subjectId,
                semester: quiz.semester,
                chapter: quiz.chapter,
                syncUrl: newUrl.isNotEmpty ? newUrl : null,
                totalMarks: quiz.totalMarks,
              );
              await DatabaseHelper.instance.insertQuiz(updated);
              _loadData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _viewResultsDialog(QuizItem quiz) async {
    final quizId = quiz.id;
    if (quizId == null) return;

    final results = await DatabaseHelper.instance.getQuizResultsForQuiz(quizId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quiz.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Student Submissions (${results.length})',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (results.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No students have attempted this quiz yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: results.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final res = results[i];
                          final isSynced = res.isSynced;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSynced
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                isSynced ? Icons.check : Icons.hourglass_top,
                                color: isSynced
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                              ),
                            ),
                            title: Text(
                              res.studentName.isNotEmpty ? res.studentName : 'Student',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(res.studentEmail, style: const TextStyle(fontSize: 12)),
                                Text(
                                  isSynced
                                      ? 'Synced on ${_formatDate(res.synchronizedAt!)}'
                                      : 'Attempted on ${_formatDate(res.attemptedAt)} (Pending Sync)',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            trailing: isSynced
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(
                                      '${res.score?.toStringAsFixed(res.score! % 1 == 0 ? 0 : 1)} / ${res.totalMarks?.toStringAsFixed(res.totalMarks! % 1 == 0 ? 0 : 1)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Text(
                                      'Pending',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
                    final hasSync = quiz.syncUrl?.isNotEmpty == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.quiz),
                        ),
                        title: Text(
                          quiz.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${quiz.subjectId} • ${quiz.chapter} • ${quiz.semester}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  hasSync ? Icons.cloud_done : Icons.cloud_off,
                                  size: 14,
                                  color: hasSync ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasSync ? 'Sync URL Configured' : 'No Sync URL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasSync ? Colors.green.shade800 : Colors.grey.shade600,
                                    fontWeight: hasSync ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View Submissions
                            IconButton(
                              icon: const Icon(Icons.people_outline, color: Colors.blue),
                              tooltip: 'View Student Results',
                              onPressed: () => _viewResultsDialog(quiz),
                            ),
                            // Edit Sync URL
                            IconButton(
                              icon: const Icon(Icons.link, color: Colors.teal),
                              tooltip: 'Edit Sync URL',
                              onPressed: () => _editSyncUrlDialog(quiz),
                            ),
                            // Delete
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Quiz',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text('Are you sure you want to delete this quiz?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await DatabaseHelper.instance.deleteQuiz(quiz.id!);
                                            _loadData();
                                          },
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
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

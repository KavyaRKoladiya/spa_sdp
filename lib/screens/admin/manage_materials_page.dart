import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';

class ManageMaterialsPage extends StatefulWidget {
  const ManageMaterialsPage({super.key});

  @override
  State<ManageMaterialsPage> createState() => _ManageMaterialsPageState();
}

class _ManageMaterialsPageState extends State<ManageMaterialsPage> {
  void _addMaterialDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final chapterController = TextEditingController();
    String? selectedSemester = MockData.semesters.first;
    String? selectedType = 'PDF';
    String? selectedSubjectId;
    String? selectedFileName;

    final types = ['PDF', 'Word Document', 'PPT', 'Text Document'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter subjects based on selected semester
            final availableSubjects = MockData.subjects
                .where((s) => s.semester == selectedSemester)
                .toList();
            if (availableSubjects.isNotEmpty && 
                !availableSubjects.any((s) => s.id == selectedSubjectId)) {
              selectedSubjectId = availableSubjects.first.id;
            } else if (availableSubjects.isEmpty) {
              selectedSubjectId = null;
            }

            return AlertDialog(
              title: const Text('Add Material'),
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
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Material Type'),
                        items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => selectedType = val,
                      ),
                      TextFormField(
                        controller: chapterController,
                        decoration: const InputDecoration(labelText: 'Chapter/Topic'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Material Title'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              PlatformFile? file = await FilePicker.pickFile();
                              if (file != null) {
                                setDialogState(() {
                                  selectedFileName = file.name;
                                });
                              }
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload File'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFileName ?? 'No file selected',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      if (selectedFileName == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please upload a file')),
                        );
                        return;
                      }
                      setState(() {
                        MockData.materials.add(MaterialItem(
                          title: titleController.text,
                          type: selectedType!,
                          fileName: selectedFileName!,
                          subjectId: selectedSubjectId!,
                          semester: selectedSemester!,
                          chapter: chapterController.text,
                        ));
                      });
                      Navigator.pop(context);
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
        title: const Text('Manage Materials'),
      ),
      body: MockData.materials.isEmpty
          ? const Center(child: Text('No materials added yet.'))
          : ListView.builder(
              itemCount: MockData.materials.length,
              itemBuilder: (context, index) {
                final item = MockData.materials[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(item.title),
                  subtitle: Text('${item.subjectId} - ${item.chapter} (${item.type})\nFile: ${item.fileName}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: const Text('Are you sure you want to delete this material?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    MockData.materials.removeAt(index);
                                  });
                                  Navigator.pop(context);
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
        onPressed: _addMaterialDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

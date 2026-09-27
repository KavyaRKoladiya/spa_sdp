import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:open_filex/open_filex.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../data/database_helper.dart';

class ManageMaterialsPage extends StatefulWidget {
  const ManageMaterialsPage({super.key});

  @override
  State<ManageMaterialsPage> createState() => _ManageMaterialsPageState();
}

class _ManageMaterialsPageState extends State<ManageMaterialsPage> {
  List<MaterialItem> _materials = [];
  List<Subject> _allSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final materials = await DatabaseHelper.instance.getMaterials();
      final subjects = await DatabaseHelper.instance.getSubjects();
      setState(() {
        _materials = materials;
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

  Future<String?> _savePdfLocally(PlatformFile file) async {
    try {
      if (kIsWeb) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final materialsDir = io.Directory(join(appDir.path, 'study_materials'));
      if (!await materialsDir.exists()) {
        await materialsDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = '${timestamp}_${file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_')}';
      final targetPath = join(materialsDir.path, safeName);

      if (file.path != null) {
        final sourceFile = io.File(file.path!);
        if (await sourceFile.exists()) {
          await sourceFile.copy(targetPath);
          return targetPath;
        }
      }
      try {
        final bytes = await file.xFile.readAsBytes();
        if (bytes.isNotEmpty) {
          final targetFile = io.File(targetPath);
          await targetFile.writeAsBytes(bytes);
          return targetPath;
        }
      } catch (_) {}
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF locally: $e');
      return file.path;
    }
  }

  Future<void> _openPdf(MaterialItem item) async {
    if (item.filePath != null && item.filePath!.isNotEmpty) {
      final file = io.File(item.filePath!);
      if (await file.exists()) {
        try {
          final result = await OpenFilex.open(item.filePath!);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open PDF: ${result.message}')),
            );
          }
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error opening PDF: $e')),
            );
          }
          return;
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF file "${item.fileName}" is not available on this device.'),
          backgroundColor: Colors.orange[800],
        ),
      );
    }
  }

  void _addMaterialDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final chapterController = TextEditingController();
    String? selectedSemester = MockData.semesters.first;
    String? selectedSubjectId;
    PlatformFile? selectedPlatformFile;
    String? selectedFileName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter subjects based on selected semester
            final availableSubjects = _allSubjects
                .where((s) => s.semester.trim().toLowerCase() == selectedSemester?.trim().toLowerCase())
                .toList();

            if (availableSubjects.isNotEmpty &&
                !availableSubjects.any((s) => s.id == selectedSubjectId)) {
              selectedSubjectId = availableSubjects.first.id;
            } else if (availableSubjects.isEmpty) {
              selectedSubjectId = null;
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Upload PDF Material'),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Semester selection
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: selectedSemester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: MockData.semesters
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedSemester = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Subject selection
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: selectedSubjectId,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          prefixIcon: Icon(Icons.book),
                        ),
                        items: availableSubjects
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (val) => selectedSubjectId = val,
                        validator: (v) => v == null ? 'Please select a subject' : null,
                        hint: availableSubjects.isEmpty
                            ? const Text('No subjects for this semester')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Chapter/Topic
                      TextFormField(
                        controller: chapterController,
                        decoration: const InputDecoration(
                          labelText: 'Chapter / Unit / Topic',
                          prefixIcon: Icon(Icons.bookmark_border),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Material Title
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'PDF Title / Notes Name',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // PDF File Picker
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final picked = await FilePicker.pickFile(
                                        type: FileType.custom,
                                        allowedExtensions: ['pdf'],
                                      );
                                      if (picked != null) {
                                        if (!picked.name.toLowerCase().endsWith('.pdf')) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please select a valid PDF file (.pdf)'),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        setDialogState(() {
                                          selectedPlatformFile = picked;
                                          selectedFileName = picked.name;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.upload_file, color: Colors.white),
                              label: const Text('Choose PDF File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  selectedFileName != null ? Icons.check_circle : Icons.info_outline,
                                  size: 16,
                                  color: selectedFileName != null ? Colors.green[700] : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    selectedFileName ?? 'No PDF selected (only .pdf allowed)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                                      color: selectedFileName != null ? Colors.black87 : Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            if (selectedPlatformFile == null || selectedFileName == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a PDF file')),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            final savedPath = await _savePdfLocally(selectedPlatformFile!);

                            final newMaterial = MaterialItem(
                              title: titleController.text.trim(),
                              type: 'PDF',
                              fileName: selectedFileName!,
                              filePath: savedPath,
                              subjectId: selectedSubjectId!,
                              semester: selectedSemester!,
                              chapter: chapterController.text.trim(),
                            );

                            await DatabaseHelper.instance.insertMaterial(newMaterial);
                            await _loadData();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${newMaterial.title}" successfully!'),
                                  backgroundColor: Colors.green[700],
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Study Materials (PDF)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No PDF materials added yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Click the + button below to upload a PDF.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    final item = _materials[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.semester} • ${item.subjectId} • ${item.chapter}\nFile: ${item.fileName}',
                          style: TextStyle(color: Colors.grey[800], fontSize: 13),
                        ),
                        isThreeLine: true,
                        onTap: () => _openPdf(item),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.blue),
                              tooltip: 'Open PDF',
                              onPressed: () => _openPdf(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: Text('Are you sure you want to delete "${item.title}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await DatabaseHelper.instance.deleteMaterial(item.id!);
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
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMaterialDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add PDF'),
      ),
    );
  }
}

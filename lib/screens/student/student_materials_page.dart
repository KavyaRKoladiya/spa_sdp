import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
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
    try {
      final materials = await DatabaseHelper.instance.getMaterialsBySemester(MockData.currentStudentSemester);
      final subjects = await DatabaseHelper.instance.getSubjects();
      setState(() {
        _myMaterials = materials;
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading materials: $e')),
        );
      }
    }
  }

  Future<void> _openPdf(MaterialItem item) async {
    String? resolvedPath = item.filePath;

    // Check if the primary filePath exists
    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      final file = io.File(resolvedPath);
      if (!await file.exists()) {
        resolvedPath = null;
      }
    }

    // Fallback: look in the app's study_materials directory
    if (resolvedPath == null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final materialsDir = io.Directory(join(appDir.path, 'study_materials'));
        if (await materialsDir.exists()) {
          final entities = materialsDir.listSync();
          for (final entity in entities) {
            if (entity is io.File && entity.path.endsWith(item.fileName)) {
              resolvedPath = entity.path;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (resolvedPath != null) {
      try {
        final result = await OpenFilex.open(resolvedPath);
        if (result.type != ResultType.done) {
          // Fallback to url_launcher Uri.file
          final fileUri = Uri.file(resolvedPath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open PDF: ${result.message}')),
            );
          }
        }
        return;
      } catch (e) {
        // Fallback attempt using url_launcher
        try {
          final fileUri = Uri.file(resolvedPath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
            return;
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening PDF: $e')),
          );
        }
        return;
      }
    }

    // File not found on disk
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF file "${item.fileName}" is not available on this device.'),
          backgroundColor: Colors.orange[800],
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials (PDF)'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myMaterials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No materials available for ${MockData.currentStudentSemester}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uploaded materials from admin will appear here.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myMaterials.length,
                  itemBuilder: (context, index) {
                    final item = _myMaterials[index];

                    // Get subject name
                    final subject = _subjects.firstWhere(
                      (s) => s.id == item.subjectId,
                      orElse: () => Subject(id: '', name: item.subjectId, credits: 0, semester: ''),
                    );
                    final subjectName = subject.name.isNotEmpty ? subject.name : item.subjectId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openPdf(item),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.red.withValues(alpha: 0.12),
                                child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$subjectName • ${item.chapter}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.attachment, size: 14, color: Colors.blue[700]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.fileName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _openPdf(item),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

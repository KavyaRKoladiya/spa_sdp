import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';
import '../../data/database_helper.dart';
import '../../data/quiz_sync_service.dart';
import '../../models/models.dart';

class StudentQuizzesPage extends StatefulWidget {
  const StudentQuizzesPage({super.key});

  @override
  State<StudentQuizzesPage> createState() => _StudentQuizzesPageState();
}

class _StudentQuizzesPageState extends State<StudentQuizzesPage> {
  final QuizSyncService _syncService = QuizSyncService();
  List<QuizItem> _myQuizzes = [];
  List<Subject> _subjects = [];
  Map<int, QuizResult> _resultsMap = {};
  final Set<int> _syncingQuizIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final student = MockData.currentStudent;
      final studentEmail = student?.email ?? '';
      final quizzes = await DatabaseHelper.instance.getQuizzesBySemester(MockData.currentStudentSemester);
      final subjects = await DatabaseHelper.instance.getSubjects();

      Map<int, QuizResult> resultMap = {};
      if (studentEmail.isNotEmpty) {
        final results = await DatabaseHelper.instance.getQuizResultsForStudent(studentEmail);
        for (final res in results) {
          resultMap[res.quizId] = res;
        }
      }

      if (mounted) {
        setState(() {
          _myQuizzes = quizzes;
          _subjects = subjects;
          _resultsMap = resultMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quizzes: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open quiz link: $url')),
        );
      }
    }
  }

  /// Opens the quiz in external browser and marks it as attempted in SQLite
  Future<void> _attemptQuiz(QuizItem quiz) async {
    final student = MockData.currentStudent;
    final studentEmail = student?.email ?? 'Unknown Student';
    final studentName = student?.name ?? 'Student';
    final existingResult = quiz.id != null ? _resultsMap[quiz.id!] : null;

    if (existingResult != null && existingResult.isSynced) {
      final shouldReattempt = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quiz Already Completed'),
          content: Text(
            'You have already completed this quiz with score: '
            '${existingResult.score?.toStringAsFixed(1)} / ${existingResult.totalMarks?.toStringAsFixed(1)} '
            '(${existingResult.percentage.toStringAsFixed(1)}%).\n\n'
            'Do you still want to re-open the quiz form?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Again'),
            ),
          ],
        ),
      );
      if (shouldReattempt != true) return;
    } else {
      // Confirmation dialog with explicit email instruction
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.quiz, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Attempt Quiz')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quiz.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          'Important for score sync:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please ensure you submit the Google Form using your registered student email:',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      studentEmail,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open Form'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Launch external browser
    await _launchUrl(quiz.link);

    // Record quiz attempt in SQLite
    if (quiz.id != null && studentEmail.isNotEmpty) {
      await DatabaseHelper.instance.recordQuizAttempt(
        quizId: quiz.id!,
        studentEmail: studentEmail,
        studentName: studentName,
      );
      await _loadData();
    }
  }

  /// Syncs the quiz result from Google Sheets via Google Apps Script Web App
  Future<void> _syncResult(QuizItem quiz) async {
    final quizId = quiz.id;
    if (quizId == null) return;

    final student = MockData.currentStudent;
    final studentEmail = student?.email ?? '';
    final studentName = student?.name ?? 'Student';

    if (studentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot sync: Student email is missing.')),
      );
      return;
    }

    final syncUrl = quiz.syncUrl?.trim() ?? '';
    if (syncUrl.isEmpty) {
      _showMissingSyncUrlDialog(quiz);
      return;
    }

    setState(() => _syncingQuizIds.add(quizId));

    try {
      final response = await _syncService.fetchScore(
        syncUrl: syncUrl,
        studentEmail: studentEmail,
        quizId: quizId,
      );

      if (!mounted) return;

      if (response.isSuccess && response.found) {
        // Record successfully synchronized result in SQLite
        final syncedResult = await DatabaseHelper.instance.recordQuizSyncResult(
          quizId: quizId,
          studentEmail: studentEmail,
          studentName: studentName,
          score: response.score!,
          totalMarks: response.totalMarks!,
          notes: response.message,
        );

        setState(() {
          _resultsMap[quizId] = syncedResult;
          _syncingQuizIds.remove(quizId);
        });

        _showScoreSuccessDialog(quiz, syncedResult);
      } else if (response.isSuccess && !response.found) {
        setState(() => _syncingQuizIds.remove(quizId));
        _showScoreNotFoundDialog(quiz, studentEmail, response.message);
      } else {
        setState(() => _syncingQuizIds.remove(quizId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Sync Error: ${response.message}'),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _syncResult(quiz),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncingQuizIds.remove(quizId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Unexpected error during sync: $e'),
          ),
        );
      }
    }
  }

  void _showScoreSuccessDialog(QuizItem quiz, QuizResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
        title: const Text('Result Synchronized!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quiz.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Text('Your Score', style: TextStyle(color: Colors.green, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '${result.score?.toStringAsFixed(result.score! % 1 == 0 ? 0 : 1)} / ${result.totalMarks?.toStringAsFixed(result.totalMarks! % 1 == 0 ? 0 : 1)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Result saved to your Study Planner database.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showScoreNotFoundDialog(QuizItem quiz, String studentEmail, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 48),
        title: const Text('Result Not Found Yet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No submitted response found in Google Sheets for:',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Text(
              studentEmail,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Possible reasons:\n'
              '• You haven\'t clicked "Submit" on the Google Form yet.\n'
              '• The form was submitted using a different email.\n'
              '• Google Sheets is still updating (wait 5-10 seconds).\n',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncResult(quiz);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showMissingSyncUrlDialog(QuizItem quiz) {
    final controller = TextEditingController(text: quiz.syncUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_off, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Google Apps Script URL Needed')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What is this URL?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'When you link a Google Form to a Google Sheet, you deploy a small Google Apps Script (from Extensions > Apps Script in the Sheet) as a Web App.\n\n'
                'Google gives you a URL that looks like:\n'
                'https://script.google.com/macros/s/AKfycb.../exec\n\n'
                'That URL acts as the API bridge so Flutter can fetch the student\'s score from the spreadsheet.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Apps Script Web App URL',
                  hintText: 'https://script.google.com/macros/s/.../exec',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Testing or presenting? You can also simulate a test score right now without setting up Google Sheets.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text('Simulate Test Score'),
            onPressed: () async {
              Navigator.pop(ctx);
              final student = MockData.currentStudent;
              final studentEmail = student?.email ?? 'student@example.com';
              final studentName = student?.name ?? 'Student';
              final totalMarks = quiz.totalMarks ?? 10.0;
              final sampleScore = (totalMarks * 0.8).roundToDouble(); // 80%

              final syncedResult = await DatabaseHelper.instance.recordQuizSyncResult(
                quizId: quiz.id!,
                studentEmail: studentEmail,
                studentName: studentName,
                score: sampleScore,
                totalMarks: totalMarks,
                notes: 'Simulated test score for demonstration',
              );

              setState(() {
                _resultsMap[quiz.id!] = syncedResult;
              });
              _showScoreSuccessDialog(quiz, syncedResult);
            },
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                Navigator.pop(ctx);
                final updatedQuiz = QuizItem(
                  id: quiz.id,
                  title: quiz.title,
                  link: quiz.link,
                  subjectId: quiz.subjectId,
                  semester: quiz.semester,
                  chapter: quiz.chapter,
                  syncUrl: newUrl,
                  totalMarks: quiz.totalMarks,
                );
                await DatabaseHelper.instance.insertQuiz(updatedQuiz);
                await _loadData();
                _syncResult(updatedQuiz);
              }
            },
            child: const Text('Save & Sync'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Quizzes',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myQuizzes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No quizzes available for ${MockData.currentStudentSemester}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myQuizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = _myQuizzes[index];
                      final quizId = quiz.id ?? -1;
                      final result = _resultsMap[quizId];
                      final isSyncing = _syncingQuizIds.contains(quizId);

                      final subjectName = _subjects
                          .firstWhere(
                            (s) => s.id == quiz.subjectId,
                            orElse: () => Subject(
                              id: '',
                              name: 'Unknown Subject',
                              credits: 0,
                              semester: '',
                            ),
                          )
                          .name;

                      return _buildQuizCard(
                        quiz: quiz,
                        subjectName: subjectName,
                        result: result,
                        isSyncing: isSyncing,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildQuizCard({
    required QuizItem quiz,
    required String subjectName,
    required QuizResult? result,
    required bool isSyncing,
  }) {
    // 3 Distinct Statuses:
    // 1. Not attempted: result == null
    // 2. Attempted (pending sync): result != null && !result.isSynced
    // 3. Synchronized: result != null && result.isSynced
    final bool isSynced = result?.isSynced == true;
    final bool isAttemptedPending = result != null && !isSynced;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isSynced) {
      statusColor = Colors.green.shade700;
      final scoreStr = result!.score! % 1 == 0
          ? result.score!.toInt().toString()
          : result.score!.toStringAsFixed(1);
      final totalStr = result.totalMarks != null
          ? (result.totalMarks! % 1 == 0
              ? result.totalMarks!.toInt().toString()
              : result.totalMarks!.toStringAsFixed(1))
          : '10';
      statusLabel = 'Score: $scoreStr / $totalStr (${result.percentage.toStringAsFixed(1)}%)';
      statusIcon = Icons.check_circle_rounded;
    } else if (isAttemptedPending) {
      statusColor = Colors.orange.shade800;
      statusLabel = 'Attempted • Result Pending';
      statusIcon = Icons.pending_actions_rounded;
    } else {
      statusColor = Colors.grey.shade600;
      statusLabel = 'Not Attempted';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSynced
              ? Colors.green.shade300
              : (isAttemptedPending ? Colors.orange.shade300 : Colors.grey.shade200),
          width: isSynced || isAttemptedPending ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Subject & Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$subjectName • ${quiz.chapter}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quiz Title
            Text(
              quiz.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Form Link / Info
            Row(
              children: [
                Icon(Icons.link, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    quiz.link,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (result?.synchronizedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Synchronized at: ${_formatDate(result!.synchronizedAt!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ] else if (result?.attemptedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Attempted at: ${_formatDate(result!.attemptedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Bottom Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // "Attempt" or "Re-open" button
                OutlinedButton.icon(
                  onPressed: () => _attemptQuiz(quiz),
                  icon: Icon(
                    isSynced ? Icons.visibility : Icons.open_in_browser,
                    size: 16,
                  ),
                  label: Text(isSynced ? 'View Form' : (isAttemptedPending ? 'Re-attempt' : 'Attempt')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 10),

                // "Sync Score" button
                ElevatedButton.icon(
                  onPressed: isSyncing ? null : () => _syncResult(quiz),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isSynced ? Icons.refresh : Icons.sync,
                          size: 16,
                        ),
                  label: Text(
                    isSyncing
                        ? 'Syncing...'
                        : (isSynced ? 'Re-sync' : 'Sync Result'),
                  ),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isSynced
                        ? Colors.green.shade600
                        : (isAttemptedPending ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

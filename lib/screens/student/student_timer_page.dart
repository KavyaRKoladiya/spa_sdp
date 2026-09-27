import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';

class StudentTimerPage extends StatefulWidget {
  const StudentTimerPage({super.key});

  @override
  State<StudentTimerPage> createState() => _StudentTimerPageState();
}

class _StudentTimerPageState extends State<StudentTimerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Subjects & Selection
  List<Subject> _subjects = [];
  String? _selectedSubjectId;
  String _selectedSubjectName = 'General Study';
  final TextEditingController _notesController = TextEditingController();

  // Timer State
  Timer? _timer;
  int _seconds = 0; // Elapsed seconds (Stopwatch) or remaining (Countdown)
  int _initialCountdownSeconds = 25 * 60; // 25 mins default for Pomodoro
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCountdown = false; // false = Stopwatch (count up), true = Countdown (Pomodoro)

  // Student Info
  late String _studentEmail;
  late String _studentName;
  late String _studentSemester;
  bool _filterByCurrentSemester = true;

  // History Data
  List<StudySession> _history = [];
  bool _isLoadingHistory = true;
  String _filterSubject = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final currentStudent = MockData.currentStudent;
    _studentEmail = currentStudent?.email ?? 'student@studyplanner.com';
    _studentName = currentStudent?.name.isNotEmpty == true
        ? currentStudent!.name
        : 'Student';
    _studentSemester = currentStudent?.semester.isNotEmpty == true
        ? currentStudent!.semester
        : MockData.currentStudentSemester;

    _loadSubjects();
    _loadHistory();
  }


  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final List<Subject> subjects;
    if (_filterByCurrentSemester) {
      subjects =
          await DatabaseHelper.instance.getSubjectsBySemester(_studentSemester);
    } else {
      subjects = await DatabaseHelper.instance.getSubjects();
    }
    if (!mounted) return;
    setState(() {
      _subjects = subjects;

      if (_subjects.isNotEmpty) {
        if (!_subjects.any((s) => s.name == _selectedSubjectName)) {
          _selectedSubjectId = _subjects.first.id;
          _selectedSubjectName = _subjects.first.name;
        }
      } else {
        _selectedSubjectId = null;
        _selectedSubjectName = 'General Study';
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final sessions =
        await DatabaseHelper.instance.getStudySessionsByStudent(_studentEmail);
    if (mounted) {
      setState(() {
        _history = sessions;
        _isLoadingHistory = false;
      });
    }
  }

  // --- Timer Actions ---
  void _startTimer() {
    if (_selectedSubjectName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a subject first.')),
      );
      return;
    }

    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
      if (_isCountdown && _seconds == 0) {
        _seconds = _initialCountdownSeconds;
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCountdown) {
        if (_seconds > 0) {
          setState(() => _seconds--);
        } else {
          _timer?.cancel();
          setState(() {
            _isRunning = false;
            _isPaused = false;
          });
          _onCountdownCompleted();
        }
      } else {
        setState(() => _seconds++);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _resetTimer() {
    if (_seconds > 10 || _isRunning) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset Timer?'),
          content: const Text(
              'Are you sure you want to reset? Any unsaved study time in this session will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _forceResetTimer();
              },
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _forceResetTimer();
    }
  }

  void _forceResetTimer() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _isRunning = false;
      _isPaused = false;
      _seconds = _isCountdown ? _initialCountdownSeconds : 0;
    });
  }

  void _onCountdownCompleted() {
    _showSaveSessionDialog(
      durationSeconds: _initialCountdownSeconds,
      title: 'Focus Goal Completed! 🎉',
      message: 'Awesome focus! You completed your $_selectedSubjectName study session.',
    );
  }

  Future<void> _finishAndSaveSession() {
    final int sessionDuration = _isCountdown
        ? (_initialCountdownSeconds - _seconds)
        : _seconds;

    if (sessionDuration < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Study for at least a few seconds before saving.'),
          duration: Duration(seconds: 2),
        ),
      );
      return Future.value();
    }

    return _showSaveSessionDialog(
      durationSeconds: sessionDuration,
      title: 'Finish & Save Session 💾',
      message: 'Great job, $_studentName! Ready to record this study session?',
    );
  }

  Future<void> _showSaveSessionDialog({
    required int durationSeconds,
    required String title,
    required String message,
  }) async {
    _pauseTimer();
    final noteCtrl = TextEditingController(text: _notesController.text);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.secondary, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subject:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Flexible(
                          child: Text(
                            _selectedSubjectName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Time Studied:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _formatDurationDetailed(durationSeconds),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Session Notes / Topics Covered (optional)',
                  hintText: 'e.g. Chapter 3 practice problems, lab work...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // resume timer if it was running
              if (_isPaused) {
                _resumeTimer();
              }
            },
            child: const Text('Keep Studying'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.save),
            label: const Text('Save to History'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveSessionToDatabase(durationSeconds, noteCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveSessionToDatabase(int durationSeconds, String notes) async {
    final newSession = StudySession(
      studentEmail: _studentEmail,
      studentName: _studentName,
      subjectName: _selectedSubjectName,
      subjectId: _selectedSubjectId,
      durationSeconds: durationSeconds,
      date: DateTime.now(),
      notes: notes.isNotEmpty ? notes : null,
    );

    try {
      await DatabaseHelper.instance.insertStudySession(newSession);

      _forceResetTimer();
      _notesController.clear();

      await _loadHistory();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session Saved! 🎉',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recorded ${_formatDurationDetailed(durationSeconds)} for $_selectedSubjectName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _tabController.animateTo(1);
                        },
                        child: const Text('View History'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save session: $e')),
        );
      }
    }
  }

  void _promptCustomSubjectDialog() {
    final customController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Custom Subject / Topic'),
        content: TextField(
          controller: customController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Subject / Topic Name',
            hintText: 'e.g. Competitive Programming, GRE Prep, Calculus',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = customController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _selectedSubjectId = null;
                  _selectedSubjectName = text;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  // --- Helper Formatters ---
  String _formatDigitalTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  String _formatDurationDetailed(int totalSeconds) {
    if (totalSeconds < 60) {
      return '$totalSeconds sec${totalSeconds == 1 ? '' : 's'}';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours hr${hours == 1 ? '' : 's'} ${minutes > 0 ? '$minutes min ' : ''}${seconds > 0 ? '$seconds sec' : ''}'.trim();
    }
    return '$minutes min${minutes == 1 ? '' : 's'} ${seconds > 0 ? '$seconds sec' : ''}'.trim();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return 'Today, $hour:$minute $ampm';
    }
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  // --- Calculations for Statistics ---
  int get _totalSecondsAllTime =>
      _history.fold(0, (sum, s) => sum + s.durationSeconds);

  int get _totalSecondsToday {
    final now = DateTime.now();
    return _history
        .where((s) =>
            s.date.year == now.year &&
            s.date.month == now.month &&
            s.date.day == now.day)
        .fold(0, (sum, s) => sum + s.durationSeconds);
  }

  String get _topSubject {
    if (_history.isEmpty) return 'None';
    final Map<String, int> subjectCounts = {};
    for (var s in _history) {
      subjectCounts[s.subjectName] =
          (subjectCounts[s.subjectName] ?? 0) + s.durationSeconds;
    }
    var best = subjectCounts.entries.first;
    for (var entry in subjectCounts.entries) {
      if (entry.value > best.value) {
        best = entry;
      }
    }
    return best.key;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Study Timer & Tracker'),
        backgroundColor: colorScheme.secondary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(icon: Icon(Icons.timer_outlined), text: 'Timer'),
            Tab(icon: Icon(Icons.history_rounded), text: 'History & Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimerTab(colorScheme),
          _buildHistoryTab(colorScheme),
        ],
      ),
    ),
  );
  }

  // =========================================================================
  // TIMER TAB
  // =========================================================================
  Widget _buildTimerTab(ColorScheme colorScheme) {
    // Calculate circular indicator progress
    double progress = 0.0;
    if (_isCountdown) {
      progress = _initialCountdownSeconds > 0
          ? (_seconds / _initialCountdownSeconds).clamp(0.0, 1.0)
          : 0.0;
    } else {
      // Stopwatch: cyclical 60-second progress ring
      progress = (_seconds % 60) / 60.0;
      if (_seconds > 0 && progress == 0.0) progress = 1.0;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Segmented Button (Stopwatch vs Countdown Pomodoro)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Stopwatch (Count Up)'),
                    icon: Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Focus (Countdown)'),
                    icon: Icon(Icons.hourglass_bottom_rounded),
                  ),
                ],
                selected: {_isCountdown},
                onSelectionChanged: _isRunning
                    ? null
                    : (newSelection) {
                        setState(() {
                          _isCountdown = newSelection.first;
                          _seconds = _isCountdown ? _initialCountdownSeconds : 0;
                          _isPaused = false;
                        });
                      },
              ),
              const SizedBox(height: 20),

              // Subject Selection Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_rounded,
                                    color: colorScheme.secondary, size: 22),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _filterByCurrentSemester
                                        ? '$_studentSemester Subjects'
                                        : 'All Subjects',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _isRunning
                                    ? null
                                    : () {
                                        setState(() {
                                          _filterByCurrentSemester =
                                              !_filterByCurrentSemester;
                                        });
                                        _loadSubjects();
                                      },
                                icon: Icon(
                                  _filterByCurrentSemester
                                      ? Icons.filter_alt
                                      : Icons.filter_alt_off_outlined,
                                  size: 16,
                                ),
                                label: Text(_filterByCurrentSemester
                                    ? 'Show All'
                                    : 'Only $_studentSemester'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _isRunning ? null : _promptCustomSubjectDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Custom'),
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.secondary,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Dropdown for Subjects
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedSubjectName),
                        isExpanded: true,
                        initialValue: _subjects.any((s) => s.name == _selectedSubjectName)
                            ? _selectedSubjectName
                            : null,
                        hint: Text(
                          _selectedSubjectName.isNotEmpty
                              ? _selectedSubjectName
                              : 'Select or enter subject',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: [
                          ..._subjects.map((sub) {
                            return DropdownMenuItem<String>(
                              value: sub.name,
                              child: Text(
                                '${sub.name} (${sub.id.isNotEmpty ? sub.id : sub.semester})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: _isRunning
                            ? null
                            : (val) {
                                if (val != null) {
                                  final match = _subjects
                                      .firstWhere((s) => s.name == val, orElse: () => _subjects.first);
                                  setState(() {
                                    _selectedSubjectId = match.id;
                                    _selectedSubjectName = match.name;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      // Optional Notes / Topic Field
                      TextField(
                        controller: _notesController,
                        enabled: true,
                        decoration: InputDecoration(
                          hintText: 'Notes / Topic (e.g. Chapter 4 problem set)...',
                          prefixIcon: const Icon(Icons.notes, size: 20),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pomodoro Preset Chips (if in Countdown mode)
              if (_isCountdown) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildPresetChip('15 min', 15 * 60),
                    _buildPresetChip('25 min (Pomodoro)', 25 * 60),
                    _buildPresetChip('45 min', 45 * 60),
                    _buildPresetChip('60 min', 60 * 60),
                    ActionChip(
                      avatar: const Icon(Icons.edit, size: 16),
                      label: const Text('Custom Min'),
                      onPressed: _isRunning ? null : _promptCustomMinutesDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Modern Circular Timer Display Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        colorScheme.secondary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Active Subject Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories, size: 18, color: colorScheme.secondary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedSubjectName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Large Circular Progress Ring with Digital Time inside
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background track ring
                            SizedBox(
                              width: 230,
                              height: 230,
                              child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade200,
                                ),
                              ),
                            ),
                            // Dynamic progress ring
                            SizedBox(
                              width: 230,
                              height: 230,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                strokeCap: StrokeCap.round,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isRunning
                                      ? colorScheme.secondary
                                      : (_isPaused ? Colors.amber : Colors.grey.shade400),
                                ),
                              ),
                            ),
                            // Inside Timer Information
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Status chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isRunning
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : (_isPaused
                                            ? Colors.amber.withValues(alpha: 0.2)
                                            : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isRunning
                                              ? Colors.green
                                              : (_isPaused
                                                  ? Colors.amber.shade800
                                                  : Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isRunning
                                            ? 'Studying...'
                                            : (_isPaused ? 'Paused' : 'Ready'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _isRunning
                                              ? Colors.green.shade800
                                              : (_isPaused
                                                  ? Colors.amber.shade900
                                                  : Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Digital Clock text
                                Text(
                                  _formatDigitalTime(_seconds),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isCountdown ? 'Remaining Time' : 'Elapsed Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Timer Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          // Start / Resume Button
                          if (!_isRunning && !_isPaused) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: const Text(
                                'Start Studying',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _startTimer,
                            ),
                          ],

                          // Pause Button
                          if (_isRunning) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.pause_rounded, size: 24),
                              label: const Text('Pause',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: _pauseTimer,
                            ),
                          ],

                          // Resume Button
                          if (_isPaused) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 24),
                              label: const Text('Resume',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: _resumeTimer,
                            ),
                          ],

                          // Finish & Save Session Button (Active when running or paused)
                          if (_isRunning || _isPaused || (_seconds > 0 && !_isCountdown)) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 24),
                              label: const Text('Finish & Save',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: _finishAndSaveSession,
                            ),
                          ],

                          // Reset Button
                          if (_seconds > 0 || _isRunning || _isPaused) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 22),
                              label: const Text('Reset',
                                  style: TextStyle(fontSize: 15)),
                              onPressed: _resetTimer,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int seconds) {
    final isSelected = _initialCountdownSeconds == seconds;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25),
      onSelected: _isRunning
          ? null
          : (selected) {
              if (selected) {
                setState(() {
                  _initialCountdownSeconds = seconds;
                  _seconds = seconds;
                });
              }
            },
    );
  }

  void _promptCustomMinutesDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Custom Focus Minutes'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Minutes (1 - 180)',
            suffixText: 'mins',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(ctrl.text.trim());
              if (mins != null && mins > 0 && mins <= 180) {
                setState(() {
                  _initialCountdownSeconds = mins * 60;
                  _seconds = _initialCountdownSeconds;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HISTORY & STATS TAB
  // =========================================================================
  Widget _buildHistoryTab(ColorScheme colorScheme) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtered History
    final displayedList = _filterSubject == 'All'
        ? _history
        : _history.where((s) => s.subjectName == _filterSubject).toList();

    // Unique subjects for filter chips
    final subjectSet = <String>{'All'};
    for (var s in _history) {
      subjectSet.add(s.subjectName);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // Header title with Student Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_studentName\'s Study Record',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Logged in as $_studentEmail',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh History',
                    onPressed: _loadHistory,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Overview Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.access_time_filled_rounded,
                      iconColor: Colors.blue.shade600,
                      label: 'Total Studied',
                      value: _formatDurationDetailed(_totalSecondsAllTime),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.today_rounded,
                      iconColor: Colors.teal.shade600,
                      label: 'Studied Today',
                      value: _formatDurationDetailed(_totalSecondsToday),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.task_alt_rounded,
                      iconColor: Colors.orange.shade700,
                      label: 'Sessions',
                      value: '${_history.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.star_rounded,
                      iconColor: Colors.purple.shade600,
                      label: 'Top Subject',
                      value: _topSubject,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Subject Filter Chips
              if (_history.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 20),
                    const SizedBox(width: 6),
                    const Text('Filter by Subject:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: subjectSet.map((subj) {
                      final isSelected = _filterSubject == subj;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(subj),
                          selected: isSelected,
                          selectedColor: colorScheme.secondary.withValues(alpha: 0.25),
                          onSelected: (val) {
                            setState(() => _filterSubject = subj);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Session List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Study Sessions (${displayedList.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sessions List or Empty State
              if (displayedList.isEmpty) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 24),
                    child: Column(
                      children: [
                        Icon(Icons.hourglass_empty_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No Study Sessions Recorded',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _history.isEmpty
                              ? 'You have not timed any study sessions yet.\nJump into the Timer tab to start your first session!'
                              : 'No sessions found for subject "$_filterSubject".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.timer),
                          label: const Text('Go to Study Timer'),
                          onPressed: () => _tabController.animateTo(0),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...displayedList.map((session) => _buildSessionCard(session, colorScheme)),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(StudySession session, ColorScheme colorScheme) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Subject Icon
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.secondary.withValues(alpha: 0.18),
              child: Icon(Icons.menu_book_rounded,
                  color: colorScheme.secondary, size: 22),
            ),
            const SizedBox(width: 14),

            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          session.subjectName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Duration Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          _formatDurationDetailed(session.durationSeconds),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(session.date),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (session.notes != null && session.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.notes!,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Delete action
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 20),
              tooltip: 'Delete session',
              onPressed: () => _confirmDeleteSession(session),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSession(StudySession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
            'Delete session for ${session.subjectName} (${_formatDurationDetailed(session.durationSeconds)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (session.id != null) {
                await DatabaseHelper.instance.deleteStudySession(session.id!);
                await _loadHistory();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

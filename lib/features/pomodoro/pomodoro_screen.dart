import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // Ayarlar
  int _workMinutes = 25;
  int _breakMinutes = 5;
  bool _isWorking = true;
  bool _isRunning = false;

  // Timer
  Timer? _timer;
  int _secondsLeft = 25 * 60;
  int _completedSessions = 0;
  double _dailyFocusScore = 0;

  // Ders seçimi
  List<Map<String, dynamic>> _subjects = [];
  int? _selectedSubjectId;

  // Analitik
  List<Map<String, dynamic>> _todaySessions = [];

  // Animasyon
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _sessionStart = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    _secondsLeft = _workMinutes * 60;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(_pulseCtrl);
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final subjects = await DatabaseHelper.instance.query('subjects');
    final today = DateTime.now().toIso8601String().split('T')[0];
    final sessions = await DatabaseHelper.instance.query(
      'pomodoro_sessions',
      where: "started_at LIKE ? AND completed = 1",
      whereArgs: ['$today%'],
    );

    double score = 0;
    int totalMin = 0;
    for (final s in sessions) {
      totalMin += s['duration_min'] as int;
    }
    // Focus score: 25dk seans = 10 puan, max 100
    score = (totalMin / 25 * 10).clamp(0, 100);

    setState(() {
      _subjects = subjects;
      _selectedSubjectId = subjects.isNotEmpty ? subjects.first['id'] as int : null;
      _todaySessions = sessions;
      _dailyFocusScore = score;
      _completedSessions = sessions.length;
    });
  }

  void _startTimer() {
    _sessionStart.value = DateTime.now();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWorking = true;
      _secondsLeft = _workMinutes * 60;
    });
    _sessionStart.value = null;
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    if (_isWorking) {
      // Seansı kaydet
      final subjectName = _subjects.firstWhere(
        (s) => s['id'] == _selectedSubjectId,
        orElse: () => {'name': 'Genel'},
      )['name'] as String;

      final focusScore = _calcFocusScore();
      await DatabaseHelper.instance.insert('pomodoro_sessions', {
        'subject_id': _selectedSubjectId,
        'duration_min': _workMinutes,
        'break_min': _breakMinutes,
        'completed': 1,
        'focus_score': focusScore,
        'started_at': (_sessionStart.value ?? DateTime.now()).toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
      });

      // Günlük analitiği güncelle
      final today = DateTime.now().toIso8601String().split('T')[0];
      await DatabaseHelper.instance.rawQuery('''
        INSERT INTO focus_analytics (analytics_date, total_focus_min, sessions_count, focus_score, best_subject, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(analytics_date) DO UPDATE SET
          total_focus_min = total_focus_min + ?,
          sessions_count = sessions_count + 1,
          focus_score = (focus_score + ?) / 2,
          updated_at = ?
      ''', [today, _workMinutes, 1, focusScore, subjectName,
            DateTime.now().toIso8601String(),
            _workMinutes, focusScore, DateTime.now().toIso8601String()]);

      await NotificationService.instance.showPomodoroComplete(subjectName);
      await _loadData();

      // Mola başlat
      setState(() {
        _isWorking = false;
        _secondsLeft = _breakMinutes * 60;
        _completedSessions++;
      });
    } else {
      // Mola bitti
      await NotificationService.instance.showBreakComplete();
      setState(() {
        _isWorking = true;
        _secondsLeft = _workMinutes * 60;
      });
    }
  }

  double _calcFocusScore() {
    // Basit focus score: tam seans = 100, yarım = 50
    return 100.0;
  }

  String get _timeString {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = (_isWorking ? _workMinutes : _breakMinutes) * 60;
    return 1 - (_secondsLeft / total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Pomodoro & Odaklanma',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ders seçici
            if (_subjects.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: _selectedSubjectId,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardColor,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppTheme.white, fontSize: 14),
                  items: _subjects.map((s) => DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(s['name'] as String),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedSubjectId = v),
                ),
              ),

            const SizedBox(height: 32),

            // Ana timer
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _isRunning ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: CircularPercentIndicator(
                radius: 130,
                lineWidth: 12,
                percent: _progress.clamp(0.0, 1.0),
                backgroundColor: AppTheme.cardColor,
                progressColor: _isWorking ? AppTheme.neonGreen : AppTheme.neonBlue,
                circularStrokeCap: CircularStrokeCap.round,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isWorking ? 'ÇALIŞMA' : 'MOLA',
                      style: TextStyle(
                        color: (_isWorking ? AppTheme.neonGreen : AppTheme.neonBlue)
                            .withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeString,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_completedSessions seans tamamlandı',
                      style: TextStyle(
                          color: AppTheme.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset
                _CircleBtn(
                  icon: Icons.refresh,
                  color: AppTheme.textDim,
                  onTap: _resetTimer,
                ),
                const SizedBox(width: 20),
                // Play/Pause
                GestureDetector(
                  onTap: _isRunning ? _pauseTimer : _startTimer,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isWorking
                          ? AppTheme.neonGreen
                          : AppTheme.neonBlue,
                      boxShadow: [
                        BoxShadow(
                          color: (_isWorking
                                  ? AppTheme.neonGreen
                                  : AppTheme.neonBlue)
                              .withOpacity(0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      color: AppTheme.black,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Skip
                _CircleBtn(
                  icon: Icons.skip_next,
                  color: AppTheme.textDim,
                  onTap: _onTimerComplete,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Süre ayarları
            Row(
              children: [
                Expanded(
                  child: _DurationSetting(
                    label: 'Çalışma',
                    value: _workMinutes,
                    color: AppTheme.neonGreen,
                    onChanged: (v) {
                      if (!_isRunning) {
                        setState(() {
                          _workMinutes = v;
                          if (_isWorking) _secondsLeft = v * 60;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DurationSetting(
                    label: 'Mola',
                    value: _breakMinutes,
                    color: AppTheme.neonBlue,
                    onChanged: (v) {
                      if (!_isRunning) {
                        setState(() {
                          _breakMinutes = v;
                          if (!_isWorking) _secondsLeft = v * 60;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Günlük Focus Score
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.neonGreen.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.neonGreen, size: 18),
                      const SizedBox(width: 6),
                      const Text('Günlük Odaklanma Puanı',
                          style: TextStyle(
                              color: AppTheme.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        _dailyFocusScore.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppTheme.neonGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('/100',
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.4),
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _dailyFocusScore / 100,
                    backgroundColor: AppTheme.surfaceColor,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.neonGreen),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_completedSessions} seans  •  '
                    '${_completedSessions * _workMinutes} dk odaklanma',
                    style: TextStyle(
                        color: AppTheme.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardColor,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _DurationSetting extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const _DurationSetting(
      {required this.label, required this.value,
       required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: () { if (value > 1) onChanged(value - 1); },
            child: Icon(Icons.remove, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Text('$value', style: const TextStyle(
              color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { if (value < 60) onChanged(value + 1); },
            child: Icon(Icons.add, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}

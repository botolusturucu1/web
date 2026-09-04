import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

class AbsenceScreen extends StatefulWidget {
  const AbsenceScreen({super.key});
  @override
  State<AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends State<AbsenceScreen> {
  List<Map<String, dynamic>> _subjects = [];
  Map<int, Map<String, int>> _absenceCounts = {};
  Map<int, Map<String, dynamic>> _limits = {};
  bool _loading = true;

  static const int _defaultMaxExcused = 14;
  static const int _defaultMaxUnexcused = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final subjects = await DatabaseHelper.instance.query('subjects');

    final Map<int, Map<String, int>> counts = {};
    final Map<int, Map<String, dynamic>> limits = {};

    for (final s in subjects) {
      final id = s['id'] as int;
      // Devamsızlık sayıları
      final excused = await DatabaseHelper.instance.rawQuery(
        "SELECT COUNT(*) as c FROM absences WHERE subject_id = ? AND type = 'excused'",
        [id],
      );
      final unexcused = await DatabaseHelper.instance.rawQuery(
        "SELECT COUNT(*) as c FROM absences WHERE subject_id = ? AND type = 'unexcused'",
        [id],
      );
      counts[id] = {
        'excused': excused.first['c'] as int,
        'unexcused': unexcused.first['c'] as int,
      };

      // Limit ayarları
      final limitData = await DatabaseHelper.instance.query(
        'absence_limits', where: 'subject_id = ?', whereArgs: [id], limit: 1);
      limits[id] = limitData.isNotEmpty
          ? Map.from(limitData.first)
          : {
              'max_excused': _defaultMaxExcused,
              'max_unexcused': _defaultMaxUnexcused,
              'warn_at_percent': 0.7,
            };
    }

    setState(() {
      _subjects = subjects;
      _absenceCounts = counts;
      _limits = limits;
      _loading = false;
    });

    _checkWarnings();
  }

  Future<void> _checkWarnings() async {
    for (final s in _subjects) {
      final id = s['id'] as int;
      final counts = _absenceCounts[id] ?? {};
      final limit = _limits[id] ?? {};
      final maxUnexcused = limit['max_unexcused'] as int? ?? _defaultMaxUnexcused;
      final unexcused = counts['unexcused'] ?? 0;
      final warnAt = (limit['warn_at_percent'] as num? ?? 0.7).toDouble();

      if (unexcused >= (maxUnexcused * warnAt).round()) {
        await NotificationService.instance.showAbsenceWarning(
          subjectName: s['name'] as String,
          currentAbsences: unexcused,
          maxAbsences: maxUnexcused,
        );
      }
    }
  }

  Future<void> _addAbsence(int subjectId, String type) async {
    await DatabaseHelper.instance.insert('absences', {
      'subject_id': subjectId,
      'absence_date': DateTime.now().toIso8601String().split('T')[0],
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(type == 'excused'
              ? 'Özürlü devamsızlık eklendi' : 'Özürsüz devamsızlık eklendi'),
          backgroundColor: AppTheme.cardColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Devamsızlık Takibi',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subjects.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _buildSummaryChart();
                final s = _subjects[i - 1];
                final id = s['id'] as int;
                return _AbsenceSubjectCard(
                  subject: s,
                  counts: _absenceCounts[id] ?? {},
                  limit: _limits[id] ?? {},
                  onAddExcused: () => _addAbsence(id, 'excused'),
                  onAddUnexcused: () => _addAbsence(id, 'unexcused'),
                );
              },
            ),
    );
  }

  Widget _buildSummaryChart() {
    if (_subjects.isEmpty) return const SizedBox.shrink();

    // Toplam özürsüz devamsızlık bar chart
    final groups = _subjects.asMap().entries.map((e) {
      final id = e.value['id'] as int;
      final counts = _absenceCounts[id] ?? {};
      final unexcused = (counts['unexcused'] ?? 0).toDouble();
      final excused = (counts['excused'] ?? 0).toDouble();
      final limit = _limits[id] ?? {};
      final maxU = (limit['max_unexcused'] as int? ?? _defaultMaxUnexcused).toDouble();
      final danger = unexcused >= maxU * 0.7;

      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: unexcused,
            color: danger ? AppTheme.neonRed : AppTheme.neonOrange,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: excused,
            color: AppTheme.neonBlue.withOpacity(0.6),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: AppTheme.neonOrange, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Özürsüz', style: TextStyle(
                  color: AppTheme.textDim, fontSize: 11)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: AppTheme.neonBlue.withOpacity(0.6),
                      shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Özürlü', style: TextStyle(
                  color: AppTheme.textDim, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: groups,
              groupsSpace: 8,
            )),
          ),
        ],
      ),
    );
  }
}

class _AbsenceSubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final Map<String, int> counts;
  final Map<String, dynamic> limit;
  final VoidCallback onAddExcused;
  final VoidCallback onAddUnexcused;

  const _AbsenceSubjectCard({
    required this.subject, required this.counts,
    required this.limit, required this.onAddExcused, required this.onAddUnexcused,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(
        'FF${(subject['color_hex'] as String).replaceAll('#', '')}', radix: 16));
    final unexcused = counts['unexcused'] ?? 0;
    final excused = counts['excused'] ?? 0;
    final maxUnexcused = limit['max_unexcused'] as int? ?? 10;
    final maxExcused = limit['max_excused'] as int? ?? 14;
    final unexcusedPercent = (unexcused / maxUnexcused).clamp(0.0, 1.0);
    final excusedPercent = (excused / maxExcused).clamp(0.0, 1.0);
    final isDanger = unexcused >= (maxUnexcused * 0.7).round();
    final isCritical = unexcused >= maxUnexcused;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCritical ? AppTheme.neonRed
              : isDanger ? AppTheme.neonOrange.withOpacity(0.5)
              : color.withOpacity(0.2),
          width: isCritical ? 1.5 : 1,
        ),
        boxShadow: isCritical ? [
          BoxShadow(color: AppTheme.neonRed.withOpacity(0.15), blurRadius: 12),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(subject['name'] as String,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (isCritical)
                const Icon(Icons.warning_amber, color: AppTheme.neonRed, size: 18),
              if (isDanger && !isCritical)
                const Icon(Icons.warning_amber_outlined,
                    color: AppTheme.neonOrange, size: 18),
            ],
          ),

          const SizedBox(height: 14),

          // Özürsüz
          _AbsenceBar(
            label: 'Özürsüz',
            count: unexcused,
            max: maxUnexcused,
            percent: unexcusedPercent,
            color: isDanger ? AppTheme.neonRed : AppTheme.neonOrange,
          ),
          const SizedBox(height: 8),
          // Özürlü
          _AbsenceBar(
            label: 'Özürlü',
            count: excused,
            max: maxExcused,
            percent: excusedPercent,
            color: AppTheme.neonBlue,
          ),

          const SizedBox(height: 14),

          // Ekle butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddUnexcused,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.neonOrange.withOpacity(0.5)),
                    foregroundColor: AppTheme.neonOrange,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Özürsüz', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddExcused,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.neonBlue.withOpacity(0.5)),
                    foregroundColor: AppTheme.neonBlue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Özürlü', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbsenceBar extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final double percent;
  final Color color;
  const _AbsenceBar({required this.label, required this.count,
      required this.max, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(
              color: AppTheme.white.withOpacity(0.5), fontSize: 11)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppTheme.surfaceColor,
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(3),
            minHeight: 7,
          ),
        ),
        const SizedBox(width: 8),
        Text('$count/$max', style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

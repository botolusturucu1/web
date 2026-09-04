import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});
  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Map<String, dynamic>> _subjects = [];
  Map<int, List<Map<String, dynamic>>> _gradesBySubject = {};
  bool _loading = true;
  String? _aiReport;
  bool _analyzingAi = false;
  int? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final subjects = await DatabaseHelper.instance.query('subjects', orderBy: 'name ASC');
    final Map<int, List<Map<String, dynamic>>> gradeMap = {};
    for (final s in subjects) {
      final grades = await DatabaseHelper.instance.query(
        'grades',
        where: 'subject_id = ?',
        whereArgs: [s['id']],
        orderBy: 'exam_date ASC',
      );
      gradeMap[s['id'] as int] = grades;
    }
    setState(() {
      _subjects = subjects;
      _gradesBySubject = gradeMap;
      _loading = false;
      if (_subjects.isNotEmpty) _selectedSubjectId ??= _subjects.first['id'] as int;
    });
  }

  double _average(int subjectId) {
    final grades = _gradesBySubject[subjectId] ?? [];
    if (grades.isEmpty) return 0;
    double total = 0, weightSum = 0;
    for (final g in grades) {
      final w = (g['weight'] as num).toDouble();
      total += (g['score'] as num).toDouble() * w;
      weightSum += w;
    }
    return weightSum > 0 ? total / weightSum : 0;
  }

  Future<void> _addGrade(int subjectId) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddGradeSheet(subjectId: subjectId),
    );
    if (result != null) {
      await DatabaseHelper.instance.insert('grades', result);
      await _loadData();
    }
  }

  Future<void> _analyzeTarget(int subjectId) async {
    final subject = _subjects.firstWhere((s) => s['id'] == subjectId);
    final avg = _average(subjectId);
    final grades = _gradesBySubject[subjectId] ?? [];
    setState(() => _analyzingAi = true);
    try {
      final result = await AiService.instance.analyzeGradeTarget(
        subject: subject['name'] as String,
        currentAverage: avg,
        targetAverage: 85.0,
        remainingExams: 2,
      );
      setState(() {
        _aiReport = '${result['message']}\n\n💡 ${result['tip']}';
        if (result['needed_score'] != null) {
          _aiReport = '📊 Gereken not: ${result['needed_score']}\n\n${_aiReport}';
        }
      });
    } on AiException catch (e) {
      setState(() => _aiReport = e.message);
    } finally {
      setState(() => _analyzingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Not Ortalaması & Hedef',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ders seçici
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _subjects.length,
                    itemBuilder: (_, i) {
                      final s = _subjects[i];
                      final id = s['id'] as int;
                      final selected = _selectedSubjectId == id;
                      final color = _hexColor(s['color_hex'] as String);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSubjectId = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? color : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(selected ? 1 : 0.3)),
                          ),
                          child: Text(
                            s['name'] as String,
                            style: TextStyle(
                              color: selected ? AppTheme.black : AppTheme.white,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                if (_selectedSubjectId != null) ...[
                  _buildSubjectDetail(_selectedSubjectId!),
                ],

                // AI Analiz raporu
                if (_aiReport != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.neonBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.neonBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppTheme.neonBlue, size: 16),
                            SizedBox(width: 6),
                            Text('AI Hedef Analizi',
                                style: TextStyle(color: AppTheme.neonBlue,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_aiReport!,
                            style: TextStyle(
                                color: AppTheme.white.withOpacity(0.85),
                                fontSize: 13,
                                height: 1.6)),
                      ],
                    ),
                  ),
                ],

                // Genel not özeti
                const SizedBox(height: 24),
                const Text('Tüm Dersler',
                    style: TextStyle(color: AppTheme.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._subjects.map((s) {
                  final id = s['id'] as int;
                  final avg = _average(id);
                  final color = _hexColor(s['color_hex'] as String);
                  return _SubjectSummaryRow(
                    name: s['name'] as String,
                    average: avg,
                    gradeCount: (_gradesBySubject[id] ?? []).length,
                    color: color,
                    onAdd: () => _addGrade(id),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildSubjectDetail(int subjectId) {
    final subject = _subjects.firstWhere((s) => s['id'] == subjectId);
    final grades = _gradesBySubject[subjectId] ?? [];
    final avg = _average(subjectId);
    final color = _hexColor(subject['color_hex'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ortalama kartı
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject['name'] as String,
                        style: TextStyle(color: color,
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${grades.length} sınav girildi',
                        style: TextStyle(
                            color: AppTheme.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                      color: avg >= 85 ? AppTheme.neonGreen
                          : avg >= 70 ? AppTheme.neonOrange
                          : AppTheme.neonRed,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('ortalama',
                      style: TextStyle(
                          color: AppTheme.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Grafik (notlar varsa)
        if (grades.length >= 2) ...[
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: grades.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(),
                            (e.value['score'] as num).toDouble())).toList(),
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.08),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Not listesi + Ekle butonu
        Row(
          children: [
            const Text('Sınavlar', style: TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () => _addGrade(subjectId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, color: color, size: 14),
                    const SizedBox(width: 4),
                    Text('Not Ekle', style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...grades.map((g) => _GradeRow(grade: g, color: color)),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _analyzingAi ? null : () => _analyzeTarget(subjectId),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.neonBlue.withOpacity(0.5)),
              foregroundColor: AppTheme.neonBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _analyzingAi
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonBlue))
                : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI Hedef Analizi Yap'),
          ),
        ),
      ],
    );
  }

  Color _hexColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

class _GradeRow extends StatelessWidget {
  final Map<String, dynamic> grade;
  final Color color;
  const _GradeRow({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    final score = (grade['score'] as num).toDouble();
    final max = (grade['max_score'] as num? ?? 100).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(grade['exam_name'] as String,
              style: const TextStyle(color: AppTheme.white, fontSize: 13))),
          Text(grade['exam_date'] as String,
              style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 11)),
          const SizedBox(width: 12),
          Text('${score.toStringAsFixed(0)}/$max',
              style: TextStyle(
                color: score >= 85 ? AppTheme.neonGreen
                    : score >= 60 ? AppTheme.neonOrange : AppTheme.neonRed,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
        ],
      ),
    );
  }
}

class _SubjectSummaryRow extends StatelessWidget {
  final String name;
  final double average;
  final int gradeCount;
  final Color color;
  final VoidCallback onAdd;

  const _SubjectSummaryRow({
    required this.name, required this.average,
    required this.gradeCount, required this.color, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppTheme.white, fontSize: 14)),
                Text('$gradeCount sınav',
                    style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          Text(
            gradeCount > 0 ? average.toStringAsFixed(1) : '—',
            style: TextStyle(
              color: average >= 85 ? AppTheme.neonGreen
                  : average >= 60 ? AppTheme.neonOrange : AppTheme.neonRed,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onAdd,
            child: Icon(Icons.add_circle_outline, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

class _AddGradeSheet extends StatefulWidget {
  final int subjectId;
  const _AddGradeSheet({required this.subjectId});
  @override
  State<_AddGradeSheet> createState() => _AddGradeSheetState();
}

class _AddGradeSheetState extends State<_AddGradeSheet> {
  final _nameCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Not Ekle', style: TextStyle(
              color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(
              labelText: 'Sınav Adı (örn. 1. Yazılı)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scoreCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(labelText: 'Not (0-100)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final score = double.tryParse(_scoreCtrl.text);
                if (_nameCtrl.text.isEmpty || score == null) return;
                Navigator.pop(context, {
                  'subject_id': widget.subjectId,
                  'exam_name': _nameCtrl.text.trim(),
                  'score': score,
                  'max_score': 100.0,
                  'exam_date': _date.toIso8601String().split('T')[0],
                  'weight': 1.0,
                  'created_at': DateTime.now().toIso8601String(),
                });
              },
              child: const Text('Kaydet'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

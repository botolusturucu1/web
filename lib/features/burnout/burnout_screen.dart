import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

class BurnoutScreen extends StatefulWidget {
  const BurnoutScreen({super.key});
  @override
  State<BurnoutScreen> createState() => _BurnoutScreenState();
}

class _BurnoutScreenState extends State<BurnoutScreen> {
  // Anket değerleri
  int _energy = 5;
  int _stress = 5;
  int _motivation = 5;
  int _sleep = 5;

  bool _analyzing = false;
  Map<String, dynamic>? _lastAnalysis;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final history = await DatabaseHelper.instance.query(
      'burnout_surveys',
      orderBy: 'survey_date DESC',
      limit: 8,
    );
    setState(() {
      _history = history;
      _loading = false;
      if (history.isNotEmpty && history.first['ai_analysis'] != null) {
        _lastAnalysis = {
          'analysis': history.first['ai_analysis'],
          'burnout_risk': _extractRisk(history.first['ai_analysis'] as String),
          'recommendations': history.first['recommendation'],
        };
      }
    });
  }

  String _extractRisk(String analysis) {
    if (analysis.contains('Yüksek')) return 'Yüksek';
    if (analysis.contains('Orta')) return 'Orta';
    return 'Düşük';
  }

  Future<void> _runAnalysis() async {
    setState(() => _analyzing = true);
    try {
      final result = await AiService.instance.analyzeBurnout(
        energyLevel: _energy,
        stressLevel: _stress,
        motivation: _motivation,
        sleepQuality: _sleep,
      );

      final recommendations = (result['recommendations'] as List?)
          ?.map((e) => e.toString())
          .join('\n• ') ?? '';

      // DB'ye kaydet
      await DatabaseHelper.instance.insert('burnout_surveys', {
        'energy_level': _energy,
        'stress_level': _stress,
        'motivation': _motivation,
        'sleep_quality': _sleep,
        'ai_analysis': '${result['burnout_risk']} risk  |  '
            '${result['analysis']}',
        'recommendation': '• $recommendations',
        'survey_date': DateTime.now().toIso8601String().split('T')[0],
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() => _lastAnalysis = result);

      // Yüksek risk bildirimi
      if (result['burnout_risk'] == 'Yüksek') {
        await NotificationService.instance.showBurnoutAlert(
          result['urgent_action'] as String? ??
              'Tükenmişlik riski yüksek! Lütfen dinlen.',
        );
      }

      await _loadHistory();
    } on AiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)));
      }
    } finally {
      setState(() => _analyzing = false);
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'Yüksek': return AppTheme.neonRed;
      case 'Orta':   return AppTheme.neonOrange;
      default:       return AppTheme.neonGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Stres & Tükenmişlik Monitörü',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum özeti
                  if (_lastAnalysis != null) _buildRiskBadge(),

                  const SizedBox(height: 20),

                  // Anket başlık
                  const Text('Haftalık Durum Kontrolü',
                      style: TextStyle(color: AppTheme.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Bu haftaki durumunu dürüstçe değerlendir.',
                    style: TextStyle(
                        color: AppTheme.white.withOpacity(0.4), fontSize: 13),
                  ),

                  const SizedBox(height: 24),

                  // Sliderlar
                  _MoodSlider(
                    label: '⚡ Enerji Seviyesi',
                    value: _energy,
                    lowLabel: 'Bitkin',
                    highLabel: 'Enerjik',
                    color: AppTheme.neonGreen,
                    onChanged: (v) => setState(() => _energy = v),
                  ),
                  _MoodSlider(
                    label: '🔥 Stres Seviyesi',
                    value: _stress,
                    lowLabel: 'Rahat',
                    highLabel: 'Çok Stresli',
                    color: AppTheme.neonRed,
                    onChanged: (v) => setState(() => _stress = v),
                  ),
                  _MoodSlider(
                    label: '🎯 Motivasyon',
                    value: _motivation,
                    lowLabel: 'Sıfır',
                    highLabel: 'Yüksek',
                    color: AppTheme.neonBlue,
                    onChanged: (v) => setState(() => _motivation = v),
                  ),
                  _MoodSlider(
                    label: '😴 Uyku Kalitesi',
                    value: _sleep,
                    lowLabel: 'Kötü',
                    highLabel: 'Harika',
                    color: AppTheme.neonPurple,
                    onChanged: (v) => setState(() => _sleep = v),
                  ),

                  const SizedBox(height: 28),

                  // Analiz butonu
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _analyzing ? null : _runAnalysis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonPurple,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _analyzing
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: AppTheme.white, strokeWidth: 2))
                          : const Icon(Icons.psychology, size: 20),
                      label: const Text('AI ile Analiz Et',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // AI Sonuç
                  if (_lastAnalysis != null) ...[
                    const SizedBox(height: 24),
                    _buildAnalysisResult(),
                  ],

                  // Geçmiş grafiği
                  if (_history.length >= 2) ...[
                    const SizedBox(height: 28),
                    const Text('Stres Trendi (Son 8 Hafta)',
                        style: TextStyle(color: AppTheme.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _buildTrendChart(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRiskBadge() {
    final risk = _lastAnalysis!['burnout_risk'] as String? ?? 'Düşük';
    final color = _riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            risk == 'Yüksek' ? Icons.warning : Icons.check_circle_outline,
            color: color, size: 18,
          ),
          const SizedBox(width: 8),
          Text('Son Analiz: $risk Risk',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final risk = _lastAnalysis!['burnout_risk'] as String? ?? 'Düşük';
    final recs = _lastAnalysis!['recommendations'];
    final analysis = _lastAnalysis!['analysis'] as String? ?? '';
    final color = _riskColor(risk);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.neonPurple, size: 18),
              const SizedBox(width: 8),
              const Text('AI Analiz Sonucu',
                  style: TextStyle(color: AppTheme.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$risk Risk',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(analysis,
              style: TextStyle(color: AppTheme.white.withOpacity(0.75),
                  fontSize: 13, height: 1.6)),
          if (recs != null) ...[
            const SizedBox(height: 14),
            const Text('Öneriler:',
                style: TextStyle(color: AppTheme.neonGreen,
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              recs is List
                  ? recs.map((r) => '• $r').join('\n')
                  : recs.toString(),
              style: TextStyle(color: AppTheme.white.withOpacity(0.7),
                  fontSize: 13, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final reversed = _history.reversed.toList();
    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Stres
            LineChartBarData(
              spots: reversed.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(),
                      (e.value['stress_level'] as int).toDouble())).toList(),
              color: AppTheme.neonRed,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              isCurved: true,
            ),
            // Enerji
            LineChartBarData(
              spots: reversed.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(),
                      (e.value['energy_level'] as int).toDouble())).toList(),
              color: AppTheme.neonGreen,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              isCurved: true,
            ),
          ],
          minY: 0,
          maxY: 10,
        ),
      ),
    );
  }
}

class _MoodSlider extends StatelessWidget {
  final String label;
  final int value;
  final String lowLabel;
  final String highLabel;
  final Color color;
  final ValueChanged<int> onChanged;

  const _MoodSlider({
    required this.label, required this.value,
    required this.lowLabel, required this.highLabel,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(
                  color: AppTheme.white, fontWeight: FontWeight.w600,
                  fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$value / 10',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: AppTheme.surfaceColor,
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Row(
            children: [
              Text(lowLabel,
                  style: TextStyle(color: AppTheme.white.withOpacity(0.3),
                      fontSize: 10)),
              const Spacer(),
              Text(highLabel,
                  style: TextStyle(color: AppTheme.white.withOpacity(0.3),
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

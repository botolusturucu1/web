import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic> _settings = {'daily_allowance': 50.0, 'weekly_limit': 300.0};
  double _spentToday = 0;
  double _spentThisWeek = 0;
  String? _aiWarning;
  bool _analyzingAi = false;
  bool _loading = true;

  static const _categories = [
    'Yemek', 'İçecek', 'Kırtasiye', 'Ulaşım', 'Eğlence', 'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final settings = await DatabaseHelper.instance.query('budget_settings', limit: 1);
    if (settings.isNotEmpty) _settings = Map.from(settings.first);

    final today = DateTime.now().toIso8601String().split('T')[0];
    final weekStart = DateTime.now()
        .subtract(Duration(days: DateTime.now().weekday - 1))
        .toIso8601String()
        .split('T')[0];

    final entries = await DatabaseHelper.instance.query(
      'budget_entries',
      where: "entry_date >= ?",
      whereArgs: [weekStart],
      orderBy: 'entry_date DESC, created_at DESC',
    );

    double todaySpent = 0, weekSpent = 0;
    for (final e in entries) {
      if (e['type'] == 'expense') {
        weekSpent += (e['amount'] as num).toDouble();
        if ((e['entry_date'] as String) == today) {
          todaySpent += (e['amount'] as num).toDouble();
        }
      }
    }

    setState(() {
      _entries = entries;
      _spentToday = todaySpent;
      _spentThisWeek = weekSpent;
      _loading = false;
    });

    // Limit uyarısı
    final weeklyLimit = (_settings['weekly_limit'] as num).toDouble();
    if (_spentThisWeek >= weeklyLimit * 0.8) {
      await NotificationService.instance.showBudgetWarning(
        message: 'Haftalık limitinin %80\'ine ulaştın!',
        isCritical: _spentThisWeek >= weeklyLimit,
      );
    }
  }

  Future<void> _analyzeWithAi() async {
    setState(() => _analyzingAi = true);
    try {
      final recent = _entries.take(10).map((e) => {
        'amount': e['amount'],
        'category': e['category'],
        'date': e['entry_date'],
      }).toList();

      final result = await AiService.instance.analyzeBudget(
        dailyAllowance: (_settings['daily_allowance'] as num).toDouble(),
        spentToday: _spentToday,
        spentThisWeek: _spentThisWeek,
        weeklyLimit: (_settings['weekly_limit'] as num).toDouble(),
        recentExpenses: recent,
      );

      setState(() => _aiWarning = '${result['warning'] ?? ''}\n\n💡 ${result['tip']}');

      if (result['status'] == 'kritik') {
        await NotificationService.instance.showBudgetWarning(
          message: result['warning'] as String? ?? 'Bütçen kritik seviyede!',
          isCritical: true,
        );
      }
    } on AiException catch (e) {
      setState(() => _aiWarning = e.message);
    } finally {
      setState(() => _analyzingAi = false);
    }
  }

  Future<void> _addEntry() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddEntrySheet(categories: _categories),
    );
    if (result == null) return;
    await DatabaseHelper.instance.insert('budget_entries', result);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final daily = (_settings['daily_allowance'] as num).toDouble();
    final weekly = (_settings['weekly_limit'] as num).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Bütçe Takibi',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textDim),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Özet kartlar
                  Row(
                    children: [
                      _BudgetCard(
                        label: 'Bugün Harcanan',
                        amount: _spentToday,
                        limit: daily,
                        color: _spentToday > daily ? AppTheme.neonRed : AppTheme.neonGreen,
                      ),
                      const SizedBox(width: 12),
                      _BudgetCard(
                        label: 'Bu Hafta',
                        amount: _spentThisWeek,
                        limit: weekly,
                        color: _spentThisWeek > weekly * 0.8
                            ? AppTheme.neonRed : AppTheme.neonBlue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Haftalık grafik
                  if (_entries.isNotEmpty) ...[
                    const Text('Harcama Trendi',
                        style: TextStyle(color: AppTheme.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: BarChart(_buildBarChartData()),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // AI analiz kartı
                  if (_aiWarning != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.neonOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.neonOrange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: AppTheme.neonOrange, size: 14),
                              SizedBox(width: 6),
                              Text('AI Bütçe Analizi',
                                  style: TextStyle(color: AppTheme.neonOrange,
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_aiWarning!,
                              style: TextStyle(
                                  color: AppTheme.white.withOpacity(0.8),
                                  fontSize: 13, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // AI analiz butonu
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _analyzingAi ? null : _analyzeWithAi,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.neonOrange.withOpacity(0.5)),
                        foregroundColor: AppTheme.neonOrange,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _analyzingAi
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.neonOrange))
                          : const Icon(Icons.insights, size: 16),
                      label: const Text('AI Harcama Analizi'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Harcama listesi
                  const Text('Son Harcamalar',
                      style: TextStyle(color: AppTheme.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  ..._entries.take(20).map((e) => _EntryRow(entry: e)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: AppTheme.neonGreen,
        foregroundColor: AppTheme.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  BarChartData _buildBarChartData() {
    // Son 7 gün için günlük harcama
    final Map<String, double> dailyTotals = {};
    for (var i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i))
          .toIso8601String().split('T')[0];
      dailyTotals[date] = 0;
    }
    for (final e in _entries) {
      if (e['type'] == 'expense') {
        final date = e['entry_date'] as String;
        if (dailyTotals.containsKey(date)) {
          dailyTotals[date] = (dailyTotals[date] ?? 0) +
              (e['amount'] as num).toDouble();
        }
      }
    }

    final spots = dailyTotals.values.toList().asMap().entries.map((e) =>
        BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: AppTheme.neonBlue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        )).toList();

    return BarChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: spots,
    );
  }

  void _showSettings() async {
    final dailyCtrl = TextEditingController(
        text: (_settings['daily_allowance'] as num).toStringAsFixed(0));
    final weeklyCtrl = TextEditingController(
        text: (_settings['weekly_limit'] as num).toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Bütçe Ayarları',
            style: TextStyle(color: AppTheme.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dailyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Günlük Harçlık (TL)')),
            const SizedBox(height: 12),
            TextField(controller: weeklyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Haftalık Limit (TL)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textDim))),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.update(
                'budget_settings',
                {
                  'daily_allowance': double.tryParse(dailyCtrl.text) ?? 50,
                  'weekly_limit': double.tryParse(weeklyCtrl.text) ?? 300,
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'id = 1',
                whereArgs: [1],
              );
              if (context.mounted) Navigator.pop(context);
              await _loadData();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final String label;
  final double amount;
  final double limit;
  final Color color;
  const _BudgetCard(
      {required this.label, required this.amount,
       required this.limit, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = (amount / limit).clamp(0.0, 1.0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                color: AppTheme.white.withOpacity(0.5), fontSize: 11)),
            const SizedBox(height: 6),
            Text('₺${amount.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text('/ ₺${limit.toStringAsFixed(0)}',
                style: TextStyle(color: AppTheme.white.withOpacity(0.3),
                    fontSize: 11)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation(color),
              borderRadius: BorderRadius.circular(3),
              minHeight: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryRow({required this.entry});

  static const _catIcons = {
    'Yemek': Icons.restaurant, 'İçecek': Icons.local_drink,
    'Kırtasiye': Icons.edit, 'Ulaşım': Icons.directions_bus,
    'Eğlence': Icons.sports_esports, 'Diğer': Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final isExpense = entry['type'] == 'expense';
    final amount = (entry['amount'] as num).toDouble();
    final category = entry['category'] as String? ?? 'Diğer';
    final icon = _catIcons[category] ?? Icons.more_horiz;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (isExpense ? AppTheme.neonRed : AppTheme.neonGreen)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isExpense ? AppTheme.neonRed : AppTheme.neonGreen,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['description'] as String? ?? category,
                    style: const TextStyle(color: AppTheme.white, fontSize: 13)),
                Text(entry['entry_date'] as String,
                    style: TextStyle(
                        color: AppTheme.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}₺${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isExpense ? AppTheme.neonRed : AppTheme.neonGreen,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  final List<String> categories;
  const _AddEntrySheet({required this.categories});
  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'Yemek';
  String _type = 'expense';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Harcama Ekle',
              style: TextStyle(color: AppTheme.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Gelir/Gider toggle
          Row(
            children: [
              Expanded(child: _TypeBtn(
                label: 'Gider', selected: _type == 'expense',
                color: AppTheme.neonRed,
                onTap: () => setState(() => _type = 'expense'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _TypeBtn(
                label: 'Gelir', selected: _type == 'income',
                color: AppTheme.neonGreen,
                onTap: () => setState(() => _type = 'income'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.white, fontSize: 20,
                fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Tutar (TL)',
              prefixText: '₺ ',
              prefixStyle: TextStyle(color: AppTheme.neonGreen),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: AppTheme.cardColor,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: widget.categories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c, style: const TextStyle(color: AppTheme.white)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountCtrl.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, {
                  'type': _type,
                  'amount': amount,
                  'category': _selectedCategory,
                  'description': _descCtrl.text.trim().isEmpty
                      ? _selectedCategory : _descCtrl.text.trim(),
                  'entry_date': DateTime.now().toIso8601String().split('T')[0],
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

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.selected,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
            color: selected ? color : AppTheme.textDim,
            fontWeight: FontWeight.bold)),
      ),
    );
  }
}

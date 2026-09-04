import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _plans = [];
  bool _loading = false;
  bool _generating = false;

  // Form alanları
  DateTime _examDate = DateTime.now().add(const Duration(days: 14));
  final List<String> _selectedWeakSubjects = [];
  final _freeSlotController = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _freeSlotController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final subjects = await DatabaseHelper.instance.query(
      'subjects',
      orderBy: 'name ASC',
    );
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final plans = await DatabaseHelper.instance.query(
      'study_plans',
      where: 'plan_date >= ?',
      whereArgs: [today],
      orderBy: 'plan_date ASC, priority DESC',
    );
    setState(() {
      _subjects = subjects;
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _generatePlan() async {
    if (_selectedWeakSubjects.isEmpty) {
      _showSnack('En az bir zayıf ders seç');
      return;
    }

    setState(() => _generating = true);
    try {
      final freeHours = int.tryParse(_freeSlotController.text) ?? 2;
      final freeSlots = List.generate(freeHours, (i) => {
        'start': '${14 + i}:00',
        'end': '${15 + i}:00',
        'duration_min': 60,
      });

      final result = await AiService.instance.generateStudyPlan(
        weakSubjects: _selectedWeakSubjects,
        examDate: DateFormat('yyyy-MM-dd').format(_examDate),
        freeSlots: freeSlots,
      );

      // Eski AI planını temizle
      await DatabaseHelper.instance.rawQuery(
        'DELETE FROM study_plans WHERE ai_generated = 1',
      );

      // Yeni planı kaydet
      for (final task in result) {
        final t = task as Map<String, dynamic>;
        // Subject ID bul
        final subjectMatch = _subjects.firstWhere(
          (s) => (s['name'] as String)
              .toLowerCase()
              .contains((t['subject'] as String).toLowerCase()),
          orElse: () => _subjects.first,
        );

        await DatabaseHelper.instance.insert('study_plans', {
          'plan_date': t['date'],
          'subject_id': subjectMatch['id'],
          'task_title': t['task'],
          'duration_min': t['duration_min'] ?? 30,
          'priority': t['priority'] ?? 2,
          'is_completed': 0,
          'ai_generated': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await _loadData();
      _tabController.animateTo(1);
      _showSnack('Program oluşturuldu! 🎯');
    } on AiException catch (e) {
      _showSnack(e.message);
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _toggleComplete(int id, int current) async {
    await DatabaseHelper.instance.update(
      'study_plans',
      {'is_completed': current == 0 ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadData();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text(
          'AI Çalışma Programı',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.neonGreen,
          labelColor: AppTheme.neonGreen,
          unselectedLabelColor: AppTheme.white.withOpacity(0.4),
          tabs: const [
            Tab(text: 'Plan Oluştur'),
            Tab(text: 'Programım'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : TabBarView(
              controller: _tabController,
              children: [_buildGeneratorTab(), _buildPlanTab()],
            ),
    );
  }

  Widget _buildGeneratorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sınav Tarihi
          _SectionTitle(title: '📅 Sınav / Yazılı Tarihi'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickExamDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppTheme.neonGreen, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMMM yyyy', 'tr_TR').format(_examDate),
                    style: const TextStyle(
                        color: AppTheme.white, fontSize: 15),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: AppTheme.white.withOpacity(0.4)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionTitle(title: '😓 Zayıf Olduğun Dersler'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subjects.map((s) {
              final name = s['name'] as String;
              final selected = _selectedWeakSubjects.contains(name);
              final color = _hexToColor(s['color_hex'] as String);
              return FilterChip(
                label: Text(name,
                    style: TextStyle(
                        color: selected ? AppTheme.black : AppTheme.white,
                        fontSize: 13)),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedWeakSubjects.add(name);
                    } else {
                      _selectedWeakSubjects.remove(name);
                    }
                  });
                },
                selectedColor: color,
                backgroundColor: AppTheme.cardColor,
                checkmarkColor: AppTheme.black,
                side: BorderSide(
                    color: selected ? color : color.withOpacity(0.3)),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          _SectionTitle(title: '⏰ Günlük Boş Ders Saati'),
          const SizedBox(height: 8),
          Row(
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: () {
                  final v = int.tryParse(_freeSlotController.text) ?? 2;
                  if (v > 1) {
                    _freeSlotController.text = (v - 1).toString();
                  }
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _freeSlotController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '2',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _CounterButton(
                icon: Icons.add,
                onTap: () {
                  final v = int.tryParse(_freeSlotController.text) ?? 2;
                  _freeSlotController.text = (v + 1).toString();
                },
              ),
            ],
          ),
          Center(
            child: Text(
              'saat/gün',
              style: TextStyle(
                  color: AppTheme.white.withOpacity(0.4), fontSize: 12),
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _generating ? null : _generatePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: AppTheme.black,
                disabledBackgroundColor:
                    AppTheme.neonGreen.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _generating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppTheme.black, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'AI ile Program Oluştur',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTab() {
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note,
                size: 64, color: AppTheme.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Henüz program yok',
              style: TextStyle(
                  color: AppTheme.white.withOpacity(0.4), fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Program Oluştur',
                  style: TextStyle(color: AppTheme.neonGreen)),
            ),
          ],
        ),
      );
    }

    // Tarihe göre grupla
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final plan in _plans) {
      final date = plan['plan_date'] as String;
      grouped.putIfAbsent(date, () => []).add(plan);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final date = grouped.keys.elementAt(i);
        final dayPlans = grouped[date]!;
        final dateObj = DateTime.parse(date);
        final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(dateObj);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateStr,
                style: const TextStyle(
                  color: AppTheme.neonGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...dayPlans.map((plan) => _PlanTaskCard(
                  plan: plan,
                  subjects: _subjects,
                  onToggle: () => _toggleComplete(
                    plan['id'] as int,
                    plan['is_completed'] as int,
                  ),
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.neonGreen,
            surface: AppTheme.cardColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _PlanTaskCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> subjects;
  final VoidCallback onToggle;

  const _PlanTaskCard({
    required this.plan,
    required this.subjects,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = (plan['is_completed'] as int) == 1;
    final priority = plan['priority'] as int? ?? 2;
    final duration = plan['duration_min'] as int? ?? 30;

    // Konuya göre renk bul
    final subjectId = plan['subject_id'];
    final subject = subjects.firstWhere(
      (s) => s['id'] == subjectId,
      orElse: () => {'name': 'Genel', 'color_hex': '#00E676'},
    );
    final color = _hexToColor(subject['color_hex'] as String);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.cardColor.withOpacity(0.4)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? AppTheme.neonGreen : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? AppTheme.neonGreen
                    : AppTheme.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: AppTheme.black)
                : null,
          ),
        ),
        title: Text(
          plan['task_title'] as String,
          style: TextStyle(
            color: isCompleted
                ? AppTheme.white.withOpacity(0.4)
                : AppTheme.white,
            fontSize: 14,
            decoration:
                isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subject['name'] as String,
                style: TextStyle(color: color, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.timer_outlined,
                size: 12, color: AppTheme.white.withOpacity(0.4)),
            const SizedBox(width: 3),
            Text(
              '$duration dk',
              style: TextStyle(
                  color: AppTheme.white.withOpacity(0.4), fontSize: 11),
            ),
          ],
        ),
        trailing: _PriorityDot(priority: priority),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _PriorityDot extends StatelessWidget {
  final int priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.grey,
      const Color(0xFF64B5F6),
      const Color(0xFFFFAB40),
      const Color(0xFFFF7043),
      const Color(0xFFFF1744),
    ];
    final color = colors[priority.clamp(0, 4)];
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppTheme.neonGreen, size: 20),
      ),
    );
  }
}

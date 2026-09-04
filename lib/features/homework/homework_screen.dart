import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});
  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  List<Map<String, dynamic>> _homework = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  static const _quadrants = {
    'do_now':   {'label': 'Hemen Yap', 'color': 0xFFFF1744, 'icon': Icons.bolt},
    'plan':     {'label': 'Planla',    'color': 0xFF448AFF, 'icon': Icons.event},
    'delegate': {'label': 'Ertele',    'color': 0xFFFFAB40, 'icon': Icons.schedule},
    'eliminate':{'label': 'Çöpe At',   'color': 0xFF757575, 'icon': Icons.delete_outline},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final hw = await DatabaseHelper.instance.query(
      'homework', where: 'is_completed = 0', orderBy: 'due_date ASC');
    final subs = await DatabaseHelper.instance.query('subjects', orderBy: 'name ASC');
    setState(() { _homework = hw; _subjects = subs; _loading = false; });
  }

  Future<void> _addHomework() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddHomeworkSheet(subjects: _subjects),
    );
    if (result == null) return;

    // AI ile Eisenhower analizi
    try {
      final subjectName = _subjects.firstWhere(
        (s) => s['id'] == result['subject_id'],
        orElse: () => {'name': 'Genel'},
      )['name'] as String;

      final ai = await AiService.instance.classifyHomework(
        title: result['title'],
        dueDate: result['due_date'],
        subject: subjectName,
      );
      result['quadrant'] = ai['quadrant'] ?? 'plan';
      result['urgency'] = ai['urgency'] ?? 2;
      result['importance'] = ai['importance'] ?? 2;
      result['ai_analyzed'] = 1;
    } catch (_) {
      result['quadrant'] = 'plan';
    }

    await DatabaseHelper.instance.insert('homework', result);
    await _loadData();
  }

  Future<void> _complete(int id) async {
    await DatabaseHelper.instance.update(
      'homework', {'is_completed': 1}, where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  Future<void> _delete(int id) async {
    await DatabaseHelper.instance.delete(
      'homework', where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Ödev Yöneticisi',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.neonGreen),
            onPressed: _addHomework,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : _homework.isEmpty
              ? _buildEmpty()
              : _buildMatrix(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHomework,
        backgroundColor: AppTheme.neonGreen,
        foregroundColor: AppTheme.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMatrix() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _quadrants.entries.map((entry) {
          final quadrantHw = _homework
              .where((h) => h['quadrant'] == entry.key)
              .toList();
          if (quadrantHw.isEmpty) return const SizedBox.shrink();

          final color = Color(entry.value['color'] as int);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quadrant başlığı
              Row(
                children: [
                  Icon(entry.value['icon'] as IconData, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    entry.value['label'] as String,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${quadrantHw.length}',
                        style: TextStyle(color: color, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...quadrantHw.map((hw) => _HomeworkCard(
                    hw: hw,
                    subjects: _subjects,
                    quadrantColor: color,
                    onComplete: () => _complete(hw['id'] as int),
                    onDelete: () => _delete(hw['id'] as int),
                  )),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: AppTheme.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('Harika! Bekleyen ödev yok.',
              style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 16)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addHomework,
            icon: const Icon(Icons.add, color: AppTheme.neonGreen),
            label: const Text('Ödev Ekle',
                style: TextStyle(color: AppTheme.neonGreen)),
          ),
        ],
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> hw;
  final List<Map<String, dynamic>> subjects;
  final Color quadrantColor;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const _HomeworkCard({
    required this.hw, required this.subjects,
    required this.quadrantColor, required this.onComplete, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dueDate = hw['due_date'] as String;
    final dueDateTime = DateTime.tryParse(dueDate);
    final daysLeft = dueDateTime != null
        ? dueDateTime.difference(DateTime.now()).inDays
        : null;
    final subject = subjects.firstWhere(
      (s) => s['id'] == hw['subject_id'],
      orElse: () => {'name': 'Genel', 'color_hex': '#00E676'},
    );
    final subjectColor = Color(
        int.parse('FF${(subject['color_hex'] as String).replaceAll('#', '')}',
            radix: 16));
    final isAiAnalyzed = (hw['ai_analyzed'] as int? ?? 0) == 1;

    return Dismissible(
      key: Key('hw_${hw['id']}'),
      background: Container(
        decoration: BoxDecoration(
          color: AppTheme.neonGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: AppTheme.neonGreen),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: AppTheme.neonRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: AppTheme.neonRed),
      ),
      onDismissed: (dir) =>
          dir == DismissDirection.startToEnd ? onComplete() : onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: quadrantColor.withOpacity(0.25)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: GestureDetector(
            onTap: onComplete,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: quadrantColor, width: 2),
              ),
            ),
          ),
          title: Text(hw['title'] as String,
              style: const TextStyle(color: AppTheme.white, fontSize: 14)),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(subject['name'] as String,
                    style: TextStyle(color: subjectColor, fontSize: 10)),
              ),
              if (daysLeft != null) ...[
                const SizedBox(width: 8),
                Text(
                  daysLeft <= 0 ? 'Bugün!' : '$daysLeft gün',
                  style: TextStyle(
                    color: daysLeft <= 1 ? AppTheme.neonRed
                        : daysLeft <= 3 ? AppTheme.neonOrange
                        : AppTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
              if (isAiAnalyzed) ...[
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome, size: 12,
                    color: AppTheme.neonBlue),
              ],
            ],
          ),
          trailing: Text(
            DateFormat('dd/MM').format(DateTime.tryParse(dueDate) ?? DateTime.now()),
            style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _AddHomeworkSheet extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  const _AddHomeworkSheet({required this.subjects});
  @override
  State<_AddHomeworkSheet> createState() => _AddHomeworkSheetState();
}

class _AddHomeworkSheetState extends State<_AddHomeworkSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  int? _selectedSubjectId;

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
          Row(
            children: [
              const Text('Ödev Ekle',
                  style: TextStyle(color: AppTheme.white,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: AppTheme.neonBlue, size: 14),
              const SizedBox(width: 4),
              Text('AI Sınıflandırma',
                  style: TextStyle(
                      color: AppTheme.neonBlue.withOpacity(0.7), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(labelText: 'Ödev başlığı'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedSubjectId,
            dropdownColor: AppTheme.cardColor,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(labelText: 'Ders'),
            items: widget.subjects.map((s) => DropdownMenuItem<int>(
              value: s['id'] as int,
              child: Text(s['name'] as String,
                  style: const TextStyle(color: AppTheme.white)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedSubjectId = v),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 180)),
                builder: (_, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                        primary: AppTheme.neonGreen, surface: AppTheme.cardColor)),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppTheme.neonGreen, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Son Teslim: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(_dueDate)}',
                    style: const TextStyle(color: AppTheme.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_titleCtrl.text.isEmpty) return;
                Navigator.pop(context, {
                  'title': _titleCtrl.text.trim(),
                  'description': _descCtrl.text.trim(),
                  'subject_id': _selectedSubjectId,
                  'due_date': _dueDate.toIso8601String().split('T')[0],
                  'is_completed': 0,
                  'ai_analyzed': 0,
                  'quadrant': 'plan',
                  'urgency': 2,
                  'importance': 2,
                  'created_at': DateTime.now().toIso8601String(),
                });
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI ile Ekle'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

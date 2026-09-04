import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<Map<String, dynamic>> _decks = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final decks = await DatabaseHelper.instance.query('flashcard_decks', orderBy: 'created_at DESC');
    final subjects = await DatabaseHelper.instance.query('subjects');
    // Her deste için kart sayısını güncelle
    for (final deck in decks) {
      final count = await DatabaseHelper.instance.rawQuery(
        'SELECT COUNT(*) as c FROM flashcards WHERE deck_id = ?', [deck['id']]);
      deck['card_count'] = count.first['c'] as int;
    }
    setState(() { _decks = decks; _subjects = subjects; _loading = false; });
  }

  Future<void> _createDeckWithAi() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateDeckSheet(subjects: _subjects),
    );
    if (result == null) return;

    // Deste oluştur
    final deckId = await DatabaseHelper.instance.insert('flashcard_decks', {
      'subject_id': result['subject_id'],
      'title': result['title'],
      'description': result['notes'],
      'card_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // AI ile kartları üret
    if (result['notes'] != null && (result['notes'] as String).isNotEmpty) {
      try {
        final subjectName = _subjects.firstWhere(
          (s) => s['id'] == result['subject_id'],
          orElse: () => {'name': 'Genel'},
        )['name'] as String;

        final cards = await AiService.instance.generateFlashcards(
          subject: subjectName,
          notes: result['notes'] as String,
          count: 10,
        );

        for (final card in cards) {
          final c = card as Map<String, dynamic>;
          await DatabaseHelper.instance.insert('flashcards', {
            'deck_id': deckId,
            'question': c['question'],
            'answer': c['answer'],
            'difficulty': 'new',
            'next_review': DateTime.now().toIso8601String(),
            'interval_days': 1,
            'ease_factor': 2.5,
            'review_count': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${cards.length} kart oluşturuldu! 🎴')));
        }
      } on AiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)));
        }
      }
    }

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Flashcard\'lar',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : _decks.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _decks.length,
                  itemBuilder: (_, i) => _DeckCard(
                    deck: _decks[i],
                    subjects: _subjects,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _StudySession(deck: _decks[i]),
                      ),
                    ).then((_) => _loadData()),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDeckWithAi,
        backgroundColor: AppTheme.neonGreen,
        foregroundColor: AppTheme.black,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI ile Deste Oluştur',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 64, color: AppTheme.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('Henüz kart yok',
              style: TextStyle(color: AppTheme.white.withOpacity(0.4), fontSize: 16)),
          const SizedBox(height: 8),
          Text('Ders notlarını yaz, AI otomatik\nsoru-cevap kartları üretsin!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

// ── DESTE KARTI ───────────────────────────────────────────────────────────────

class _DeckCard extends StatelessWidget {
  final Map<String, dynamic> deck;
  final List<Map<String, dynamic>> subjects;
  final VoidCallback onTap;

  const _DeckCard({required this.deck, required this.subjects, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subject = subjects.firstWhere(
      (s) => s['id'] == deck['subject_id'],
      orElse: () => {'name': 'Genel', 'color_hex': '#00E676'},
    );
    final color = Color(int.parse(
        'FF${(subject['color_hex'] as String).replaceAll('#', '')}', radix: 16));
    final cardCount = deck['card_count'] as int? ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.style, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck['title'] as String,
                      style: const TextStyle(color: AppTheme.white,
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(subject['name'] as String,
                            style: TextStyle(color: color, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Text('$cardCount kart',
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.4), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textDim, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── ÇALIŞMA OTURUMU ───────────────────────────────────────────────────────────

class _StudySession extends StatefulWidget {
  final Map<String, dynamic> deck;
  const _StudySession({required this.deck});

  @override
  State<_StudySession> createState() => _StudySessionState();
}

class _StudySessionState extends State<_StudySession>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _loading = true;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flipAnim = Tween(begin: 0.0, end: 1.0).animate(_flipCtrl);
    _loadDueCards();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDueCards() async {
    final now = DateTime.now().toIso8601String();
    final cards = await DatabaseHelper.instance.query(
      'flashcards',
      where: 'deck_id = ? AND next_review <= ?',
      whereArgs: [widget.deck['id'], now],
      orderBy: 'next_review ASC',
    );
    setState(() {
      _cards = cards;
      _currentIndex = 0;
      _showAnswer = false;
      _loading = false;
    });
  }

  Future<void> _rateCard(String difficulty) async {
    if (_cards.isEmpty) return;
    final card = _cards[_currentIndex];

    // SM-2 Spaced Repetition algoritması
    double ef = (card['ease_factor'] as num).toDouble();
    int interval = card['interval_days'] as int;
    int reviewCount = (card['review_count'] as int) + 1;

    int q; // kalite 0-5
    switch (difficulty) {
      case 'again': q = 0; break;
      case 'hard':  q = 2; break;
      case 'good':  q = 4; break;
      case 'easy':  q = 5; break;
      default:      q = 3;
    }

    if (q < 3) {
      interval = 1;
    } else {
      if (reviewCount == 1) {
        interval = 1;
      } else if (reviewCount == 2) {
        interval = 6;
      } else {
        interval = (interval * ef).round();
      }
    }

    ef = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (ef < 1.3) ef = 1.3;

    final nextReview = DateTime.now()
        .add(Duration(days: interval))
        .toIso8601String();

    await DatabaseHelper.instance.update(
      'flashcards',
      {
        'difficulty': difficulty,
        'next_review': nextReview,
        'interval_days': interval,
        'ease_factor': ef,
        'review_count': reviewCount,
      },
      where: 'id = ?',
      whereArgs: [card['id']],
    );

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        _flipCtrl.reset();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('🎉 Oturum Tamamlandı!',
            style: TextStyle(color: AppTheme.white)),
        content: Text(
          '${_cards.length} kart çalışıldı.\nBir sonraki tekrar algoritma tarafından planlandı.',
          style: TextStyle(color: AppTheme.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Tamam', style: TextStyle(color: AppTheme.neonGreen)),
          ),
        ],
      ),
    );
  }

  void _flipCard() {
    if (_showAnswer) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text(widget.deck['title'] as String,
            style: const TextStyle(color: AppTheme.white)),
        actions: [
          if (_cards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '${_currentIndex + 1}/${_cards.length}',
                style: const TextStyle(color: AppTheme.textDim),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : _cards.isEmpty
              ? _buildDoneState()
              : _buildCardView(),
    );
  }

  Widget _buildCardView() {
    final card = _cards[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // İlerleme çubuğu
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _cards.length,
            backgroundColor: AppTheme.cardColor,
            valueColor: const AlwaysStoppedAnimation(AppTheme.neonGreen),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 30),

          // Kart
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnim,
                builder: (_, child) {
                  final angle = _flipAnim.value * 3.14159;
                  final isFront = _flipAnim.value < 0.5;
                  return Transform(
                    transform: Matrix4.rotationY(angle),
                    alignment: Alignment.center,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isFront
                              ? AppTheme.neonBlue.withOpacity(0.4)
                              : AppTheme.neonGreen.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFront ? AppTheme.neonBlue : AppTheme.neonGreen)
                                .withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFront ? 'SORU' : 'CEVAP',
                              style: TextStyle(
                                color: (isFront ? AppTheme.neonBlue : AppTheme.neonGreen)
                                    .withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Transform(
                              transform: isFront
                                  ? Matrix4.identity()
                                  : Matrix4.rotationY(3.14159),
                              alignment: Alignment.center,
                              child: Text(
                                isFront
                                    ? card['question'] as String
                                    : card['answer'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 20,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (!_showAnswer)
                              Text(
                                'Kartı çevirmek için dokun',
                                style: TextStyle(
                                  color: AppTheme.white.withOpacity(0.3),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Değerlendirme butonları (sadece cevap görününce)
          AnimatedOpacity(
            opacity: _showAnswer ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Row(
              children: [
                _RateButton(label: 'Tekrar', color: AppTheme.neonRed,
                    onTap: () => _rateCard('again')),
                const SizedBox(width: 8),
                _RateButton(label: 'Zor', color: AppTheme.neonOrange,
                    onTap: () => _rateCard('hard')),
                const SizedBox(width: 8),
                _RateButton(label: 'İyi', color: AppTheme.neonBlue,
                    onTap: () => _rateCard('good')),
                const SizedBox(width: 8),
                _RateButton(label: 'Kolay', color: AppTheme.neonGreen,
                    onTap: () => _rateCard('easy')),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: AppTheme.neonGreen),
          const SizedBox(height: 16),
          const Text('Bugünlük hepsi bu!',
              style: TextStyle(color: AppTheme.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tekrar edilecek kart yok.\nYarın tekrar gelin!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.white.withOpacity(0.5))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RateButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _CreateDeckSheet extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  const _CreateDeckSheet({required this.subjects});
  @override
  State<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends State<_CreateDeckSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
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
          const Text('AI ile Deste Oluştur',
              style: TextStyle(color: AppTheme.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(labelText: 'Deste Adı'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedSubjectId,
            dropdownColor: AppTheme.cardColor,
            decoration: const InputDecoration(labelText: 'Ders'),
            items: widget.subjects.map((s) => DropdownMenuItem<int>(
              value: s['id'] as int,
              child: Text(s['name'] as String,
                  style: const TextStyle(color: AppTheme.white)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedSubjectId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(
              labelText: 'Ders Notların (AI kartları buradan üretir)',
              alignLabelWithHint: true,
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
                  'subject_id': _selectedSubjectId,
                  'notes': _notesCtrl.text.trim(),
                });
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Oluştur'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

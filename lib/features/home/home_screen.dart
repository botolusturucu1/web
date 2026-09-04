import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../../core/services/meb_intelligence_service.dart';
import '../../core/theme/app_theme.dart';
import '../study_plan/study_plan_screen.dart';
import '../grades/grades_screen.dart';
import '../homework/homework_screen.dart';
import '../flashcards/flashcard_screen.dart';
import '../pomodoro/pomodoro_screen.dart';
import '../budget/budget_screen.dart';
import '../absence/absence_screen.dart';
import '../burnout/burnout_screen.dart';
import '../meb/meb_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _mebUnread = 0;

  static const _pages = [
    _DashboardPage(),
    HomeworkScreen(),
    PomodoroScreen(),
    FlashcardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadMebCount();
  }

  Future<void> _loadMebCount() async {
    final count = await MebIntelligenceService.instance.getUnreadCount();
    setState(() => _mebUnread = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation, secondaryAnimation) =>
            FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            ),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(
              top: BorderSide(color: AppTheme.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.neonGreen,
          unselectedItemColor: AppTheme.textDim,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Ana Sayfa',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Ödevler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'Pomodoro',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.style_outlined),
              activeIcon: Icon(Icons.style),
              label: 'Flashcard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────

class _DashboardPage extends StatefulWidget {
  const _DashboardPage();
  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  int _mebUnread = 0;

  @override
  void initState() {
    super.initState();
    _loadMebCount();
  }

  Future<void> _loadMebCount() async {
    final count = await MebIntelligenceService.instance.getUnreadCount();
    setState(() => _mebUnread = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: AppTheme.black,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NexusEdu Ultra',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: AppTheme.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // MEB Uyarı Kartı
                if (_mebUnread > 0) _buildMebAlert(),

                const SizedBox(height: 20),

                // Modül Grid
                const Text('Modüller',
                    style: TextStyle(color: AppTheme.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _buildModuleGrid(context),

                const SizedBox(height: 24),
                const Text('Hızlı Erişim',
                    style: TextStyle(color: AppTheme.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildQuickAccess(context),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMebAlert() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MebScreen())).then((_) => _loadMebCount()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.neonRed.withOpacity(0.15),
              AppTheme.neonBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.neonRed.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.neonRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: AppTheme.neonRed, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_mebUnread okunmamış MEB duyurusu',
                      style: const TextStyle(color: AppTheme.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Text('Seni etkileyen güncellemeler var',
                      style: TextStyle(color: AppTheme.neonRed, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textDim),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final modules = [
      _Module(icon: Icons.auto_awesome, label: 'AI Program',
          color: AppTheme.neonGreen, screen: const StudyPlanScreen()),
      _Module(icon: Icons.bar_chart, label: 'Notlar',
          color: AppTheme.neonBlue, screen: const GradesScreen()),
      _Module(icon: Icons.style, label: 'Flashcard',
          color: AppTheme.neonPurple, screen: const FlashcardScreen()),
      _Module(icon: Icons.timer, label: 'Pomodoro',
          color: AppTheme.neonOrange, screen: const PomodoroScreen()),
      _Module(icon: Icons.account_balance_wallet, label: 'Bütçe',
          color: const Color(0xFF00BCD4), screen: const BudgetScreen()),
      _Module(icon: Icons.event_busy, label: 'Devamsızlık',
          color: AppTheme.neonRed, screen: const AbsenceScreen()),
      _Module(icon: Icons.psychology, label: 'Stres',
          color: const Color(0xFFE040FB), screen: const BurnoutScreen()),
      _Module(icon: Icons.newspaper, label: 'MEB',
          color: const Color(0xFFFFD600), screen: const MebScreen()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleTile(module: modules[i]),
    );
  }

  Widget _buildQuickAccess(BuildContext context) {
    return Column(
      children: [
        _QuickAccessTile(
          icon: Icons.assignment_outlined,
          label: 'Ödevlerim',
          subtitle: 'Eisenhower matrisi ile yönet',
          color: AppTheme.neonBlue,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HomeworkScreen())),
        ),
        const SizedBox(height: 8),
        _QuickAccessTile(
          icon: Icons.psychology_outlined,
          label: 'Haftalık Stres Anketi',
          subtitle: 'AI ile tükenmişlik riski analizi',
          color: const Color(0xFFE040FB),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BurnoutScreen())),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın! Bugün harika bir gün.';
    if (hour < 17) return 'İyi günler! Verimli bir öğleden sonra.';
    if (hour < 21) return 'İyi akşamlar! Çalışmaya devam.';
    return 'İyi geceler! Yarın yeni bir gün.';
  }
}

class _Module {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;
  const _Module({required this.icon, required this.label,
      required this.color, required this.screen});
}

class _ModuleTile extends StatelessWidget {
  final _Module module;
  const _ModuleTile({required this.module});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => module.screen)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: module.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: module.color.withOpacity(0.3)),
            ),
            child: Icon(module.icon, color: module.color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(module.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.white.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                      color: AppTheme.white, fontWeight: FontWeight.bold,
                      fontSize: 14)),
                  Text(subtitle, style: TextStyle(
                      color: AppTheme.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

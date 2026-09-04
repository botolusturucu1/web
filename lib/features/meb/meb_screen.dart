import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/meb_intelligence_service.dart';
import '../../core/theme/app_theme.dart';

class MebScreen extends StatefulWidget {
  const MebScreen({super.key});

  @override
  State<MebScreen> createState() => _MebScreenState();
}

class _MebScreenState extends State<MebScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loading = true);
    final data = await MebIntelligenceService.instance.getAllAnnouncements();
    setState(() {
      _announcements = data;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await MebIntelligenceService.instance.fetchAndAnalyze();
    await _loadAnnouncements();
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text(
          'MEB Duyuruları',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppTheme.neonGreen,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.neonGreen),
              onPressed: _refresh,
              tooltip: 'Güncelle',
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen),
            )
          : _announcements.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppTheme.neonGreen,
                  backgroundColor: AppTheme.cardColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, i) =>
                        _AnnouncementCard(
                          item: _announcements[i],
                          onTap: () async {
                            await MebIntelligenceService.instance
                                .markAsRead(_announcements[i]['id']);
                            setState(() => _announcements[i]['is_read'] = 1);
                          },
                        ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined,
              size: 64, color: AppTheme.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Henüz duyuru yok',
            style: TextStyle(
              color: AppTheme.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: AppTheme.neonGreen),
            label: const Text(
              'Duyuruları Getir',
              style: TextStyle(color: AppTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.item, required this.onTap});

  Color get _impactColor {
    switch (item['impact_level']) {
      case 'Kritik':
        return const Color(0xFFFF1744);
      case 'Yüksek':
        return const Color(0xFFFF6D00);
      case 'Orta':
        return const Color(0xFFFFAB40);
      default:
        return AppTheme.neonGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = (item['is_read'] as int? ?? 0) == 0;
    final isAffected = (item['affected_student'] as int? ?? 0) == 1;
    final fetchedAt = item['fetched_at'] != null
        ? DateFormat('dd MMM HH:mm', 'tr_TR')
            .format(DateTime.parse(item['fetched_at']))
        : '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? _impactColor.withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isAffected
              ? [
                  BoxShadow(
                    color: _impactColor.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  if (isAffected)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _impactColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item['ai_title'] ?? item['raw_title'] ?? '',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 15,
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  // Etki seviyesi badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _impactColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _impactColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      item['impact_level'] ?? 'Normal',
                      style: TextStyle(
                        color: _impactColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              if (item['ai_summary'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  item['ai_summary'],
                  style: TextStyle(
                    color: AppTheme.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],

              // Eylem önerisi
              if (item['ai_action'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.neonGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.neonGreen,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['ai_action'],
                          style: const TextStyle(
                            color: AppTheme.neonGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Text(
                fetchedAt,
                style: TextStyle(
                  color: AppTheme.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

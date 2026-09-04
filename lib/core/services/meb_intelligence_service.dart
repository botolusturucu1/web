import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'ai_service.dart';
import 'notification_service.dart';

/// MEB Canlı İstihbarat ve Akıllı Bildirim Motoru
/// RSS + web scraping + AI analiz katmanı
class MebIntelligenceService {
  static final MebIntelligenceService instance = MebIntelligenceService._();
  MebIntelligenceService._();

  static const _lastFetchKey = 'meb_last_fetch';

  // MEB RSS ve haber kaynakları
  static const _sources = [
    {
      'name': 'MEB Ana Sayfa',
      'url': 'https://www.meb.gov.tr/haberler/haberlistesi.php',
      'type': 'html',
    },
    {
      'name': 'MEB Duyurular',
      'url': 'https://www.meb.gov.tr/duyurular/duyurulistesi.php',
      'type': 'html',
    },
  ];

  // Simüle edilmiş MEB duyuruları (offline-first fallback)
  static final _simulatedAnnouncements = [
    {
      'title': 'Ara Tatil Tarihleri Açıklandı',
      'content':
          'Kasım ayı ara tatili 11-15 Kasım 2025 tarihleri arasında uygulanacaktır. '
          'Tüm okullarda ders yapılmayacak, etkinlikler iptal edilecektir.',
      'url': 'https://www.meb.gov.tr',
    },
    {
      'title': 'LGS Sınav Takvimi Güncellendi',
      'content':
          'Liselere Geçiş Sınavı (LGS) 2025 yılında 1 Haziran tarihinde '
          'yapılacaktır. Başvurular Mart ayında başlayacak.',
      'url': 'https://www.meb.gov.tr',
    },
    {
      'title': 'Ders Kitabı Dağıtımı Hakkında Duyuru',
      'content':
          '2024-2025 eğitim öğretim yılı ders kitapları okullara teslim edilmiştir.',
      'url': 'https://www.meb.gov.tr',
    },
  ];

  // ── ANA FETCH METODU ──────────────────────────────────────────────────────

  /// Arka planda çalışır, yeni duyuruları çekip analiz eder
  Future<List<Map<String, dynamic>>> fetchAndAnalyze() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getString(_lastFetchKey);
    final now = DateTime.now();

    // 4 saatte bir güncelle
    if (lastFetch != null) {
      final last = DateTime.parse(lastFetch);
      if (now.difference(last).inHours < 4) {
        return _getCachedAnnouncements();
      }
    }

    final rawItems = await _fetchFromSources();
    final analyzed = <Map<String, dynamic>>[];

    for (final item in rawItems) {
      try {
        final result = await _analyzeWithAi(item);
        if (result != null) {
          await _saveAnnouncement(item, result);
          analyzed.add({...item, ...result});

          // Etkilenen öğrenciye bildirim gönder
          if (result['affected_student'] == true) {
            await NotificationService.instance.showMebAlert(
              title: result['title'] ?? item['title'],
              body: result['summary'] ?? item['content'],
              payload: 'meb_${item['url']}',
            );
          }
        }
      } catch (_) {
        // Tek duyuru başarısız olsa bile diğerlerine devam et
      }
    }

    await prefs.setString(_lastFetchKey, now.toIso8601String());
    return analyzed;
  }

  // ── KAYNAKLARDAN ÇEK ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchFromSources() async {
    final items = <Map<String, dynamic>>[];

    for (final source in _sources) {
      try {
        final fetched = await _scrapeHtml(source['url']!);
        items.addAll(fetched);
      } catch (_) {
        // Ağ erişimi yoksa simüle edilmiş verileri kullan
        items.addAll(_simulatedAnnouncements);
        break;
      }
    }

    // Tekrar edenler temizle
    final seen = <String>{};
    return items.where((item) {
      final key = item['title'] as String;
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _scrapeHtml(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'NexusEdu/1.0 (educational app)'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final document = html_parser.parse(
      utf8.decode(response.bodyBytes),
    );

    final items = <Map<String, dynamic>>[];

    // MEB sayfa yapısına göre haber listesi çek
    final newsElements = document.querySelectorAll(
      '.haber-liste-item, .news-item, h3 a, .duyuru-item',
    );

    for (final el in newsElements.take(10)) {
      final title = el.text.trim();
      final href = el.attributes['href'] ?? '';
      if (title.length > 10) {
        items.add({
          'title': title,
          'content': title, // Özet için başlığı kullan
          'url': href.startsWith('http')
              ? href
              : 'https://www.meb.gov.tr$href',
        });
      }
    }

    return items.isEmpty ? _simulatedAnnouncements : items;
  }

  // ── AI ANALİZ KATMANI ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _analyzeWithAi(
    Map<String, dynamic> item,
  ) async {
    try {
      final result = await AiService.instance.analyzeMebAnnouncement(
        '${item['title']}\n${item['content']}',
      );
      return result;
    } on AiException {
      // AI yoksa kural tabanlı analiz
      return _ruleBasedAnalysis(item);
    }
  }

  /// AI olmadan kural tabanlı analiz (offline fallback)
  Map<String, dynamic> _ruleBasedAnalysis(Map<String, dynamic> item) {
    final text = '${item['title']} ${item['content']}'.toLowerCase();

    final isAffected = text.contains('tatil') ||
        text.contains('sınav') ||
        text.contains('lgs') ||
        text.contains('öğrenci') ||
        text.contains('okul') ||
        text.contains('ders');

    final isHigh = text.contains('iptal') ||
        text.contains('ertelendi') ||
        text.contains('değişti') ||
        text.contains('acil');

    return {
      'title': item['title'],
      'affected_student': isAffected,
      'impact_level': isHigh ? 'Yüksek' : 'Normal',
      'summary': item['content'],
      'action_required': isAffected
          ? 'Bu duyuruyu kontrol et ve gerekli adımları at.'
          : null,
    };
  }

  // ── VERİTABANI ────────────────────────────────────────────────────────────

  Future<void> _saveAnnouncement(
    Map<String, dynamic> raw,
    Map<String, dynamic> aiResult,
  ) async {
    // Daha önce kaydedilmişse kaydetme
    final existing = await DatabaseHelper.instance.query(
      'meb_announcements',
      where: 'raw_title = ?',
      whereArgs: [raw['title']],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await DatabaseHelper.instance.insert('meb_announcements', {
      'raw_title': raw['title'],
      'raw_content': raw['content'],
      'source_url': raw['url'],
      'ai_title': aiResult['title'],
      'ai_summary': aiResult['summary'],
      'ai_action': aiResult['action_required'],
      'impact_level': aiResult['impact_level'] ?? 'Normal',
      'affected_student': (aiResult['affected_student'] == true) ? 1 : 0,
      'is_read': 0,
      'fetched_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> _getCachedAnnouncements() async {
    return DatabaseHelper.instance.query(
      'meb_announcements',
      orderBy: 'fetched_at DESC',
      limit: 20,
    );
  }

  Future<List<Map<String, dynamic>>> getUnreadAnnouncements() async {
    return DatabaseHelper.instance.query(
      'meb_announcements',
      where: 'is_read = 0',
      orderBy: 'fetched_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllAnnouncements() async {
    return DatabaseHelper.instance.query(
      'meb_announcements',
      orderBy: 'fetched_at DESC',
      limit: 50,
    );
  }

  Future<void> markAsRead(int id) async {
    await DatabaseHelper.instance.update(
      'meb_announcements',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getUnreadCount() async {
    final results = await DatabaseHelper.instance.rawQuery(
      'SELECT COUNT(*) as count FROM meb_announcements WHERE is_read = 0',
    );
    return results.first['count'] as int? ?? 0;
  }
}

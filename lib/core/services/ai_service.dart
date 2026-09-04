import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Tüm AI isteklerini yöneten merkezi servis.
/// OpenRouter ve doğrudan Gemini API'yi destekler.
class AiService {
  static final AiService instance = AiService._();
  AiService._();

  static const _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── ANA İSTEK METODU ───────────────────────────────────────────────────────

  /// Herhangi bir görev için AI'ya istek gönderir.
  /// [systemPrompt] — AI'ya rolünü tanımlayan sistem mesajı
  /// [userPrompt]   — Kullanıcının / uygulamanın isteği
  /// [expectJson]   — true ise yanıtı JSON olarak parse eder
  Future<dynamic> ask({
    required String systemPrompt,
    required String userPrompt,
    bool expectJson = true,
  }) async {
    final provider = await SecureStorageService.instance.getAiProvider();
    final apiKey   = await SecureStorageService.instance.getActiveApiKey();
    final model    = await SecureStorageService.instance.getAiModel();

    if (apiKey == null || apiKey.isEmpty) {
      throw AiException('API anahtarı bulunamadı. Lütfen Ayarlar\'dan girin.');
    }

    try {
      final raw = provider == 'gemini'
          ? await _callGemini(apiKey, model, systemPrompt, userPrompt)
          : await _callOpenRouter(apiKey, model, systemPrompt, userPrompt);

      if (!expectJson) return raw;

      // JSON temizleme: markdown code block varsa soyundur
      final cleaned = _stripMarkdown(raw);
      return jsonDecode(cleaned);
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('AI yanıtı işlenemedi: $e');
    }
  }

  // ── OPENROUTER ─────────────────────────────────────────────────────────────

  Future<String> _callOpenRouter(
    String apiKey,
    String model,
    String system,
    String user,
  ) async {
    final response = await http
        .post(
          Uri.parse(_openRouterUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'nexusedu-ultra',
            'X-Title': 'NexusEdu Ultra',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user',   'content': user},
            ],
            'temperature': 0.3,
            'max_tokens': 2048,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else if (response.statusCode == 401) {
      throw AiException('Geçersiz API anahtarı. Lütfen kontrol edin.');
    } else if (response.statusCode == 429) {
      throw AiException('API limit aşıldı. Biraz bekleyip tekrar dene.');
    } else {
      throw AiException('OpenRouter hatası: ${response.statusCode}');
    }
  }

  // ── GEMINI DIRECT ──────────────────────────────────────────────────────────

  Future<String> _callGemini(
    String apiKey,
    String model,
    String system,
    String user,
  ) async {
    // Gemini için model adından 'google/' prefix'ini kaldır
    final geminiModel = model.replaceFirst('google/', '');
    final url =
        '$_geminiBaseUrl/$geminiModel:generateContent?key=$apiKey';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [{'text': system}]
            },
            'contents': [
              {
                'parts': [{'text': user}]
              }
            ],
            'generationConfig': {
              'temperature': 0.3,
              'maxOutputTokens': 2048,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else if (response.statusCode == 400) {
      throw AiException('Gemini: Geçersiz istek. API anahtarını kontrol et.');
    } else {
      throw AiException('Gemini hatası: ${response.statusCode}');
    }
  }

  // ── GÖREV BAZLI YARDIMCILAR ────────────────────────────────────────────────

  /// MEB duyurusunu analiz eder
  Future<Map<String, dynamic>> analyzeMebAnnouncement(String rawText) async {
    return await ask(
      systemPrompt: '''
Sen bir Türk eğitim sistemi ve MEB analisti uzmanısın.
Gelen MEB duyuru metnini analiz et ve SADECE şu JSON formatında yanıt ver, başka hiçbir şey yazma:
{
  "title": "kısa başlık",
  "affected_student": true/false,
  "impact_level": "Düşük/Orta/Yüksek/Kritik",
  "summary": "öğrenciyi nasıl etkilediği",
  "action_required": "öğrencinin yapması gereken eylem"
}''',
      userPrompt: 'Analiz et: $rawText',
    ) as Map<String, dynamic>;
  }

  /// AI dinamik çalışma programı üretir
  Future<List<dynamic>> generateStudyPlan({
    required List<String> weakSubjects,
    required String examDate,
    required List<Map<String, dynamic>> freeSlots,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir Türk ortaokul öğrencisi için kişiselleştirilmiş çalışma programı oluşturan eğitim koçusun.
SADECE şu JSON array formatında yanıt ver:
[
  {
    "date": "YYYY-MM-DD",
    "subject": "Ders adı",
    "task": "Yapılacak görev",
    "duration_min": 30,
    "priority": 1-5
  }
]''',
      userPrompt: '''
Zayıf dersler: ${weakSubjects.join(', ')}
Sınav tarihi: $examDate
Boş zaman dilimleri: ${jsonEncode(freeSlots)}
Bugünden sınav tarihine kadar günlük mikro-görevler oluştur.''',
    ) as List<dynamic>;
  }

  /// Not hedef analizi yapar
  Future<Map<String, dynamic>> analyzeGradeTarget({
    required String subject,
    required double currentAverage,
    required double targetAverage,
    required int remainingExams,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir not analizi uzmanısın. Türk ortaokul not sistemine göre hesaplama yap.
SADECE JSON formatında yanıt ver:
{
  "needed_score": 0-100,
  "is_achievable": true/false,
  "message": "motivasyonel mesaj",
  "tip": "çalışma tavsiyesi"
}''',
      userPrompt: '''
Ders: $subject
Mevcut ortalama: $currentAverage
Hedef ortalama: $targetAverage
Kalan sınav sayısı: $remainingExams''',
    ) as Map<String, dynamic>;
  }

  /// Ödev Eisenhower matrisi analizi
  Future<Map<String, dynamic>> classifyHomework({
    required String title,
    required String dueDate,
    required String subject,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir verimlilik uzmanısın. Eisenhower matrisine göre ödevleri sınıflandır.
Quadrant değerleri: "do_now" (Acil+Önemli), "plan" (Önemli+Acil Değil), 
"delegate" (Acil+Önemsiz), "eliminate" (Acil Değil+Önemsiz)
SADECE JSON formatında yanıt ver:
{
  "quadrant": "do_now/plan/delegate/eliminate",
  "urgency": 1-5,
  "importance": 1-5,
  "reason": "neden bu kategoride"
}''',
      userPrompt: '''
Ödev: $title
Ders: $subject
Son teslim: $dueDate
Bugün: ${DateTime.now().toIso8601String().split('T')[0]}''',
    ) as Map<String, dynamic>;
  }

  /// Flashcard üretir
  Future<List<dynamic>> generateFlashcards({
    required String subject,
    required String notes,
    int count = 10,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir eğitim içerik uzmanısın. Türk ortaokul müfredatına uygun flashcard üret.
SADECE JSON array formatında yanıt ver:
[
  {
    "question": "soru",
    "answer": "cevap"
  }
]''',
      userPrompt: '''
Ders: $subject
Ders notları: $notes
$count adet soru-cevap kartı üret. Sorular kısa ve net olsun.''',
    ) as List<dynamic>;
  }

  /// Bütçe analizi
  Future<Map<String, dynamic>> analyzeBudget({
    required double dailyAllowance,
    required double spentToday,
    required double spentThisWeek,
    required double weeklyLimit,
    required List<Map<String, dynamic>> recentExpenses,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir gençlik finansal danışmanısın. Türk lirası cinsinden bütçe analizi yap.
SADECE JSON formatında yanıt ver:
{
  "status": "iyi/dikkatli/kritik",
  "warning": "uyarı mesajı veya null",
  "tip": "tasarruf tavsiyesi",
  "days_until_broke": gün sayısı veya null
}''',
      userPrompt: '''
Günlük harçlık: $dailyAllowance TL
Bugün harcanan: $spentToday TL
Bu hafta harcanan: $spentThisWeek TL
Haftalık limit: $weeklyLimit TL
Son harcamalar: ${jsonEncode(recentExpenses)}''',
    ) as Map<String, dynamic>;
  }

  /// Burnout analizi
  Future<Map<String, dynamic>> analyzeBurnout({
    required int energyLevel,
    required int stressLevel,
    required int motivation,
    required int sleepQuality,
  }) async {
    return await ask(
      systemPrompt: '''
Sen bir öğrenci mental sağlığı uzmanısın. Tükenmişlik riskini değerlendir.
SADECE JSON formatında yanıt ver:
{
  "burnout_risk": "Düşük/Orta/Yüksek",
  "score": 0-100,
  "analysis": "detaylı analiz",
  "recommendations": ["öneri1", "öneri2", "öneri3"],
  "urgent_action": "acil eylem veya null"
}''',
      userPrompt: '''
Enerji seviyesi (1-10): $energyLevel
Stres seviyesi (1-10): $stressLevel
Motivasyon (1-10): $motivation
Uyku kalitesi (1-10): $sleepQuality''',
    ) as Map<String, dynamic>;
  }

  // ── YARDIMCI ──────────────────────────────────────────────────────────────

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
  }
}

class AiException implements Exception {
  final String message;
  AiException(this.message);

  @override
  String toString() => 'AiException: $message';
}

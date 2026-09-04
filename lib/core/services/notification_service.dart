import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelMeb = AndroidNotificationChannel(
    'meb_alerts',
    'MEB Duyuruları',
    description: 'Kritik MEB bildirimleri',
    importance: Importance.max,
    playSound: true,
  );

  static const _channelStudy = AndroidNotificationChannel(
    'study_reminders',
    'Çalışma Hatırlatıcıları',
    description: 'Pomodoro ve çalışma bildirimleri',
    importance: Importance.high,
  );

  static const _channelBudget = AndroidNotificationChannel(
    'budget_alerts',
    'Bütçe Uyarıları',
    description: 'Harcama limiti bildirimleri',
    importance: Importance.high,
  );

  static const _channelAbsence = AndroidNotificationChannel(
    'absence_alerts',
    'Devamsızlık Uyarıları',
    description: 'Devamsızlık sınır bildirimleri',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Kanalları kaydet
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelMeb);
    await androidPlugin?.createNotificationChannel(_channelStudy);
    await androidPlugin?.createNotificationChannel(_channelBudget);
    await androidPlugin?.createNotificationChannel(_channelAbsence);
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigator ile ilgili ekrana yönlendir
    // Deep link: response.payload
  }

  // ── MEB KRİTİK BİLDİRİM ───────────────────────────────────────────────────

  Future<void> showMebAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      1000,
      '🚨 MEB: $title',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelMeb.id,
          _channelMeb.name,
          importance: Importance.max,
          priority: Priority.max,
          color: const Color(0xFFFF1744),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
          ticker: 'MEB Duyurusu',
        ),
      ),
      payload: payload ?? 'meb',
    );
  }

  // ── POMODORO BİLDİRİMLERİ ─────────────────────────────────────────────────

  Future<void> showPomodoroComplete(String subjectName) async {
    await _plugin.show(
      2000,
      '✅ Pomodoro Tamamlandı!',
      '$subjectName için 25 dakika odaklandın. Harika iş! Mola zamanı.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelStudy.id,
          _channelStudy.name,
          importance: Importance.high,
          color: const Color(0xFF00E676),
        ),
      ),
      payload: 'pomodoro',
    );
  }

  Future<void> showBreakComplete() async {
    await _plugin.show(
      2001,
      '⚡ Mola Bitti!',
      'Tekrar odaklanma zamanı. Hadi başlayalım!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelStudy.id,
          _channelStudy.name,
          importance: Importance.high,
          color: const Color(0xFF00E676),
        ),
      ),
      payload: 'pomodoro_break',
    );
  }

  // ── ZAMANLANMIŞ ÖDEV HATIRLATICI ──────────────────────────────────────────

  Future<void> scheduleHomeworkReminder({
    required int id,
    required String homeworkTitle,
    required DateTime dueDateTime,
  }) async {
    final scheduledTime = tz.TZDateTime.from(
      dueDateTime.subtract(const Duration(hours: 24)),
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      '📚 Ödev Hatırlatıcı',
      '"$homeworkTitle" ödevi yarın teslim!',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelStudy.id,
          _channelStudy.name,
          importance: Importance.high,
          color: const Color(0xFF448AFF),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'homework_$id',
    );
  }

  // ── BÜTÇE UYARISI ─────────────────────────────────────────────────────────

  Future<void> showBudgetWarning({
    required String message,
    bool isCritical = false,
  }) async {
    await _plugin.show(
      3000,
      isCritical ? '🔴 Kritik Bütçe Uyarısı!' : '⚠️ Bütçe Uyarısı',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBudget.id,
          _channelBudget.name,
          importance: isCritical ? Importance.max : Importance.high,
          color: isCritical
              ? const Color(0xFFFF1744)
              : const Color(0xFFFFAB40),
        ),
      ),
      payload: 'budget',
    );
  }

  // ── DEVAMSIZLIK UYARISI ───────────────────────────────────────────────────

  Future<void> showAbsenceWarning({
    required String subjectName,
    required int currentAbsences,
    required int maxAbsences,
  }) async {
    final remaining = maxAbsences - currentAbsences;
    await _plugin.show(
      4000,
      '🚨 Devamsızlık Uyarısı: $subjectName',
      'Sadece $remaining günlük devamsızlık hakkın kaldı! Dikkat et.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelAbsence.id,
          _channelAbsence.name,
          importance: Importance.max,
          color: const Color(0xFFFF1744),
        ),
      ),
      payload: 'absence',
    );
  }

  // ── BURNOUT UYARISI ───────────────────────────────────────────────────────

  Future<void> showBurnoutAlert(String recommendation) async {
    await _plugin.show(
      5000,
      '🧠 Tükenmişlik Riski Tespit Edildi',
      recommendation,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelStudy.id,
          _channelStudy.name,
          importance: Importance.high,
          color: const Color(0xFFE040FB),
          styleInformation: BigTextStyleInformation(recommendation),
        ),
      ),
      payload: 'burnout',
    );
  }

  // ── HAFTALIK BURNOUT ANKETİ ───────────────────────────────────────────────

  Future<void> scheduleWeeklyBurnoutSurvey() async {
    // Her Pazar 20:00'de hatırlatıcı
    await _plugin.periodicallyShow(
      6000,
      '💙 Haftalık Durum Kontrolü',
      'Bu haftaki enerji ve stres seviyeni güncellemek ister misin?',
      RepeatInterval.weekly,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelStudy.id,
          _channelStudy.name,
          importance: Importance.defaultImportance,
          color: const Color(0xFF7C4DFF),
        ),
      ),
      payload: 'burnout_survey',
    );
  }

  Future<void> cancelNotification(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

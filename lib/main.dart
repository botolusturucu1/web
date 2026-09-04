import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/notification_service.dart';
import 'core/services/meb_intelligence_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // OLED için saf siyah durum çubuğu
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Yalnızca dikey mod
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Türkçe tarih formatı
  await initializeDateFormatting('tr_TR', null);

  // Bildirim servisi
  await NotificationService.instance.initialize();
  await NotificationService.instance.scheduleWeeklyBurnoutSurvey();

  // Arka planda MEB duyurularını başlat (sessiz)
  MebIntelligenceService.instance.fetchAndAnalyze().ignore();

  runApp(const NexusEduApp());
}

class NexusEduApp extends StatelessWidget {
  const NexusEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexusEdu Ultra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

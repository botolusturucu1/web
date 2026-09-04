# NexusEdu Ultra — APK Derleme Talimatları

## Gereksinimler
- Flutter SDK 3.x (https://flutter.dev/docs/get-started/install)
- Android Studio veya VS Code
- Android SDK (API 21+)
- JDK 17+

## Kurulum

```bash
# 1. Proje dizinine gir
cd nexusedu_ultra

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Kod üretimi (gerekirse)
flutter pub run build_runner build

# 4. Debug APK oluştur
flutter build apk --debug

# 5. Release APK oluştur (telefona kurmak için)
flutter build apk --release

# APK konumu:
# build/app/outputs/flutter-apk/app-release.apk
```

## Telefona Kurulum

```bash
# USB ile bağlıyken
flutter install

# Ya da APK dosyasını telefona kopyalayıp
# "Bilinmeyen kaynaklardan kurulum"u aktifleştirerek kur
```

## Önemli Notlar

1. **API Key**: İlk açılışta Ayarlar > API Key kısmına
   OpenRouter veya Gemini API key gir.
   - OpenRouter: https://openrouter.ai (ücretsiz)
   - Gemini: https://aistudio.google.com (ücretsiz)

2. **Offline Çalışma**: API key olmadan da tüm temel özellikler
   (not takibi, ödev, pomodoro, bütçe, devamsızlık) çalışır.
   Sadece AI özellikleri API key gerektirir.

3. **Veri**: Tüm veriler cihazda SQLite'ta saklanır.
   İnternet sadece AI ve MEB duyuruları için kullanılır.

4. **OLED**: Saf #000000 siyah zemin, OLED ekranlarda
   pil tasarrufu sağlar.

## Proje Yapısı

```
lib/
├── main.dart                          # Uygulama girişi
├── core/
│   ├── database/
│   │   └── database_helper.dart       # SQLite şeması + CRUD
│   ├── services/
│   │   ├── ai_service.dart            # AI wrapper (OpenRouter + Gemini)
│   │   ├── secure_storage_service.dart # Encrypted API key saklama
│   │   ├── notification_service.dart  # Yerel bildirimler
│   │   └── meb_intelligence_service.dart # MEB scraper + AI analiz
│   └── theme/
│       └── app_theme.dart             # OLED siyah tema
└── features/
    ├── home/           # Ana sayfa + navigasyon
    ├── study_plan/     # Modül A: AI Çalışma Programı
    ├── grades/         # Modül B: Not + Hedef Simülatörü
    ├── homework/       # Modül C: Eisenhower Matrisi
    ├── flashcards/     # Modül D: Spaced Repetition
    ├── pomodoro/       # Modül E: Pomodoro + Analitik
    ├── budget/         # Modül F: Bütçe Takibi
    ├── absence/        # Modül G: Devamsızlık
    ├── burnout/        # Modül H: Stres Monitörü
    ├── meb/            # MEB Duyuruları
    └── settings/       # API Key Yönetimi
```

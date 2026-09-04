import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API anahtarlarını ve hassas verileri şifreleyerek saklar.
/// flutter_secure_storage → Android Keystore üzerinden AES-256 şifrelemesi.
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Anahtar sabitleri
  static const _kOpenRouterKey = 'nexus_openrouter_api_key';
  static const _kGeminiKey     = 'nexus_gemini_api_key';
  static const _kAiProvider    = 'nexus_ai_provider'; // 'openrouter' | 'gemini'
  static const _kAiModel       = 'nexus_ai_model';

  // ── OKUMA ──────────────────────────────────────────────────

  Future<String?> getOpenRouterKey() =>
      _storage.read(key: _kOpenRouterKey);

  Future<String?> getGeminiKey() =>
      _storage.read(key: _kGeminiKey);

  Future<String> getAiProvider() async =>
      (await _storage.read(key: _kAiProvider)) ?? 'openrouter';

  Future<String> getAiModel() async =>
      (await _storage.read(key: _kAiModel)) ?? 'google/gemini-2.5-flash';

  /// Aktif sağlayıcıya göre doğru anahtarı döner.
  Future<String?> getActiveApiKey() async {
    final provider = await getAiProvider();
    if (provider == 'gemini') return getGeminiKey();
    return getOpenRouterKey();
  }

  // ── YAZMA ──────────────────────────────────────────────────

  Future<void> saveOpenRouterKey(String key) =>
      _storage.write(key: _kOpenRouterKey, value: key.trim());

  Future<void> saveGeminiKey(String key) =>
      _storage.write(key: _kGeminiKey, value: key.trim());

  Future<void> saveAiProvider(String provider) =>
      _storage.write(key: _kAiProvider, value: provider);

  Future<void> saveAiModel(String model) =>
      _storage.write(key: _kAiModel, value: model);

  // ── SİLME ──────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();

  Future<void> clearApiKeys() async {
    await _storage.delete(key: _kOpenRouterKey);
    await _storage.delete(key: _kGeminiKey);
  }

  // ── DOĞRULAMA ──────────────────────────────────────────────

  Future<bool> hasValidKey() async {
    final key = await getActiveApiKey();
    return key != null && key.length > 10;
  }
}

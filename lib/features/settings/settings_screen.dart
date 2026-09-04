import 'package:flutter/material.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _openRouterCtrl = TextEditingController();
  final _geminiCtrl = TextEditingController();
  String _selectedProvider = 'openrouter';
  String _selectedModel = 'google/gemini-2.5-flash';
  bool _loading = true;
  bool _saving = false;
  bool _showOpenRouterKey = false;
  bool _showGeminiKey = false;

  static const _providers = [
    {'value': 'openrouter', 'label': 'OpenRouter', 'desc': 'Çoklu model erişimi'},
    {'value': 'gemini', 'label': 'Google Gemini', 'desc': 'Doğrudan Gemini API'},
  ];

  static const _models = [
    'google/gemini-2.5-flash',
    'google/gemini-2.0-flash-exp',
    'anthropic/claude-3.5-haiku',
    'meta-llama/llama-3.1-8b-instruct:free',
    'openai/gpt-4o-mini',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final orKey = await SecureStorageService.instance.getOpenRouterKey();
    final gemKey = await SecureStorageService.instance.getGeminiKey();
    final provider = await SecureStorageService.instance.getAiProvider();
    final model = await SecureStorageService.instance.getAiModel();

    setState(() {
      if (orKey != null) _openRouterCtrl.text = orKey;
      if (gemKey != null) _geminiCtrl.text = gemKey;
      _selectedProvider = provider;
      _selectedModel = model;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      if (_openRouterCtrl.text.isNotEmpty) {
        await SecureStorageService.instance.saveOpenRouterKey(_openRouterCtrl.text);
      }
      if (_geminiCtrl.text.isNotEmpty) {
        await SecureStorageService.instance.saveGeminiKey(_geminiCtrl.text);
      }
      await SecureStorageService.instance.saveAiProvider(_selectedProvider);
      await SecureStorageService.instance.saveAiModel(_selectedModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 18),
                SizedBox(width: 8),
                Text('Ayarlar kaydedildi!'),
              ],
            ),
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _clearApiKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('API Anahtarlarını Sil',
            style: TextStyle(color: AppTheme.white)),
        content: Text('Tüm API anahtarları silinecek. Emin misin?',
            style: TextStyle(color: AppTheme.white.withOpacity(0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textDim))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SecureStorageService.instance.clearApiKeys();
      setState(() {
        _openRouterCtrl.clear();
        _geminiCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Ayarlar',
            style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: AppTheme.neonGreen, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Kaydet',
                  style: TextStyle(color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // AI Sağlayıcı
                _SectionHeader(title: '🤖 AI Sağlayıcı'),
                const SizedBox(height: 12),
                ...(_providers.map((p) => _ProviderTile(
                  value: p['value']!,
                  label: p['label']!,
                  desc: p['desc']!,
                  selected: _selectedProvider == p['value'],
                  onTap: () => setState(() => _selectedProvider = p['value']!),
                ))),

                const SizedBox(height: 24),

                // Model seçimi
                _SectionHeader(title: '🧠 AI Modeli'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.white.withOpacity(0.1)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardColor,
                    underline: const SizedBox(),
                    style: const TextStyle(color: AppTheme.white, fontSize: 13),
                    items: _models.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedModel = v!),
                  ),
                ),

                const SizedBox(height: 24),

                // OpenRouter API Key
                _SectionHeader(title: '🔑 OpenRouter API Key'),
                const SizedBox(height: 8),
                Text(
                  'openrouter.ai adresinden ücretsiz key alabilirsin.',
                  style: TextStyle(
                      color: AppTheme.white.withOpacity(0.4), fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _openRouterCtrl,
                  obscureText: !_showOpenRouterKey,
                  style: const TextStyle(color: AppTheme.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'sk-or-...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showOpenRouterKey ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textDim, size: 18,
                      ),
                      onPressed: () => setState(
                          () => _showOpenRouterKey = !_showOpenRouterKey),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Gemini API Key
                _SectionHeader(title: '🔑 Google Gemini API Key'),
                const SizedBox(height: 8),
                Text(
                  'aistudio.google.com adresinden ücretsiz key alabilirsin.',
                  style: TextStyle(
                      color: AppTheme.white.withOpacity(0.4), fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _geminiCtrl,
                  obscureText: !_showGeminiKey,
                  style: const TextStyle(color: AppTheme.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'AIza...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showGeminiKey ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textDim, size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showGeminiKey = !_showGeminiKey),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Güvenlik notu
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.neonGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppTheme.neonGreen, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'API anahtarların Android Keystore ile şifrelenmiş '
                          'olarak saklanır. Hiçbir zaman sunucuya gönderilmez.',
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.6),
                              fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Kaydet butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSettings,
                    child: const Text('Ayarları Kaydet',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 12),

                // Sil butonu
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _clearApiKeys,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.neonRed.withOpacity(0.4)),
                      foregroundColor: AppTheme.neonRed,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('API Anahtarlarını Sil'),
                  ),
                ),

                const SizedBox(height: 40),

                // Uygulama hakkında
                Center(
                  child: Column(
                    children: [
                      Text('NexusEdu Ultra v1.0.0',
                          style: TextStyle(
                              color: AppTheme.white.withOpacity(0.3),
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('OLED • Offline-First • SQLite • AI Powered',
                          style: TextStyle(
                              color: AppTheme.neonGreen.withOpacity(0.5),
                              fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(color: AppTheme.white,
            fontSize: 15, fontWeight: FontWeight.bold));
  }
}

class _ProviderTile extends StatelessWidget {
  final String value;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.value, required this.label, required this.desc,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.neonGreen.withOpacity(0.08) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.neonGreen : AppTheme.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    color: selected ? AppTheme.neonGreen : AppTheme.white,
                    fontWeight: FontWeight.bold, fontSize: 14,
                  )),
                  Text(desc, style: TextStyle(
                      color: AppTheme.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.neonGreen, size: 20),
          ],
        ),
      ),
    );
  }
}

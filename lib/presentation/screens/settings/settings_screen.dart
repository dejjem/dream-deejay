import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/deezer_api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/secure_storage.dart';
import '../../providers/providers.dart';
import 'package:dream_deejay/data/services/ai_dj_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _deezerAppIdController = TextEditingController();
  final _deezerAppSecretController = TextEditingController();
  final _openWeatherController = TextEditingController();
  final _newsApiController = TextEditingController();
  final _llmApiController = TextEditingController();
  bool _useGemini = false;
  bool _autoTriggerDj = false;
  bool _includeWeather = true;
  bool _includeNews = true;
  bool _showSecrets = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsProvider);
    _deezerAppIdController.text = settings.deezerAppId ?? '';
    _deezerAppSecretController.text = settings.deezerAppSecret ?? '';
    _openWeatherController.text = settings.openWeatherApiKey ?? '';
    _newsApiController.text = settings.newsApiKey ?? '';
    _llmApiController.text = settings.llmApiKey ?? '';
    setState(() {
      _useGemini = settings.useGemini;
      _autoTriggerDj = settings.autoTriggerDj;
      _includeWeather = settings.includeWeather;
      _includeNews = settings.includeNews;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final storage = getIt<SecureStorage>();

    // Save API keys to secure storage
    await storage.write('api_deezer_app_id', _deezerAppIdController.text.trim());
    await storage.write('api_deezer_app_secret', _deezerAppSecretController.text.trim());
    await storage.write('api_open_weather', _openWeatherController.text.trim());
    await storage.write('api_news_api', _newsApiController.text.trim());
    await storage.write('api_llm', _llmApiController.text.trim());

    ref.read(settingsProvider.notifier).updateApiKeys(
      deezerAppId: _deezerAppIdController.text.trim(),
      deezerAppSecret: _deezerAppSecretController.text.trim(),
      openWeatherApiKey: _openWeatherController.text.trim(),
      newsApiKey: _newsApiController.text.trim(),
      llmApiKey: _llmApiController.text.trim(),
      useGemini: _useGemini,
    );

    ref.read(settingsProvider.notifier).updateDjSettings(
      autoTriggerDj: _autoTriggerDj,
      includeWeather: _includeWeather,
      includeNews: _includeNews,
    );

    // Configure AI DJ service
    final aiDj = getIt<AiDjService>();
    aiDj.configure(
      openWeatherApiKey: _openWeatherController.text.trim(),
      newsApiKey: _newsApiController.text.trim(),
      llmApiKey: _llmApiController.text.trim(),
      useGemini: _useGemini,
      autoTrigger: _autoTriggerDj,
      includeWeather: _includeWeather,
      includeNews: _includeNews,
    );

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), backgroundColor: AppTheme.bgCard),
      );
    }
  }

  Future<void> _loginDeezer() async {
    final appId = _deezerAppIdController.text.trim();
    if (appId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your Deezer App ID first'), backgroundColor: AppTheme.bgCard),
      );
      return;
    }

    final client = getIt<DeezerApiClient>();
    final authUrl = client.getAuthorizationUrl(appId);

    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _DeezerWebViewAuth(url: authUrl),
      ),
    );

    if (result != null && mounted) {
      // Exchange code for token
      setState(() => _saving = true);
      try {
        final token = await client.exchangeCodeForToken(
          appId,
          _deezerAppSecretController.text.trim(),
          result,
        );
        final storage = getIt<SecureStorage>();
        await storage.saveDeezerToken(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken,
          expiresIn: token.expiresIn,
        );
        client.setAccessToken(token.accessToken);
        final user = await client.getMe();
        await storage.saveDeezerUserId(user.id);
        ref.invalidate(authStateProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logged in as ${user.name}'), backgroundColor: AppTheme.bgCard),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
      setState(() => _saving = false);
    }
  }

  Future<void> _logoutDeezer() async {
    final storage = getIt<SecureStorage>();
    await storage.clearDeezerTokens();
    getIt<DeezerApiClient>().clearAccessToken();
    ref.invalidate(authStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Deezer Account
          _SectionHeader(title: 'Deezer Account'),
          const SizedBox(height: 8),
          _ApiKeyField(
            label: 'Deezer App ID',
            controller: _deezerAppIdController,
            hint: 'From developers.deezer.com',
          ),
          const SizedBox(height: 12),
          _ApiKeyField(
            label: 'Deezer App Secret',
            controller: _deezerAppSecretController,
            hint: 'From developers.deezer.com',
            isSecret: !_showSecrets,
          ),
          const SizedBox(height: 12),
          authState.when(
            data: (loggedIn) => loggedIn
                ? OutlinedButton.icon(
                    onPressed: _logoutDeezer,
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnect Deezer'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  )
                : ElevatedButton.icon(
                    onPressed: _loginDeezer,
                    icon: const Icon(Icons.login),
                    label: const Text('Connect Deezer'),
                  ),
            loading: () => const CircularProgressIndicator(color: AppTheme.accentMagenta),
            error: (_, __) => ElevatedButton.icon(
              onPressed: _loginDeezer,
              icon: const Icon(Icons.login),
              label: const Text('Connect Deezer'),
            ),
          ),
          const SizedBox(height: 32),

          // AI DJ Settings
          _SectionHeader(title: 'AI DJ'),
          const SizedBox(height: 8),
          _ApiKeyField(
            label: 'OpenWeatherMap API Key',
            controller: _openWeatherController,
            hint: 'openweathermap.org/api',
            isSecret: !_showSecrets,
          ),
          const SizedBox(height: 12),
          _ApiKeyField(
            label: 'NewsAPI Key',
            controller: _newsApiController,
            hint: 'newsapi.org',
            isSecret: !_showSecrets,
          ),
          const SizedBox(height: 12),
          _ApiKeyField(
            label: 'LLM API Key (OpenAI or Gemini)',
            controller: _llmApiController,
            hint: 'OpenAI or Gemini key',
            isSecret: !_showSecrets,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Use Gemini instead of OpenAI', style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Toggle between GPT-4o-mini and Gemini Flash',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            value: _useGemini,
            onChanged: (v) => setState(() => _useGemini = v),
          ),
          const Divider(color: AppTheme.divider),
          SwitchListTile(
            title: const Text('Auto-trigger DJ between tracks', style: TextStyle(color: AppTheme.textPrimary)),
            value: _autoTriggerDj,
            onChanged: (v) => setState(() => _autoTriggerDj = v),
          ),
          SwitchListTile(
            title: const Text('Include weather in DJ announcement',
                style: TextStyle(color: AppTheme.textPrimary)),
            value: _includeWeather,
            onChanged: (v) => setState(() => _includeWeather = v),
          ),
          SwitchListTile(
            title: const Text('Include news in DJ announcement',
                style: TextStyle(color: AppTheme.textPrimary)),
            value: _includeNews,
            onChanged: (v) => setState(() => _includeNews = v),
          ),
          const SizedBox(height: 32),

          // Show/hide secrets toggle
          SwitchListTile(
            title: const Text('Show API keys', style: TextStyle(color: AppTheme.textPrimary)),
            value: _showSecrets,
            onChanged: (v) => setState(() => _showSecrets = v),
          ),
          const SizedBox(height: 16),

          // Save button
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Settings'),
          ),
          const SizedBox(height: 48),
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
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.accentMagenta,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isSecret;

  const _ApiKeyField({
    required this.label,
    required this.controller,
    required this.hint,
    this.isSecret = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isSecret,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: hint,
        helperStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _DeezerWebViewAuth extends StatefulWidget {
  final String url;
  const _DeezerWebViewAuth({required this.url});

  @override
  State<_DeezerWebViewAuth> createState() => _DeezerWebViewAuthState();
}

class _DeezerWebViewAuthState extends State<_DeezerWebViewAuth> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest navReq) {
          final uri = Uri.parse(navReq.url);
          if (uri.toString().startsWith(ApiConstants.deezerRedirectUri)) {
            final code = uri.queryParameters['code'];
            Navigator.of(context).pop(code);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deezer Login'),
        backgroundColor: AppTheme.bgCard,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirect to settings for Deezer login
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: AppTheme.accentMagenta),
            const SizedBox(height: 24),
            const Text(
              'Dream DeeJay',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configure API Keys'),
            ),
          ],
        ),
      ),
    );
  }
}
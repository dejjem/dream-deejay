# Dream DeeJay

Native Android music player with AI DJ announcements — built with Flutter.

## Features

- **Music Playback** via Deezer API (Premium+ required for full streaming)
- **AI DJ** — tap the floating mic button on Now Playing screen to hear a radio-style announcement with:
  - LLM-generated intro for the next queued track (GPT-4o-mini or Gemini Flash)
  - Current weather at your device location (OpenWeatherMap)
  - Top news headline for your region (NewsAPI)
- **Queue management** with drag-to-reorder and swipe-to-remove
- **Offline mode** — save tracks for offline playback
- **Settings** — all API keys entered at runtime (no hardcoding)

## Architecture

```
lib/
├── core/
│   ├── api/          # DeezerApiClient
│   ├── constants/    # API base URLs
│   ├── di/           # GetIt dependency injection
│   ├── theme/        # AppTheme (dark, neon magenta/purple/cyan)
│   └── utils/        # SecureStorage (encrypted)
├── data/
│   ├── models/       # DeezerTrack, DeezerAlbum, etc. (JSON serializable)
│   └── services/     # AudioHandler (Media3/ExoPlayer), AiDjService (TTS + APIs)
└── presentation/
    ├── providers/    # Riverpod state (queue, settings, auth)
    ├── screens/      # Home, Search, Queue, Library, NowPlaying, Settings
    └── widgets/       # TrackTile, SectionHeader, AppShell, MiniPlayer
```

## API Keys Required

Configure these at runtime in the **Settings** screen:

| Service | Purpose | Get key at |
|---|---|---|
| Deezer App ID + Secret | OAuth login + API access | [developers.deezer.com](https://developers.deezer.com) |
| OpenWeatherMap | Weather in DJ announcements | [openweathermap.org/api](https://openweathermap.org/api) |
| NewsAPI | Headlines in DJ announcements | [newsapi.org](https://newsapi.org) |
| OpenAI **or** Gemini | LLM track introductions | [platform.openai.com](https://platform.openai.com) or [aistudio.google.com](https://aistudio.google.com) |

## Building

### Local (requires Flutter SDK + Android SDK)

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### GitHub Actions (CI/CD)

Push to `main` or open a PR — the workflow at `.github/workflows/build.yml` automatically:
1. Installs Flutter + Android SDK
2. Runs `flutter analyze`
3. Builds a debug APK (validates shell)
4. Generates code (json_serializable)
5. Builds a **release APK**
6. Uploads both as workflow artifacts

For a **signed** APK, set these repository **Variables** and **Secrets**:

| Variable/Secret | Value |
|---|---|
| `KEYSTORE_BASE64` (Variable) | Base64-encoded `.jks` keystore |
| `KEY_ALIAS` (Variable) | Your key alias |
| `KEYSTORE_PASSWORD` (Secret) | Keystore password |
| `KEY_PASSWORD` (Secret) | Key password |

## Permissions

```xml
INTERNET
ACCESS_FINE_LOCATION
ACCESS_COARSE_LOCATION
FOREGROUND_SERVICE
FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
WAKE_LOCK
POST_NOTIFICATIONS          <!-- Android 13+ -->
READ_EXTERNAL_STORAGE       <!-- API ≤ 32 -->
READ_MEDIA_AUDIO            <!-- API ≥ 33 -->
```

## Tech Stack

| Concern | Solution |
|---|---|
| Framework | Flutter 3.22 / Dart |
| Audio | `just_audio` + `audio_service` (Media3/ExoPlayer) |
| HTTP | `dio` with auth interceptors |
| JSON | `json_serializable` + `json_annotation` |
| DI | `get_it` |
| State | `flutter_riverpod` |
| Images | `cached_network_image` |
| Storage | `flutter_secure_storage` (encrypted) |
| Location | `geolocator` |
| TTS | `flutter_tts` (Android native, no network TTS) |
| OAuth | `webview_flutter` + Deezer Authorization Code flow |
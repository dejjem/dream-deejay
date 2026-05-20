import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dream_deejay/data/models/deezer_models.dart';
import '../../core/utils/secure_storage.dart';
import '../../data/services/ai_dj_service.dart';
import '../../data/models/deezer_models.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final aiDjServiceProvider = Provider<AiDjService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AiDjService(storage);
});

// Auth state
final authStateProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final token = await storage.getDeezerAccessToken();
  return token != null && token.isNotEmpty;
});

// Settings state
class AppSettings {
  final String? deezerAppId;
  final String? deezerAppSecret;
  final String? openWeatherApiKey;
  final String? newsApiKey;
  final String? llmApiKey;
  final bool useGemini;
  final bool autoTriggerDj;
  final bool includeWeather;
  final bool includeNews;
  final int cacheSizeMb;

  AppSettings({
    this.deezerAppId,
    this.deezerAppSecret,
    this.openWeatherApiKey,
    this.newsApiKey,
    this.llmApiKey,
    this.useGemini = false,
    this.autoTriggerDj = false,
    this.includeWeather = true,
    this.includeNews = true,
    this.cacheSizeMb = 500,
  });

  AppSettings copyWith({
    String? deezerAppId,
    String? deezerAppSecret,
    String? openWeatherApiKey,
    String? newsApiKey,
    String? llmApiKey,
    bool? useGemini,
    bool? autoTriggerDj,
    bool? includeWeather,
    bool? includeNews,
    int? cacheSizeMb,
  }) {
    return AppSettings(
      deezerAppId: deezerAppId ?? this.deezerAppId,
      deezerAppSecret: deezerAppSecret ?? this.deezerAppSecret,
      openWeatherApiKey: openWeatherApiKey ?? this.openWeatherApiKey,
      newsApiKey: newsApiKey ?? this.newsApiKey,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      useGemini: useGemini ?? this.useGemini,
      autoTriggerDj: autoTriggerDj ?? this.autoTriggerDj,
      includeWeather: includeWeather ?? this.includeWeather,
      includeNews: includeNews ?? this.includeNews,
      cacheSizeMb: cacheSizeMb ?? this.cacheSizeMb,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings());

  void update(AppSettings settings) => state = settings;
  void updateApiKeys({
    String? deezerAppId,
    String? deezerAppSecret,
    String? openWeatherApiKey,
    String? newsApiKey,
    String? llmApiKey,
    bool? useGemini,
  }) {
    state = state.copyWith(
      deezerAppId: deezerAppId,
      deezerAppSecret: deezerAppSecret,
      openWeatherApiKey: openWeatherApiKey,
      newsApiKey: newsApiKey,
      llmApiKey: llmApiKey,
      useGemini: useGemini,
    );
  }
  void updateDjSettings({
    bool? autoTriggerDj,
    bool? includeWeather,
    bool? includeNews,
  }) {
    state = state.copyWith(
      autoTriggerDj: autoTriggerDj,
      includeWeather: includeWeather,
      includeNews: includeNews,
    );
  }
  void updateCacheSize(int mb) => state = state.copyWith(cacheSizeMb: mb);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

// Playback queue state
class QueueState {
  final List<Map<String, dynamic>> tracks;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;

  QueueState({
    this.tracks = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
  });

  QueueState copyWith({
    List<Map<String, dynamic>>? tracks,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return QueueState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic>? get currentTrack =>
      currentIndex < tracks.length ? tracks[currentIndex] : null;

  Map<String, dynamic>? get nextTrack =>
      currentIndex + 1 < tracks.length ? tracks[currentIndex + 1] : null;
}

class QueueNotifier extends StateNotifier<QueueState> {
  QueueNotifier() : super(QueueState());

  void setQueue(List<Map<String, dynamic>> tracks, {int initialIndex = 0}) {
    state = state.copyWith(tracks: tracks, currentIndex: initialIndex);
  }

  void addTrack(Map<String, dynamic> track) {
    state = state.copyWith(tracks: [...state.tracks, track]);
  }

  void insertTrack(int index, Map<String, dynamic> track) {
    final newTracks = List<Map<String, dynamic>>.from(state.tracks);
    newTracks.insert(index, track);
    state = state.copyWith(tracks: newTracks);
  }

  void removeTrack(int index) {
    final newTracks = List<Map<String, dynamic>>.from(state.tracks);
    if (index < newTracks.length) {
      newTracks.removeAt(index);
      int newIndex = state.currentIndex;
      if (index < state.currentIndex) {
        newIndex--;
      } else if (index == state.currentIndex) {
        newIndex = newIndex.clamp(0, newTracks.length - 1);
      }
      state = state.copyWith(tracks: newTracks, currentIndex: newIndex);
    }
  }

  void reorder(int oldIndex, int newIndex) {
    final newTracks = List<Map<String, dynamic>>.from(state.tracks);
    final item = newTracks.removeAt(oldIndex);
    newTracks.insert(newIndex, item);
    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      newCurrentIndex++;
    }
    state = state.copyWith(tracks: newTracks, currentIndex: newCurrentIndex);
  }

  void setCurrentIndex(int index) => state = state.copyWith(currentIndex: index);
  void setPlaying(bool playing) => state = state.copyWith(isPlaying: playing);
  void setPosition(Duration pos) => state = state.copyWith(position: pos);
  void setDuration(Duration? dur) => state = state.copyWith(duration: dur);
  void clear() => state = QueueState();
}

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>((ref) => QueueNotifier());

// Navigation
final currentNavIndexProvider = StateProvider<int>((ref) => 0);

// Search state
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFilterProvider = StateProvider<SearchFilter>((ref) => SearchFilter.tracks);
final searchResultsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
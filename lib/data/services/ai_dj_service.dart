import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/api_constants.dart';
import '../../core/utils/secure_storage.dart';

enum TtsState { playing, stopped, paused }

class AiDjService {
  final FlutterTts _tts = FlutterTts();
  final Dio _dio = Dio();
  final SecureStorage _secureStorage;
  bool _isInitialized = false;
  TtsState _ttsState = TtsState.stopped;

  // Settings
  bool autoTrigger = false;
  bool includeWeather = true;
  bool includeNews = true;
  String? _openWeatherApiKey;
  String? _newsApiKey;
  String? _llmApiKey;
  bool _useGemini = false;

  AiDjService(this._secureStorage);

  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // iOS specific
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );


    _isInitialized = true;
  }

  void configure({
    required String? openWeatherApiKey,
    required String? newsApiKey,
    required String? llmApiKey,
    required bool useGemini,
    required bool autoTrigger,
    required bool includeWeather,
    required bool includeNews,
  }) {
    _openWeatherApiKey = openWeatherApiKey;
    _newsApiKey = newsApiKey;
    _llmApiKey = llmApiKey;
    _useGemini = useGemini;
    this.autoTrigger = autoTrigger;
    this.includeWeather = includeWeather;
    this.includeNews = includeNews;
  }

  /// Fetch weather data for the device's current location
  Future<WeatherInfo?> fetchWeather(double lat, double lon) async {
    if (_openWeatherApiKey == null || _openWeatherApiKey!.isEmpty) return null;
    try {
      final resp = await _dio.get(
        '${ApiConstants.weatherApiBase}/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': _openWeatherApiKey,
          'units': 'metric',
        },
      );
      final data = resp.data;
      return WeatherInfo(
        temperature: (data['main']['temp'] as num).toDouble(),
        condition: data['weather'][0]['description'] as String,
        city: data['name'] as String,
        icon: data['weather'][0]['icon'] as String,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch top news headline for the given country code
  Future<NewsHeadline?> fetchTopHeadline(String countryCode) async {
    if (_newsApiKey == null || _newsApiKey!.isEmpty) return null;
    try {
      final resp = await _dio.get(
        '${ApiConstants.newsApiBase}/top-headlines',
        queryParameters: {
          'country': countryCode,
          'pageSize': 1,
          'apiKey': _newsApiKey,
        },
      );
      final articles = resp.data['articles'] as List?;
      if (articles == null || articles.isEmpty) return null;
      final article = articles[0];
      return NewsHeadline(
        title: article['title'] as String,
        source: article['source']?['name'] as String? ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Get current device location
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }

  /// Build the DJ announcement text for a given next track
  Future<DjAnnouncement> buildAnnouncement({
    required String trackTitle,
    required String artistName,
    required String? albumName,
    required int? bpm,
    required int? releaseYear,
    required String countryCode,
    double? lat,
    double? lon,
  }) async {
    String djIntro = '';

    // Part A: Music intro via LLM
    if (_llmApiKey != null && _llmApiKey!.isNotEmpty) {
      djIntro = await _generateMusicIntro(
        trackTitle: trackTitle,
        artistName: artistName,
        albumName: albumName,
        bpm: bpm,
        year: releaseYear,
      );
    } else {
      // Fallback to template
      djIntro = _buildTemplateIntro(
        trackTitle: trackTitle,
        artistName: artistName,
        bpm: bpm,
        year: releaseYear,
      );
    }

    // Part B: Weather
    String weatherText = '';
    if (includeWeather && lat != null && lon != null) {
      final weather = await fetchWeather(lat, lon);
      if (weather != null) {
        weatherText =
            "It's ${weather.temperature.round()}°C and ${weather.condition} in ${weather.city}.";
      }
    }

    // Part C: News
    String newsText = '';
    if (includeNews) {
      final headline = await fetchTopHeadline(countryCode);
      if (headline != null) {
        newsText = "And in the news today: ${headline.title}.";
      }
    }

    return DjAnnouncement(
      musicIntro: djIntro,
      weatherText: weatherText,
      newsText: newsText,
    );
  }

  Future<String> _generateMusicIntro({
    required String trackTitle,
    required String artistName,
    required String? albumName,
    required int? bpm,
    required int? releaseYear,
  }) async {
    if (_llmApiKey == null) return _buildTemplateIntro(
      trackTitle: trackTitle,
      artistName: artistName,
      bpm: bpm,
      year: releaseYear,
    );

    final albumStr = albumName != null ? ' from "$albumName"' : '';
    final bpmStr = bpm != null ? ' $bpm BPM' : '';
    final yearStr = releaseYear != null ? ' $releaseYear' : '';

    final prompt = '''
Generate a 2-3 sentence radio DJ "coming up next" intro for a track.
Format: "Next up, we have [Artist] dropping [Track]$albumStr — a [energy descriptor]$bpmStr release$yearStr. Stay locked in."
Keep it punchy, energetic, and under 50 words total.
Only output the intro text, no quotes or labels.
''';

    try {
      if (_useGemini) {
        final resp = await _dio.get(
          '${ApiConstants.geminiBase}/models/gemini-1.5-flash:generateContent',
          queryParameters: {'key': _llmApiKey},
          data: {'contents': [{'parts': [{'text': prompt}]}]},
        );
        return resp.data['candidates'][0]['content']['parts'][0]['text'] ?? _buildTemplateIntro(
          trackTitle: trackTitle,
          artistName: artistName,
          bpm: bpm,
          year: releaseYear,
        );
      } else {
        final resp = await _dio.post(
          '${ApiConstants.openAiBase}/chat/completions',
          options: Options(headers: {'Authorization': 'Bearer $_llmApiKey'}),
          data: {
            'model': 'gpt-4o-mini',
            'messages': [
              {
                'role': 'system',
                'content': 'You are a radio DJ writing punchy track introductions.'
              },
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 100,
            'temperature': 0.8,
          },
        );
        return resp.data['choices'][0]['message']['content'].trim();
      }
    } catch (e) {
      return _buildTemplateIntro(
        trackTitle: trackTitle,
        artistName: artistName,
        bpm: bpm,
        year: releaseYear,
      );
    }
  }

  String _buildTemplateIntro({
    required String trackTitle,
    required String artistName,
    required int? bpm,
    required int? releaseYear,
  }) {
    final bpmStr = bpm != null ? ' $bpm BPM' : '';
    final yearStr = releaseYear != null ? ', $releaseYear' : '';
    return 'Next up, we have $artistName dropping "$trackTitle" — a high-energy$bpmStr release$yearStr. Stay locked in.';
  }

  /// Speak the announcement via TTS
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.speak(text);
  }

  /// Stop TTS
  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}

class WeatherInfo {
  final double temperature;
  final String condition;
  final String city;
  final String icon;

  WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.city,
    required this.icon,
  });
}

class NewsHeadline {
  final String title;
  final String source;

  NewsHeadline({required this.title, required this.source});
}

class DjAnnouncement {
  final String musicIntro;
  final String weatherText;
  final String newsText;

  DjAnnouncement({
    required this.musicIntro,
    required this.weatherText,
    required this.newsText,
  });

  List<String> get segments => [musicIntro, weatherText, newsText].where((s) => s.isNotEmpty).toList();
}
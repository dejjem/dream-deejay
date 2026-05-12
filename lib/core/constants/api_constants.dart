class ApiConstants {
  ApiConstants._();

  // Deezer
  static const String deezerApiBase = 'https://api.deezer.com';
  static const String deezerAuthBase = 'https://connect.deezer.com';
  static const String deezerRedirectScheme = 'dreamdeejay';
  static const String deezerRedirectUri = '$deezerRedirectScheme://oauth2callback';

  // OpenWeatherMap
  static const String weatherApiBase = 'https://api.openweathermap.org/data/2.5';

  // NewsAPI
  static const String newsApiBase = 'https://newsapi.org/v2';

  // LLM
  static const String openAiBase = 'https://api.openai.com/v1';
  static const String geminiBase = 'https://generativelanguage.googleapis.com/v1';

  // App
  static const String appName = 'Dream DeeJay';
  static const String appVersion = '1.0.0';
}
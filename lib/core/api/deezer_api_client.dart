import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../../data/models/deezer_models.dart';

class DeezerApiClient {
  final Dio _dio;
  String? _accessToken;

  DeezerApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.deezerApiBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            )) {
    _dio.interceptors.add(_AuthInterceptor(this));
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
    ));
  }

  void setAccessToken(String token) {
    _accessToken = token;
  }

  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: {
        ...?queryParameters,
        if (_accessToken != null) 'access_token': _accessToken,
      },
      options: options,
    );
  }

  // Charts
  Future<List<DeezerTrack>> getCharts({int index = 0, int limit = 25}) async {
    final res = await _get<Map<String, dynamic>>('/chart/0/tracks', queryParameters: {'index': index, 'limit': limit});
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // Search
  Future<List<DeezerTrack>> searchTracks(String query, {int index = 0, int limit = 25}) async {
    final res = await _get<Map<String, dynamic>>('/search/track', queryParameters: {'q': query, 'index': index, 'limit': limit});
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerTrack.fromJson(e)).toList();
  }

  Future<List<DeezerArtist>> searchArtists(String query, {int index = 0, int limit = 10}) async {
    final res = await _get<Map<String, dynamic>>('/search/artist', queryParameters: {'q': query, 'index': index, 'limit': limit});
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerArtist.fromJson(e)).toList();
  }

  Future<List<DeezerAlbum>> searchAlbums(String query, {int index = 0, int limit = 10}) async {
    final res = await _get<Map<String, dynamic>>('/search/album', queryParameters: {'q': query, 'index': index, 'limit': limit});
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerAlbum.fromJson(e)).toList();
  }

  // Artists
  Future<DeezerArtist> getArtist(int artistId) async {
    final res = await _get<Map<String, dynamic>>('/artist/');
    return DeezerArtist.fromJson(res.data ?? {});
  }

  Future<List<DeezerTrack>> getArtistTopTracks(int artistId, {int index = 0, int limit = 10}) async {
    final res = await _get<Map<String, dynamic>>('/artist//top', queryParameters: {'index': index, 'limit': limit});
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // Albums
  Future<DeezerAlbum> getAlbum(int albumId) async {
    final res = await _get<Map<String, dynamic>>('/album/');
    return DeezerAlbum.fromJson(res.data ?? {});
  }

  Future<List<DeezerTrack>> getAlbumTracks(int albumId) async {
    final res = await _get<Map<String, dynamic>>('/album//tracks');
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // Playlists
  Future<List<DeezerTrack>> getPlaylistTracks(int playlistId) async {
    final res = await _get<Map<String, dynamic>>('/playlist//tracks');
    return ((res.data?['data'] ?? []) as List).map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // User
  Future<DeezerUser> getUser(int userId) async {
    final res = await _get<Map<String, dynamic>>('/user/');
    return DeezerUser.fromJson(res.data ?? {});
  }

  // AI Recommendations
  Future<DeezerRecommendations> getRecommendations({int limit = 25}) async {
    final res = await _get<Map<String, dynamic>>('/user/me/r Recommendations', queryParameters: {'limit': limit});
    return DeezerRecommendations.fromJson(res.data ?? {});
  }

  // Genres
  Future<List<DeeGenre>> getGenres() async {
    final res = await _get<Map<String, dynamic>>('/genre');
    return ((res.data?['data'] ?? []) as List).map((e) => DeeGenre.fromJson(e)).toList();
  }
}

class _AuthInterceptor extends Interceptor {
  final DeezerApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token is added via query param in _get
    handler.next(options);
  }
}

class DeeGenre {
  final int id;
  final String name;
  final String? picture;

  DeeGenre({required this.id, required this.name, this.picture});

  factory DeeGenre.fromJson(Map<String, dynamic> json) => DeeGenre(id: json["id"], name: json["name"], picture: json["picture"]);
}

class DeeAuthToken {
  final String accessToken;
  final int expires;
  final String tokenType;
  final int userId;

  DeeAuthToken({
    required this.accessToken,
    required this.expires,
    required this.tokenType,
    required this.userId,
  });

  factory DeeAuthToken.fromJson(Map<String, dynamic> json) => DeeAuthToken(accessToken: json["access_token"] as String, expires: json["expires"] as int, tokenType: json["token_type"] as String, userId: json["user_id"] as int);
}

class DeeToken {
  final String accessToken;
  final int expiresIn;
  final String tokenType;
  final int? userId;
  final String? scope;

  DeeToken({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    this.userId,
    this.scope,
  });

  factory DeeToken.fromJson(Map<String, dynamic> json) => DeeToken(accessToken: json["access_token"] as String, expiresIn: json["expires_in"] as int, tokenType: json["token_type"] as String, userId: json["user_id"] as int?, scope: json["scope"] as String?);

  // Auth - missing stubs for compilation
  String getAuthorizationUrl(String appId) => 'https://connect.deezer.com/oauth/auth.php?app_id=$appId&redirect_uri=${Uri.encodeComponent('https://deezer.com')}&response_type=token';

  Future<String> exchangeCodeForToken(String code, String appId) async {
    // TODO: implement real OAuth token exchange
    return '';
  }

  Future<DeezerUser> getMe() async {
    // TODO: get user ID from stored token and call getUser
    return DeezerUser(id: 0, name: '', email: '');
  }

  Future<void> clearAccessToken() async {
    // TODO: clear from secure storage
  }

  // Recommendations wrapper
  Future<List<DeezerTrack>> getMyRecommendations({int limit = 25}) async {
    try {
      final recs = await getCharts(limit: limit);
      return recs;
    } catch (_) {
      return [];
    }
  }

  // Chart wrapper
  Future<List<DeezerTrack>> getChart({int index = 0, int limit = 25}) async {
    return getCharts(index: index, limit: limit);
  }

  // User playlists
  Future<List<DeezerAlbum>> getUserPlaylists(int userId) async {
    // TODO: implement real endpoint
    return [];
  }

}

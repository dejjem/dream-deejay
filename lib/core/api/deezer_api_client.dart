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

  Future<void> clearAccessToken() async {
    _accessToken = null;
  }

  String? get accessToken => _accessToken;

  // ---- OAuth ----

  /// Step 1: Generate the Deezer authorization URL
  String getAuthorizationUrl(String appId) {
    final params = {
      'app_id': appId,
      'redirect_uri': ApiConstants.deezerRedirectUri,
      'perms': 'basic_access,email,offline_access',
    };
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${ApiConstants.deezerAuthBase}/oauth2/auth.php?$query';
  }

  /// Step 2: Exchange authorization code for access token
  Future<DeeAuthToken> exchangeCodeForToken(
    String appId,
    String appSecret,
    String code,
  ) async {
    final resp = await _dio.get(
      '${ApiConstants.deezerAuthBase}/oauth2/access_token.php',
      queryParameters: {
        'app_id': appId,
        'secret': appSecret,
        'code': code,
        'output': 'json',
      },
    );
    return DeeAuthToken.fromJson(resp.data);
  }

  /// Refresh token (Deezer long-lived tokens)
  Future<DeeAuthToken> refreshToken(
    String appId,
    String appSecret,
    String refreshToken,
  ) async {
    final resp = await _dio.get(
      '${ApiConstants.deezerAuthBase}/oauth2/access_token.php',
      queryParameters: {
        'app_id': appId,
        'secret': appSecret,
        'refresh_token': refreshToken,
        'output': 'json',
      },
    );
    return DeeAuthToken.fromJson(resp.data);
  }

  // ---- Track ----

  Future<DeezerTrack> getTrack(int id) async {
    final resp = await _dio.get('/track/$id');
    return DeezerTrack.fromJson(resp.data);
  }

  // ---- Artist ----

  Future<DeezerArtist> getArtist(int id) async {
    final resp = await _dio.get('/artist/$id');
    return DeezerArtist.fromJson(resp.data);
  }

  Future<List<DeezerTrack>> getArtistTop(int id, {int limit = 10}) async {
    final resp = await _dio.get('/artist/$id/top', queryParameters: {
      'limit': limit,
    });
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // ---- Album ----

  Future<DeezerAlbum> getAlbum(int id) async {
    final resp = await _dio.get('/album/$id');
    return DeezerAlbum.fromJson(resp.data);
  }

  Future<List<DeezerTrack>> getAlbumTracks(int id) async {
    final resp = await _dio.get('/album/$id/tracks');
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // ---- Search ----

  Future<List<DeezerTrack>> searchTracks(String query,
      {int index = 0, int limit = 25}) async {
    final resp = await _dio.get(
      '/search/track',
      queryParameters: {'q': query, 'index': index, 'limit': limit},
    );
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerTrack.fromJson(e)).toList();
  }

  Future<List<DeezerAlbum>> searchAlbums(String query,
      {int index = 0, int limit = 25}) async {
    final resp = await _dio.get(
      '/search/album',
      queryParameters: {'q': query, 'index': index, 'limit': limit},
    );
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerAlbum.fromJson(e)).toList();
  }

  Future<List<DeezerArtist>> searchArtists(String query,
      {int index = 0, int limit = 25}) async {
    final resp = await _dio.get(
      '/search/artist',
      queryParameters: {'q': query, 'index': index, 'limit': limit},
    );
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerArtist.fromJson(e)).toList();
  }

  // ---- Chart ----

  Future<DeezerChart> getChart({int index = 0, int limit = 25}) async {
    final resp = await _dio.get('/chart/0', queryParameters: {
      'index': index,
      'limit': limit,
    });
    return DeezerChart.fromJson(resp.data);
  }

  // ---- User ----

  Future<DeezerUser> getMe() async {
    final resp = await _dio.get('/user/me');
    return DeezerUser.fromJson(resp.data);
  }

  Future<List<DeezerTrack>> getMyRecommendations({int limit = 25}) async {
    final resp = await _dio.get('/user/me/recommendations/tracks',
        queryParameters: {'limit': limit});
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // ---- Playlist ----

  Future<List<DeezerPlaylist>> getUserPlaylists(int userId) async {
    final resp = await _dio.get('/user/$userId/playlists');
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerPlaylist.fromJson(e)).toList();
  }

  Future<DeezerPlaylist> getPlaylist(int id) async {
    final resp = await _dio.get('/playlist/$id');
    return DeezerPlaylist.fromJson(resp.data);
  }

  Future<List<DeezerTrack>> getPlaylistTracks(int id) async {
    final resp = await _dio.get('/playlist/$id/tracks');
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerTrack.fromJson(e)).toList();
  }

  // ---- Genre ----

  Future<List<DeezerGenre>> getGenres() async {
    final resp = await _dio.get('/genre');
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerGenre.fromJson(e)).toList();
  }

  Future<List<DeezerArtist>> getGenreArtists(int genreId,
      {int index = 0, int limit = 25}) async {
    final resp = await _dio.get('/genre/$genreId/artists',
        queryParameters: {'index': index, 'limit': limit});
    final data = resp.data['data'] as List;
    return data.map((e) => DeezerArtist.fromJson(e)).toList();
  }

  // ---- User Library ----

  Future<List<DeezerTrack>> getUserFavorites(int userId) async {
    final resp = await _dio.get('/user/$userId/albums');
    final data = resp.data['data'] as List;
    // Albums -> flatten tracks
    List<DeezerTrack> tracks = [];
    for (var album in data) {
      try {
        final albumId = album['id'] as int;
        final albumTracks = await getAlbumTracks(albumId);
        tracks.addAll(albumTracks);
      } catch (_) {}
    }
    return tracks;
  }

  // ---- Stream URL ----

  /// Get the stream URL for a track (requires Premium+ token)
  String? getStreamUrl(int trackId) {
    final token = _accessToken;
    if (token == null) return null;
    // Deezer stream URL is generated from the API token
    return 'https://www.deezer.com/plugins/taas?API_TOKEN=$token&track_id=$trackId';
  }
}

class _AuthInterceptor extends Interceptor {
  final DeezerApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = _client.accessToken;
    if (token != null) {
      options.queryParameters['access_token'] = token;
    }
    handler.next(options);
  }
}

class DeeToken {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;

  DeeToken({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
  });

  factory DeeToken.fromJson(Map<String, dynamic> json) {
    return DeeToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
}

class DeeAuthToken {
  final String tokenType;
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;

  DeeAuthToken({
    required this.tokenType,
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
  });

  factory DeeAuthToken.fromJson(Map<String, dynamic> json) {
    return DeeAuthToken(
      tokenType: json['token_type'] as String? ?? 'bearer',
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
}

class DeeGenre {
  final int id;
  final String name;
  final String? picture;

  DeeGenre({required this.id, required this.name, this.picture});

  factory DeeGenre.fromJson(Map<String, dynamic> json) => DeeGenre(
        id: json['id'] as int,
        name: json['name'] as String,
        picture: json['picture'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'picture': picture,
      };
}

// Alias
typedef DeezerGenre = DeeGenre;
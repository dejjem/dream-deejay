import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const _keyDeezerAccessToken = 'deezer_access_token';
  static const _keyDeezerRefreshToken = 'deezer_refresh_token';
  static const _keyDeezerExpiresAt = 'deezer_expires_at';
  static const _keyDeezerUserId = 'deezer_user_id';

  // Deezer
  Future<void> saveDeezerToken({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) async {
    await _storage.write(key: _keyDeezerAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyDeezerRefreshToken, value: refreshToken);
    }
    final expiresAt = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    await _storage.write(key: _keyDeezerExpiresAt, value: expiresAt.toString());
  }

  Future<String?> getDeezerAccessToken() =>
      _storage.read(key: _keyDeezerAccessToken);

  Future<String?> getDeezerRefreshToken() =>
      _storage.read(key: _keyDeezerRefreshToken);

  Future<int?> getDeezerExpiresAt() async {
    final v = await _storage.read(key: _keyDeezerExpiresAt);
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> saveDeezerUserId(int userId) async {
    await _storage.write(key: _keyDeezerUserId, value: userId.toString());
  }

  Future<int?> getDeezerUserId() async {
    final v = await _storage.read(key: _keyDeezerUserId);
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> clearDeezerTokens() async {
    await _storage.delete(key: _keyDeezerAccessToken);
    await _storage.delete(key: _keyDeezerRefreshToken);
    await _storage.delete(key: _keyDeezerExpiresAt);
    await _storage.delete(key: _keyDeezerUserId);
  }

  // Generic key-value
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
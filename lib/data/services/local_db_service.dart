import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalDbService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'dream_deejay.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            album_cover TEXT,
            duration INTEGER,
            preview TEXT,
            artist_id INTEGER,
            album_id INTEGER,
            added_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE downloads (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            album_cover TEXT,
            duration INTEGER,
            preview TEXT,
            artist_id INTEGER,
            album_id INTEGER,
            file_path TEXT NOT NULL,
            file_size INTEGER,
            downloaded_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cache_stats (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ---- Favorites ----

  Future<void> addFavorite(Map<String, dynamic> track) async {
    final database = await db;
    await database.insert(
      'favorites',
      {
        'id': track['id'],
        'title': track['title'],
        'artist': track['artist'],
        'album': track['album'],
        'album_cover': track['album_cover'],
        'duration': track['duration'],
        'preview': track['preview'],
        'artist_id': track['artist_id'],
        'album_id': track['album_id'],
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(int trackId) async {
    final database = await db;
    await database.delete('favorites', where: 'id = ?', whereArgs: [trackId]);
  }

  Future<bool> isFavorite(int trackId) async {
    final database = await db;
    final result = await database.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final database = await db;
    final rows = await database.query('favorites', orderBy: 'added_at DESC');
    return rows;
  }

  // ---- Downloads (offline) ----

  Future<String> _getDownloadDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(appDir.path, 'downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<void> addDownload(Map<String, dynamic> track, String filePath) async {
    final database = await db;
    final file = File(filePath);
    final size = await file.exists() ? await file.length() : 0;

    await database.insert(
      'downloads',
      {
        'id': track['id'],
        'title': track['title'],
        'artist': track['artist'],
        'album': track['album'],
        'album_cover': track['album_cover'],
        'duration': track['duration'],
        'preview': track['preview'],
        'artist_id': track['artist_id'],
        'album_id': track['album_id'],
        'file_path': filePath,
        'file_size': size,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeDownload(int trackId) async {
    final database = await db;
    // Get file path before deleting DB record
    final rows = await database.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [trackId],
      columns: ['file_path'],
    );
    if (rows.isNotEmpty) {
      final filePath = rows.first['file_path'] as String?;
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await database.delete('downloads', where: 'id = ?', whereArgs: [trackId]);
  }

  Future<bool> isDownloaded(int trackId) async {
    final database = await db;
    final result = await database.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<String?> getDownloadPath(int trackId) async {
    final database = await db;
    final result = await database.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [trackId],
      columns: ['file_path'],
      limit: 1,
    );
    if (result.isEmpty) return null;
    final path = result.first['file_path'] as String?;
    if (path == null) return null;
    // Verify file still exists
    if (await File(path).exists()) return path;
    // File gone — clean up DB
    await removeDownload(trackId);
    return null;
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    final database = await db;
    final rows = await database.query('downloads', orderBy: 'downloaded_at DESC');
    return rows;
  }

  Future<int> getTotalDownloadSize() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT SUM(file_size) as total FROM downloads',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  // ---- Cache size management ----

  Future<int> getMaxCacheSize() async {
    final database = await db;
    final rows = await database.query(
      'cache_stats',
      where: 'key = ?',
      whereArgs: ['max_cache_mb'],
    );
    if (rows.isEmpty) return 500; // default 500 MB
    return int.tryParse(rows.first['value'] as String) ?? 500;
  }

  Future<void> setMaxCacheSize(int mb) async {
    final database = await db;
    await database.insert(
      'cache_stats',
      {'key': 'max_cache_mb', 'value': mb.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Download a track's audio file for offline playback
  /// Returns the local file path when complete.
  Future<String?> downloadTrack(Map<String, dynamic> track) async {
    final previewUrl = track['preview'] as String?;
    if (previewUrl == null || previewUrl.isEmpty) return null;

    try {
      final downloadDir = await _getDownloadDir();
      final fileName = 'track_${track['id']}.mp3';
      final filePath = p.join(downloadDir, fileName);

      final dio = Dio();
      await dio.download(previewUrl, filePath);

      await addDownload(track, filePath);
      return filePath;
    } catch (e) {
      return null;
    }
  }
}

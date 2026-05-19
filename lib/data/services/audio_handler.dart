import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import '../providers/providers.dart';

/// Offline audio cache for Deezer preview tracks.
/// Respects Deezer API offline terms: 30-second MP3 previews only.
/// Cache is stored in the application documents directory and is
/// subject to a configurable size limit (default 500 MB).
class AudioCacheService {
  static const _cacheDirName = 'audio_cache';
  static const _defaultMaxCacheMb = 500;

  String? _cacheDir;
  int _maxCacheMb = _defaultMaxCacheMb;
  int _currentSizeBytes = 0;
  bool _initialized = false;

  Future<void> init({int? maxCacheMb}) async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = p.join(appDir.path, _cacheDirName);
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (maxCacheMb != null) {
      _maxCacheMb = maxCacheMb;
    }
    await _computeSize();
    _initialized = true;
  }

  void setMaxCacheMb(int mb) {
    _maxCacheMb = mb;
  }

  int get currentSizeBytes => _currentSizeBytes;
  int get maxCacheBytes => _maxCacheMb * 1024 * 1024;

  Future<void> _computeSize() async {
    _currentSizeBytes = 0;
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        _currentSizeBytes += await entity.length();
      }
    }
  }

  /// Returns the cached file path if a track is already cached, null otherwise.
  Future<String?> getCachedPath(int trackId) async {
    if (_cacheDir == null) return null;
    final file = File(p.join(_cacheDir!, 'track_$trackId.mp3'));
    if (await file.exists()) {
      // Update mtime for LRU
      await file.setLastModified(DateTime.now());
      return file.path;
    }
    return null;
  }

  /// Downloads and caches a track's audio preview.
  /// Returns the local file path on success, null on failure.
  /// Evicts oldest files if cache limit would be exceeded.
  Future<String?> cacheTrack(Map<String, dynamic> track) async {
    if (_cacheDir == null) await init();
    final previewUrl = track['preview'] as String?;
    if (previewUrl == null || previewUrl.isEmpty) return null;

    final trackId = track['id'] as int;
    final filePath = p.join(_cacheDir!, 'track_$trackId.mp3');
    final file = File(filePath);

    // Already cached
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return filePath;
    }

    try {
      final dio = Dio();
      // Fetch file size first
      final resp = await dio.head(previewUrl);
      final contentLength = int.tryParse(resp.headers.value('content-length') ?? '');

      if (contentLength != null) {
        final neededBytes = _currentSizeBytes + contentLength;
        if (neededBytes > maxCacheBytes) {
          await _evictToFree(contentLength);
        }
      } else {
        // No content-length header — evict to make room unconditionally
        await _evictToFree(maxCacheBytes ~/ 4);
      }

      await dio.download(previewUrl, filePath);
      final savedSize = await file.length();
      _currentSizeBytes += savedSize;
      return filePath;
    } catch (e) {
      // Clean up partial file
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }
  }

  /// Removes a track from the cache.
  Future<void> removeCachedTrack(int trackId) async {
    if (_cacheDir == null) return;
    final file = File(p.join(_cacheDir!, 'track_$trackId.mp3'));
    if (await file.exists()) {
      _currentSizeBytes -= await file.length();
      await file.delete();
    }
  }

  /// Clears the entire cache.
  Future<void> clearCache() async {
    if (_cacheDir == null) return;
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
    _currentSizeBytes = 0;
  }

  /// Returns the total bytes used by the cache.
  Future<int> getCacheSizeBytes() async {
    await _computeSize();
    return _currentSizeBytes;
  }

  /// Evicts the least-recently-used files until `neededBytes` are freed.
  Future<void> _evictToFree(int neededBytes) async {
    final dir = Directory(_cacheDir!);
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }
    // Sort by mtime ascending (oldest first) — collect mtimes first to avoid
    // concurrent stat calls inside sort
    final filesWithMtime = await Future.wait(
      files.map((f) async => MapEntry(f, (await f.stat()).modified)),
    );
    filesWithMtime.sort((a, b) => a.value.compareTo(b.value));

    int freed = 0;
    for (final entry in filesWithMtime) {
      if (freed >= neededBytes) break;
      final file = entry.key;
      final size = await file.length();
      await file.delete();
      freed += size;
      _currentSizeBytes -= size;
    }
  }
}

class DeeJayAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<MediaItem> _queue = [];
  int _currentIndex = 0;

  DeeJayAudioHandler() {
    _init();
  }

  void _init() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        mediaItem.add(_queue[index]);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  @override
  Future<void> setQueue(List<MediaItem> queue, {int initialIndex = 0}) async {
    _queue.clear();
    _queue.addAll(queue);
    _currentIndex = initialIndex;

    if (queue.isEmpty) return;

    final sources = queue.map((item) {
      final url = item.extras?['url'] as String? ?? item.id;
      return AudioSource.uri(Uri.parse(url), tag: item);
    }).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
    );

    this.queue.add(_queue);
    if (_queue.isNotEmpty) {
      mediaItem.add(_queue[_currentIndex]);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    _queue.add(item);
    queue.add(_queue);

    final url = item.extras?['url'] as String? ?? item.id;
    final source = AudioSource.uri(Uri.parse(url), tag: item);

    if (_queue.length == 1) {
      // First item — load and wait
      await _player.setAudioSource(source);
    } else {
      // Append to existing queue
      final currentSrc = _player.audioSource;
      if (currentSrc is ConcatenatingAudioSource) {
        await currentSrc.add(source);
      }
    }
  }

  @override
  Future<void> addQueueItemAt(MediaItem item, int index) async {
    if (index < 0 || index > _queue.length) return;
    _queue.insert(index, item);
    queue.add(_queue);

    final url = item.extras?['url'] as String? ?? item.id;
    final source = AudioSource.uri(Uri.parse(url), tag: item);

    final currentSrc = _player.audioSource;
    if (currentSrc is ConcatenatingAudioSource) {
      await currentSrc.add(source);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    queue.add(_queue);

    final currentSrc = _player.audioSource;
    if (currentSrc is ConcatenatingAudioSource) {
      await currentSrc.removeAt(index);
    }

    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
  }

  @override
  Future<void> onCustomAction(String action, [Map<String, dynamic>? extras]) async {
    if (action == 'reorderQueue') {
      final from = extras?['from'] as int?;
      final to = extras?['to'] as int?;
      if (from != null && to != null) {
        await _reorderQueue(from, to);
      }
    } else if (action == 'clearQueue') {
      _queue.clear();
      queue.add(_queue);
      await _player.stop();
    }
    return;
  }

  Future<void> _reorderQueue(int from, int to) async {
    if (from < 0 || from >= _queue.length) return;
    if (to < 0 || to >= _queue.length) return;

    final item = _queue.removeAt(from);
    _queue.insert(to, item);
    queue.add(_queue);

    final wasPlaying = _player.playing;
    final position = _player.position;
    final currentIdx = _currentIndex;

    final sources = _queue.map((mi) {
      final url = mi.extras?['url'] as String? ?? mi.id;
      return AudioSource.uri(Uri.parse(url), tag: mi);
    }).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: currentIdx,
      initialPosition: position,
    );

    if (!wasPlaying) await _player.pause();
  }

  List<MediaItem> get queueItems => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  PlayerState get playerState => _player.playerState;
}
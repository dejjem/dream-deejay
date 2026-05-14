import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

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
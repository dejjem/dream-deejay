import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/ai_dj_service.dart';
import '../../../core/di/injection.dart';
import '../../../data/services/local_db_service.dart';
import '../../providers/providers.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isDjSpeaking = false;
  bool _isFavorite = false;
  String _djText = '';
  final _aiDj = getIt<AiDjService>();
  final _db = getIt<LocalDbService>();

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    final handler = audioHandler;
    _positionSub = handler.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = handler.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
    _playingSub = handler.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  void _checkFavoriteStatus(Map<String, dynamic>? track) async {
    if (track == null) return;
    final id = track['id'] as int?;
    if (id == null) return;
    final isFav = await _db.isFavorite(id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  Future<void> _triggerDj() async {
    if (_isDjSpeaking) return;

    final queue = ref.read(queueProvider);
    final next = queue.nextTrack;
    if (next == null) {
      _speakText('No track queued up next.');
      return;
    }

    setState(() { _isDjSpeaking = true; _djText = 'Preparing your DJ announcement...'; });

    Position? location;
    try {
      location = await _aiDj.getCurrentLocation();
    } catch (_) {}

    // Derive country code from device locale for NewsAPI
    String countryCode = 'us';
    try {
      final locale = Platform.resolvedLocale ?? Platform.locale;
      if (locale.contains('_')) {
        countryCode = locale.split('_').last.toLowerCase();
      } else if (locale.contains('-')) {
        countryCode = locale.split('-').last.toLowerCase();
      } else if (locale.length == 2) {
        countryCode = locale.toLowerCase();
      }
      // NewsAPI only supports specific country codes; fall back for unsupported ones
      const supported = {'ae','ar','at','au','be','bg','br','ca','ch','cn','co','cu','cz','de','eg','fr','gb','gr','hk','hu','id','ie','il','in','it','jp','kr','lt','lv','ma','mx','my','ng','nl','no','nz','ph','pl','pt','ro','rs','ru','sa','se','sg','si','sk','th','tr','tw','ua','us','ve','za'};
      if (!supported.contains(countryCode)) countryCode = 'us';
    } catch (_) {}

    final announcement = await _aiDj.buildAnnouncement(
      trackTitle: next['title'] ?? '',
      artistName: next['artist'] ?? '',
      albumName: next['album'],
      bpm: next['bpm'] as int?,
      releaseYear: next['year'] as int?,
      countryCode: countryCode,
      lat: location?.latitude,
      lon: location?.longitude,
    );

    // Build read-along text
    final allText = announcement.segments.join(' ');

    setState(() { _djText = allText; });

    // Speak each segment
    for (final segment in announcement.segments) {
      await _aiDj.speak(segment);
    }

    setState(() { _isDjSpeaking = false; _djText = ''; });
  }

  void _speakText(String text) async {
    setState(() { _isDjSpeaking = true; _djText = text; });
    await _aiDj.speak(text);
    setState(() { _isDjSpeaking = false; _djText = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider);
    final current = queue.currentTrack;
    // Update favorite icon when track changes
    _checkFavoriteStatus(current);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                        color: AppTheme.textPrimary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text('Now Playing',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        color: AppTheme.textSecondary,
                        onPressed: () => _showOptions(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Album art
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Hero(
                      tag: 'album_art',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: current?['album_cover'] != null && current!['album_cover'].toString().isNotEmpty
                            ? Image.network(
                                current['album_cover'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _PlaceholderArt(),
                              )
                            : _PlaceholderArt(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  current?['title'] ?? 'Not playing',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  current?['artist'] ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (current?['bpm'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentPurple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${current!['bpm']} BPM',
                                style: const TextStyle(
                                  color: AppTheme.accentPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _duration.inSeconds > 0
                              ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: (v) {
                            final newPos = Duration(seconds: (v * _duration.inSeconds).round());
                            audioHandler.seek(newPos);
                            ref.read(queueProvider.notifier).setPosition(newPos);
                          },
                          activeColor: AppTheme.accentMagenta,
                          inactiveColor: AppTheme.divider,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Text(_formatDuration(_duration),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 36),
                        color: AppTheme.textPrimary,
                        onPressed: () {
                          audioHandler.skipToPrevious();
                          final newIdx = ref.read(queueProvider).currentIndex - 1;
                          if (newIdx >= 0) ref.read(queueProvider.notifier).setCurrentIndex(newIdx);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay, size: 28),
                        color: AppTheme.textSecondary,
                        onPressed: () => audioHandler.seek(Duration.zero),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentMagenta,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 40,
                          ),
                          color: Colors.white,
                          onPressed: () {
                            if (_isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                            ref.read(queueProvider.notifier).setPlaying(!_isPlaying);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 36),
                        color: AppTheme.textPrimary,
                        onPressed: () {
                          audioHandler.skipToNext();
                          final newIdx = ref.read(queueProvider).currentIndex + 1;
                          ref.read(queueProvider.notifier).setCurrentIndex(newIdx);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 28,
                        ),
                        color: AppTheme.accentMagenta,
                        onPressed: () async {
                          final queue = ref.read(queueProvider);
                          final track = queue.currentTrack;
                          if (track == null) return;
                          final id = track['id'] as int?;
                          if (id == null) return;

                          if (_isFavorite) {
                            await _db.removeFavorite(id);
                            if (mounted) setState(() => _isFavorite = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from favorites'),
                                duration: Duration(seconds: 1),
                                backgroundColor: AppTheme.bgCard,
                              ),
                            );
                          } else {
                            await _db.addFavorite(track);
                            if (mounted) setState(() => _isFavorite = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved to favorites'),
                                duration: Duration(seconds: 1),
                                backgroundColor: AppTheme.bgCard,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Space for DJ button
              ],
            ),
            // Floating DJ button
            Positioned(
              right: 20,
              bottom: 120,
              child: FloatingActionButton(
                onPressed: _isDjSpeaking ? null : _triggerDj,
                backgroundColor: _isDjSpeaking ? AppTheme.textSecondary : AppTheme.accentCyan,
                child: Icon(
                  _isDjSpeaking ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ),
            // DJ announcement card
            if (_isDjSpeaking && _djText.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 200,
                child: _DjCard(text: _djText),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.textSecondary),
              title: const Text('Share', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
              title: const Text('Add to playlist', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.album, color: AppTheme.textSecondary),
              title: const Text('Go to album', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgCard,
      child: const Center(
        child: Icon(Icons.album, size: 80, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _DjCard extends StatelessWidget {
  final String text;
  const _DjCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppTheme.accentCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
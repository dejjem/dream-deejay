import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dream_deejay/main.dart';
import 'package:dream_deejay/data/models/deezer_models.dart';
import 'package:dream_deejay/core/api/deezer_api_client.dart';
import 'package:get_it/get_it.dart';
import 'package:dream_deejay/core/utils/secure_storage.dart';
import 'package:dream_deejay/core/theme/app_theme.dart';
import 'package:dream_deejay/core/di/injection.dart';
import 'package:dream_deejay/data/services/local_db_service.dart';
import 'package:dream_deejay/data/services/audio_handler.dart';
import 'package:dream_deejay/presentation/providers/providers.dart';
import 'package:dream_deejay/presentation/widgets/track_tile.dart';
import 'package:dream_deejay/presentation/widgets/section_header.dart';
class HomeScreen extends ConsumerState {
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });

    try {
      final client = getIt<DeezerApiClient>();
      final token = await getIt<SecureStorage>().getDeezerAccessToken();
      if (token == null) {
        setState(() { _loading = false; _error = 'Not logged in'; });
        return;
      }
      client.setAccessToken(token);

      // Load recommendations + chart in parallel
      final results = await Future.wait([
        _loadRecommendations(client),
        _loadChart(client),
      ]);

      setState(() {
        _loading = false;
        _recommendations = results[0];
        _chartTracks = results[1];
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecommendations(DeezerApiClient client) async {
    try {
      final tracks = await client.getMyRecommendations(limit: 20);
      return tracks.map((t) => _trackToMap(t)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadChart(DeezerApiClient client) async {
    try {
      final chart = await client.getChart(limit: 20);
      return chart.tracks?.map((t) => _trackToMap(t)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _trackToMap(dynamic t) {
    return {
      'id': t.id,
      'title': t.title,
      'artist': t.artist?.name ?? 'Unknown',
      'album': t.album?.title ?? 'Unknown',
      'album_cover': t.album?.coverMedium ?? t.album?.cover ?? '',
      'duration': t.duration,
      'preview': t.preview,
      'artist_id': t.artist?.id,
      'album_id': t.album?.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentMagenta),
        ),
      );
    }

    if (_error == 'Not logged in') {
      return Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off, size: 64, color: AppTheme.textSecondary),
              SizedBox(height: 16),
              Text(
                'Connect your Deezer account',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 20),
              ),
              SizedBox(height: 8),
              Text(
                'Go to Settings to sign in',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        title: Text('Dream DeeJay'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.accentMagenta,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            if (_recommendations.isNotEmpty) ...[
              SectionHeader(title: 'Recommended for You'),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _recommendations.length,
                  itemBuilder: (ctx, i) => _AlbumCard(
                    item: _recommendations[i],
                    onTap: () => _playTrack(_recommendations, i),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
            if (_chartTracks.isNotEmpty) ...[
              SectionHeader(title: 'Top Charts'),
              ...List.generate(
                _chartTracks.length > 10 ? 10 : _chartTracks.length,
                (i) => TrackTile(
                  item: _chartTracks[i],
                  index: i + 1,
                  onTap: () => _playTrack(_chartTracks, i),
                  onDownload: () => _downloadTrack(_chartTracks[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _playTrack(List<Map<String, dynamic>> tracks, int index) {
    // Convert to MediaItems and play
    final queueNotifier = ref.read(queueProvider.notifier);
    final mediaItems = tracks.map((t) => MediaItem(
      id: t['preview'] ?? 'https://www.deezer.com/track/${t['id']}',
      title: t['title'] ?? 'Unknown',
      artist: t['artist'] ?? 'Unknown',
      album: t['album'] ?? 'Unknown',
      artUri: Uri.tryParse(t['album_cover'] ?? ''),
      duration: Duration(seconds: (t['duration'] ?? 0) as int),
      extras: {'url': t['preview'], ...t},
    )).toList();

    audioHandler.setQueue(mediaItems, initialIndex: index);
    audioHandler.play();

    queueNotifier.setQueue(tracks, initialIndex: index);
    queueNotifier.setPlaying(true);
  }

  void _downloadTrack(Map<String, dynamic> track) async {
    final id = track['id'] as int?;
    if (id == null) return;
    try {
      final db = getIt<LocalDbService>();
      final alreadyDownloaded = await db.isDownloaded(id);
      if (alreadyDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Already downloaded'),
              backgroundColor: AppTheme.bgCard, duration: Duration(seconds: 1)),
        );
        return;
      }
      final path = await db.downloadTrack(track);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: ${track['title']}'),
              backgroundColor: AppTheme.bgCard, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'),
            backgroundColor: AppTheme.bgCard, duration: Duration(seconds: 2)),
      );
    }
  }
}

class _AlbumCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  _AlbumCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item['album_cover'] != null && item['album_cover'].toString().isNotEmpty
                  ? Image.network(
                      item['album_cover'],
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 150,
                        height: 150,
                        color: AppTheme.bgCard,
                        child: Icon(Icons.album, size: 48, color: AppTheme.textSecondary),
                      ),
                    )
                  : Container(
                      width: 150,
                      height: 150,
                      color: AppTheme.bgCard,
                      child: Icon(Icons.album, size: 48, color: AppTheme.textSecondary),
                    ),
            ),
            SizedBox(height: 8),
            Text(
              item['title'] ?? 'Unknown',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              item['artist'] ?? 'Unknown',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dream_deejay/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/deezer_api_client.dart';
import '../../../core/utils/secure_storage.dart';
import '../../../data/services/local_db_service.dart';
import '../../providers/providers.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.bgDeep,
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            indicatorColor: AppTheme.accentMagenta,
            labelColor: AppTheme.accentMagenta,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: 'Saved'),
              Tab(text: 'Playlists'),
              Tab(text: 'Downloads'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SavedTab(),
            _PlaylistsTab(),
            _DownloadsTab(),
          ],
        ),
      ),
    );
  }
}

// ---- Saved Tracks (Favorites) ----

class _SavedTab extends ConsumerStatefulWidget {
  const _SavedTab();

  @override
  ConsumerState<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends ConsumerState<_SavedTab> {
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final db = getIt<LocalDbService>();
      final rows = await db.getFavorites();
      _favorites = rows.map((row) {
        return {
          'id': row['id'],
          'title': row['title'],
          'artist': row['artist'],
          'album': row['album'],
          'album_cover': row['album_cover'],
          'duration': row['duration'],
          'preview': row['preview'],
          'artist_id': row['artist_id'],
          'album_id': row['album_id'],
        };
      }).toList();
    } catch (e) {
      _favorites = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentMagenta),
      );
    }

    if (_favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No saved tracks yet',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            SizedBox(height: 8),
            Text('Tap the heart icon on any track to save it',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppTheme.accentMagenta,
      child: ListView.builder(
        itemCount: _favorites.length,
        itemBuilder: (ctx, i) {
          final track = _favorites[i];
          return ListTile(
            onTap: () => _playTrack(track, i),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track['album_cover'] != null
                  ? Image.network(track['album_cover'], width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderArt())
                  : _PlaceholderArt(),
            ),
            title: Text(track['title'] ?? 'Unknown',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track['artist'] ?? 'Unknown',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: AppTheme.accentMagenta),
              onPressed: () async {
                await getIt<LocalDbService>().removeFavorite(track['id'] as int);
                await _loadFavorites();
              },
            ),
          );
        },
      ),
    );
  }

  void _playTrack(Map<String, dynamic> track, int index) {
    final mediaItems = _favorites.map((t) => MediaItem(
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

    ref.read(queueProvider.notifier).setQueue(_favorites, initialIndex: index);
    ref.read(queueProvider.notifier).setPlaying(true);
  }
}

// ---- User Playlists from Deezer ----

class _PlaylistsTab extends ConsumerStatefulWidget {
  const _PlaylistsTab();

  @override
  ConsumerState<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<_PlaylistsTab> {
  List<Map<String, dynamic>> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _loading = true);
    try {
      final client = getIt<DeezerApiClient>();
      final token = await getIt<SecureStorage>().getDeezerAccessToken();
      if (token == null) {
        setState(() { _loading = false; _error = 'Not logged in'; });
        return;
      }
      client.setAccessToken(token);
      final userId = await getIt<SecureStorage>().getDeezerUserId();
      if (userId == null) {
        setState(() { _loading = false; _error = 'Not logged in'; });
        return;
      }
      final playlists = await client.getUserPlaylists(userId);
      _playlists = playlists.map((p) => {
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'picture': p.pictureMedium ?? p.picture,
        'nb_tracks': p.nbTracks,
      }).toList();
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentMagenta),
      );
    }

    if (_error == 'Not logged in' || _playlists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No playlists found',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            SizedBox(height: 8),
            Text('Create playlists in Deezer to see them here',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      color: AppTheme.accentMagenta,
      child: ListView.builder(
        itemCount: _playlists.length,
        itemBuilder: (ctx, i) {
          final playlist = _playlists[i];
          return ListTile(
            onTap: () => _loadAndPlayPlaylist(playlist),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: playlist['picture'] != null
                  ? Image.network(playlist['picture'], width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaylistArt())
                  : _PlaylistArt(),
            ),
            title: Text(playlist['title'] ?? '',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${playlist['nb_tracks'] ?? 0} tracks',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          );
        },
      ),
    );
  }

  void _loadAndPlayPlaylist(Map<String, dynamic> playlist) async {
    final playlistId = playlist['id'] as int;
    try {
      final client = getIt<DeezerApiClient>();
      final tracks = await client.getPlaylistTracks(playlistId);
      if (tracks.isEmpty) return;

      final trackMaps = tracks.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist?.name ?? 'Unknown',
        'album': t.album?.title ?? 'Unknown',
        'album_cover': t.album?.coverMedium ?? t.album?.cover ?? '',
        'duration': t.duration,
        'preview': t.preview,
        'artist_id': t.artist?.id,
        'album_id': t.album?.id,
      }).toList();

      final mediaItems = trackMaps.map((t) => MediaItem(
        id: t['preview'] ?? 'https://www.deezer.com/track/${t['id']}',
        title: t['title'] ?? 'Unknown',
        artist: t['artist'] ?? 'Unknown',
        album: t['album'] ?? 'Unknown',
        artUri: Uri.tryParse(t['album_cover'] ?? ''),
        duration: Duration(seconds: (t['duration'] ?? 0) as int),
        extras: {'url': t['preview'], ...t},
      )).toList();

      audioHandler.setQueue(mediaItems);
      audioHandler.play();

      ref.read(queueProvider.notifier).setQueue(trackMaps);
      ref.read(queueProvider.notifier).setPlaying(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load playlist: $e'),
              backgroundColor: AppTheme.bgCard),
        );
      }
    }
  }
}

// ---- Downloads (offline tracks) ----

class _DownloadsTab extends ConsumerStatefulWidget {
  const _DownloadsTab();

  @override
  ConsumerState<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends ConsumerState<_DownloadsTab> {
  List<Map<String, dynamic>> _downloads = [];
  bool _loading = true;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _loading = true);
    try {
      final db = getIt<LocalDbService>();
      final rows = await db.getDownloads();
      _downloads = rows.map((row) {
        return {
          'id': row['id'],
          'title': row['title'],
          'artist': row['artist'],
          'album': row['album'],
          'album_cover': row['album_cover'],
          'duration': row['duration'],
          'preview': row['preview'],
          'file_path': row['file_path'],
          'file_size': row['file_size'],
        };
      }).toList();
      _totalSize = await db.getTotalDownloadSize();
    } catch (e) {
      _downloads = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentMagenta),
      );
    }

    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_outlined, size: 64, color: AppTheme.accentCyan),
            const SizedBox(height: 16),
            const Text('No downloaded tracks',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Tap the download icon on any track\nto save it for offline playback',
                style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Storage info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.bgCard,
          child: Row(
            children: [
              Icon(Icons.storage, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                '${_downloads.length} tracks · ${_formatBytes(_totalSize)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDownloads,
            color: AppTheme.accentMagenta,
            child: ListView.builder(
              itemCount: _downloads.length,
              itemBuilder: (ctx, i) {
                final track = _downloads[i];
                return ListTile(
                  onTap: () => _playDownload(track, i),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: track['album_cover'] != null
                        ? Image.network(track['album_cover'], width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PlaceholderArt())
                        : _PlaceholderArt(),
                  ),
                  title: Text(track['title'] ?? 'Unknown',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(track['artist'] ?? 'Unknown',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                    onPressed: () async {
                      await getIt<LocalDbService>().removeDownload(track['id'] as int);
                      await _loadDownloads();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _playDownload(Map<String, dynamic> track, int index) {
    // Use local file path for downloaded tracks
    final filePath = track['file_path'] as String?;
    final mediaItems = _downloads.map((t) {
      final fp = t['file_path'] as String?;
      return MediaItem(
        id: fp ?? t['preview'] ?? 'https://www.deezer.com/track/${t['id']}',
        title: t['title'] ?? 'Unknown',
        artist: t['artist'] ?? 'Unknown',
        album: t['album'] ?? 'Unknown',
        artUri: Uri.tryParse(t['album_cover'] ?? ''),
        duration: Duration(seconds: (t['duration'] ?? 0) as int),
        extras: {'url': fp ?? t['preview'], ...t},
      );
    }).toList();

    audioHandler.setQueue(mediaItems, initialIndex: index);
    audioHandler.play();

    ref.read(queueProvider.notifier).setQueue(_downloads, initialIndex: index);
    ref.read(queueProvider.notifier).setPlaying(true);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).round()} GB';
  }
}

class _PlaceholderArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(6)),
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary, size: 20),
    );
  }
}

class _PlaylistArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.queue_music, color: AppTheme.textSecondary, size: 24),
    );
  }
}

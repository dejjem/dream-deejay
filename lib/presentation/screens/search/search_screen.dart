import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dream_deejay/main.dart';
import 'package:dream_deejay/data/models/deezer_models.dart';
import 'package:dream_deejay/core/api/deezer_api_client.dart';
import 'package:dream_deejay/core/utils/secure_storage.dart';
import 'package:dream_deejay/data/services/local_db_service.dart';
import 'package:get_it/get_it.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _results = [];
  Set<int> _favoriteIds = {};
  bool _loading = false;
  String? _error;
  SearchFilter _filter = SearchFilter.tracks;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteIds() async {
    final db = getIt<LocalDbService>();
    final favorites = await db.getFavorites();
    _favoriteIds = favorites.map((f) => f['id'] as int).toSet();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _query = ''; });
      return;
    }

    setState(() { _loading = true; _error = null; _query = query; });

    try {
      final client = getIt<DeezerApiClient>();
      final token = await getIt<SecureStorage>().getDeezerAccessToken();
      client.setAccessToken(token ?? '');

      List<Map<String, dynamic>> results;
      if (_filter == SearchFilter.tracks) {
        final tracks = await client.searchTracks(query);
        results = tracks.map(_trackToMap).toList();
      } else if (_filter == SearchFilter.albums) {
        final albums = await client.searchAlbums(query);
        results = albums.map(_albumToMap).toList();
      } else {
        final artists = await client.searchArtists(query);
        results = artists.map(_artistToMap).toList();
      }

      // Load favorite IDs for track results
      await _loadFavoriteIds();

      setState(() { _loading = false; _results = results; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Map<String, dynamic> _trackToMap(DeezerTrack t) => {
    'id': t.id, 'title': t.title, 'artist': t.artist?.name ?? 'Unknown',
    'album': t.album?.title ?? 'Unknown', 'album_cover': t.album?.coverMedium ?? '',
    'duration': t.duration, 'preview': t.preview,
    'artist_id': t.artist?.id, 'album_id': t.album?.id,
    '_type': 'track',
  };

  Map<String, dynamic> _albumToMap(DeezerAlbum a) => {
    'id': a.id, 'title': a.title, 'artist': a.artist?.name ?? 'Unknown',
    'album_cover': a.coverMedium ?? a.cover ?? '',
    '_type': 'album',
  };

  Map<String, dynamic> _artistToMap(DeezerArtist a) => {
    'id': a.id, 'name': a.name,
    'artist_cover': a.pictureMedium ?? a.picture ?? '',
    '_type': 'artist',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search tracks, albums, artists...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _results = []; _query = ''; });
                        },
                      )
                    : null,
              ),
              onSubmitted: _search,
              onChanged: (v) => setState(() {}),
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: SearchFilter.values.map((f) {
                final label = f.name[0].toUpperCase() + f.name.substring(1);
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (sel) {
                      setState(() { _filter = f; });
                      if (_query.isNotEmpty) _search(_query);
                    },
                    selectedColor: AppTheme.accentMagenta.withOpacity(0.3),
                    checkmarkColor: AppTheme.accentMagenta,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.accentMagenta : AppTheme.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentMagenta))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.accentMagenta)))
                    : _results.isEmpty
                        ? const Center(
                            child: Text('Search for your favorite music',
                                style: TextStyle(color: AppTheme.textSecondary)))
                        : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_filter == SearchFilter.artists) {
      return ListView.builder(
        itemCount: _results.length,
        itemBuilder: (ctx, i) => _ArtistTile(item: _results[i]),
      );
    } else if (_filter == SearchFilter.albums) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: _results.length,
        itemBuilder: (ctx, i) => _AlbumGridItem(item: _results[i], onTap: () => _playAlbum(i)),
      );
    } else {
      // Filter to track results only for proper indexing
      final trackResults = _results.where((r) => r['_type'] == 'track').toList();
      return ListView.builder(
        itemCount: trackResults.length,
        itemBuilder: (ctx, i) => TrackTile(
          item: trackResults[i],
          index: i + 1,
          onTap: () => _playTrack(i),
          onDownload: () => _downloadTrack(trackResults[i]),
          onFavorite: () => _toggleFavorite(trackResults[i]),
          isFavorite: _favoriteIds.contains(trackResults[i]['id']),
        ),
      );
    }
  }

  void _playTrack(int index) {
    final trackResults = _results.where((r) => r['_type'] == 'track').toList();
    final mediaItems = trackResults.map((t) => MediaItem(
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

    ref.read(queueProvider.notifier).setQueue(trackResults, initialIndex: index);
    ref.read(queueProvider.notifier).setPlaying(true);
  }

  void _playAlbum(int index) async {
    final results = _results.where((r) => r['_type'] == 'album').toList();
    if (index >= results.length) return;
    final album = results[index];
    final albumId = album['id'] as int;
    try {
      final client = getIt<DeezerApiClient>();
      final token = await getIt<SecureStorage>().getDeezerAccessToken();
      if (token == null) return;
      client.setAccessToken(token);

      final tracks = await client.getAlbumTracks(albumId);
      final trackMaps = tracks.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist?.name ?? 'Unknown',
        'album': album['title'],
        'album_cover': album['album_cover'] ?? '',
        'duration': t.duration,
        'preview': t.preview,
        'artist_id': t.artist?.id,
        'album_id': albumId,
      }).toList();

      if (trackMaps.isEmpty) return;

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
      // Silently fail — album tracks loading is best-effort
    }
  }

  void _downloadTrack(Map<String, dynamic> track) async {
    final id = track['id'] as int?;
    if (id == null) return;
    try {
      final db = getIt<LocalDbService>();
      final alreadyDownloaded = await db.isDownloaded(id);
      if (alreadyDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already downloaded'),
              backgroundColor: AppTheme.bgCard, duration: Duration(seconds: 1)),
        );
        return;
      }
      final path = await db.downloadTrack(track);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: ${track['title']}'),
              backgroundColor: AppTheme.bgCard, duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'),
            backgroundColor: AppTheme.bgCard, duration: const Duration(seconds: 2)),
      );
    }
  }
}

class _ArtistTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ArtistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipOval(
        child: item['artist_cover'] != null
            ? Image.network(item['artist_cover'], width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: AppTheme.bgCard))
            : Container(width: 48, height: 48, color: AppTheme.bgCard),
      ),
      title: Text(item['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: const Text('Artist', style: TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _AlbumGridItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _AlbumGridItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item['album_cover'] != null
                  ? Image.network(item['album_cover'], width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppTheme.bgCard,
                          child: const Icon(Icons.album, color: AppTheme.textSecondary)))
                  : Container(color: AppTheme.bgCard,
                      child: const Icon(Icons.album, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          Text(item['title'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(item['artist'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
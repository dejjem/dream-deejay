import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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

class _SavedTab extends ConsumerWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Load from local DB (isar/hive) the user's liked tracks
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text('No saved tracks yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          SizedBox(height: 8),
          Text('Tap the heart icon on any track to save it',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Load user playlists from Deezer API
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text('No playlists yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          SizedBox(height: 8),
          Text('Create playlists in Deezer to see them here',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Show offline-downloaded tracks
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 64, color: AppTheme.accentCyan),
          const SizedBox(height: 16),
          const Text('Offline Mode', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Tap the download icon on any track\nto save it for offline playback',
              style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
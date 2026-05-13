import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/queue/queue_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/now_playing/now_playing_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    QueueScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentNavIndexProvider);
    final queue = ref.watch(queueProvider);
    final hasActiveTrack = queue.tracks.isNotEmpty;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player strip
          if (hasActiveTrack)
            _MiniPlayerStrip(
              onTap: () => _openNowPlaying(context),
            ),
          BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (i) => ref.read(currentNavIndexProvider.notifier).state = i,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music),
                label: 'Queue',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NowPlayingScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

class _MiniPlayerStrip extends ConsumerWidget {
  const _MiniPlayerStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final currentTrack = queue.currentTrack;
    if (currentTrack == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: const Border(
            top: BorderSide(color: AppTheme.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: currentTrack['album_cover'] != null
                  ? Image.network(
                      currentTrack['album_cover'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: AppTheme.divider,
                        child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: AppTheme.divider,
                      child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                    ),
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTrack['title'] ?? 'Unknown',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentTrack['artist'] ?? 'Unknown artist',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play/Pause
            IconButton(
              icon: Icon(
                queue.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: AppTheme.accentMagenta,
                size: 40,
              ),
              onPressed: () {
                final handler = audioHandler;
                if (queue.isPlaying) {
                  handler.pause();
                } else {
                  handler.play();
                }
                ref.read(queueProvider.notifier).setPlaying(!queue.isPlaying);
              },
            ),
          ],
        ),
      ),
    );
  }
}
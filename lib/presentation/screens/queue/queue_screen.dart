import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import 'package:dream_deejay/main.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (queue.tracks.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(queueProvider.notifier).clear();
                audioHandler.stop();
              },
              child: const Text('Clear', style: TextStyle(color: AppTheme.accentMagenta)),
            ),
        ],
      ),
      body: queue.tracks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('Your queue is empty', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Add tracks from Home or Search', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: queue.tracks.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                ref.read(queueProvider.notifier).reorder(oldIndex, newIndex);
                audioHandler.onCustomAction('reorderQueue', {'from': oldIndex, 'to': newIndex});
              },
              itemBuilder: (ctx, i) {
                final track = queue.tracks[i];
                final isActive = i == queue.currentIndex;

                return _QueueTile(
                  key: ValueKey('${track['id']}_$i'),
                  track: track,
                  index: i,
                  isActive: isActive,
                  onTap: () {
                    ref.read(queueProvider.notifier).setCurrentIndex(i);
                    audioHandler.skipToQueueItem(i);
                    audioHandler.play();
                    ref.read(queueProvider.notifier).setPlaying(true);
                  },
                  onRemove: () {
                    ref.read(queueProvider.notifier).removeTrack(i);
                    audioHandler.removeQueueItemAt(i);
                  },
                );
              },
            ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Map<String, dynamic> track;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueTile({
    super.key,
    required this.track,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${track['id']}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: AppTheme.accentMagenta,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentMagenta.withOpacity(0.1) : Colors.transparent,
          border: isActive ? const Border(
            left: BorderSide(color: AppTheme.accentMagenta, width: 3),
          ) : null,
        ),
        child: ListTile(
          onTap: onTap,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: track['album_cover'] != null
                    ? Image.network(track['album_cover'], width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderArt())
                    : _PlaceholderArt(),
              ),
            ],
          ),
          title: Text(
            track['title'] ?? 'Unknown',
            style: TextStyle(
              color: isActive ? AppTheme.accentMagenta : AppTheme.textPrimary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track['artist'] ?? 'Unknown',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: track['duration'] != null
              ? Text(
                  _formatDuration(Duration(seconds: track['duration'] as int)),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                )
              : null,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlaceholderArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      color: AppTheme.bgCard,
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary, size: 20),
    );
  }
}
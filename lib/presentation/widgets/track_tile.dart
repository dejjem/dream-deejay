import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TrackTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final VoidCallback? onFavorite;
  final bool showDownload;
  final bool isFavorite;

  const TrackTile({
    super.key,
    required this.item,
    this.index,
    this.onTap,
    this.onLongPress,
    this.onDownload,
    this.onFavorite,
    this.showDownload = true,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = item['duration'] as int?;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index != null)
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: item['album_cover'] != null && item['album_cover'].toString().isNotEmpty
                ? Image.network(
                    item['album_cover'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _PlaceholderArt(),
                  )
                : _PlaceholderArt(),
          ),
        ],
      ),
      title: Text(
        item['title'] ?? 'Unknown',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item['artist'] ?? 'Unknown',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onFavorite != null)
            SizedBox(
              width: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                ),
                color: AppTheme.accentMagenta,
                onPressed: onFavorite,
              ),
            ),
          if (onDownload != null && showDownload)
            SizedBox(
              width: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.download_outlined, size: 20),
                color: AppTheme.accentCyan,
                onPressed: onDownload,
              ),
            ),
          if (duration != null)
            Text(
              _formatDuration(Duration(seconds: duration)),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          else
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
        ],
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary, size: 20),
    );
  }
}
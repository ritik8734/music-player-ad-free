import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/music_service.dart';
import 'playing_indicator.dart';

class SongListTile extends StatelessWidget {
  final SongModel song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool isPinned;
  final VoidCallback? onPinToggle;
  final VoidCallback? onChangeDate;
  final VoidCallback? onDelete;

  const SongListTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.isPinned = false,
    this.onPinToggle,
    this.onChangeDate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 50,
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                size: 150,
                quality: 75,
                artworkBorder: BorderRadius.circular(8),
                artworkFit: BoxFit.cover,
                artworkQuality: FilterQuality.medium,
                nullArtworkWidget: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.6),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          if (isPinned)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.push_pin,
                  size: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isPlaying
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
          ),
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.push_pin,
                size: 14,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Unknown Album'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isPlaying
          ? PlayingIndicator(
              color: Theme.of(context).colorScheme.primary,
            )
          : Text(
              song.formattedDuration,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: onTap,
      onLongPress: () => _showOptions(context),
    );
  }

  void _showOptions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromCenter(
          center: renderBox.localToGlobal(renderBox.size.center(Offset.zero), ancestor: overlay),
          width: 0,
          height: 0,
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(isPinned ? 'Unpin from top' : 'Pin to top'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'date',
          child: const Row(
            children: [
              Icon(Icons.edit_calendar, size: 20),
              SizedBox(width: 12),
              Text('Change date added'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'pin') {
        onPinToggle?.call();
      } else if (value == 'date') {
        onChangeDate?.call();
      } else if (value == 'delete') {
        onDelete?.call();
      }
    });
  }
}

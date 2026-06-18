import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/music_provider.dart';
import '../widgets/song_list_tile.dart';
import 'now_playing_screen.dart';

class MusicLibraryScreen extends StatelessWidget {
  const MusicLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort songs',
            onSelected: (value) {
              switch (value) {
                case 'title':
                  context.read<MusicProvider>().setSortType(SongSortType.TITLE, OrderType.ASC_OR_SMALLER);
                  break;
                case 'artist':
                  context.read<MusicProvider>().setSortType(SongSortType.ARTIST, OrderType.ASC_OR_SMALLER);
                  break;
                case 'last_added':
                  context.read<MusicProvider>().setSortType(SongSortType.DATE_ADDED, OrderType.DESC_OR_GREATER);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 20),
                    SizedBox(width: 12),
                    Text('Title (A-Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'artist',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Artist'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'last_added',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Last Added'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MusicProvider>().scanSongs(),
            tooltip: 'Refresh',
          ),
        ],
      ),

      body: Consumer<MusicProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon with rings
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer animated ring
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: provider.scanningPercent),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) {
                                return CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 8,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  color: Theme.of(context).colorScheme.primary,
                                  strokeCap: StrokeCap.round,
                                );
                              },
                            ),
                          ),
                          // Inner circle with icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.tertiary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_library_music_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      // Title
                      Text(
                        'Scanning Library',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Subtitle
                      Text(
                        'Looking for audio files on your device.\nThis might take a moment.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Fancy percentage pill
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: provider.scanningPercent),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(value * 100).toInt()}% Complete',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (!provider.isPermissionGranted) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Storage permission is required',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please grant storage permission\nto scan your music files',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.scanSongs(),
                    icon: const Icon(Icons.security),
                    label: const Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.scanSongs(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.allSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No music files found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text('Add some music files to your device'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _FilterTab(
                      label: 'Songs',
                      icon: Icons.music_note,
                      isSelected: provider.currentFilter == MusicFilter.songs,
                      onTap: () => provider.setFilter(MusicFilter.songs),
                    ),
                    _FilterTab(
                      label: 'Albums',
                      icon: Icons.album,
                      isSelected: provider.currentFilter == MusicFilter.albums,
                      onTap: () => provider.setFilter(MusicFilter.albums),
                    ),
                    _FilterTab(
                      label: 'Artists',
                      icon: Icons.person,
                      isSelected: provider.currentFilter == MusicFilter.artists,
                      onTap: () => provider.setFilter(MusicFilter.artists),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: provider.currentFilter == MusicFilter.songs
                        ? 'Search songs, artists, albums...'
                        : provider.currentFilter == MusicFilter.albums
                        ? 'Search albums...'
                        : 'Search artists...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: provider.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => provider.setSearchQuery(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),

              // Content based on filter
              Expanded(child: _buildContent(context, provider)),
            ],
          );
        },
      ),
      // Mini player at bottom
      bottomNavigationBar: Consumer<MusicProvider>(
        builder: (context, provider, child) {
          if (provider.currentSong == null) {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NowPlayingScreen(),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  StreamBuilder<Duration>(
                    stream: provider.playerService.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = provider.duration;
                      return LinearProgressIndicator(
                        value: duration != null && duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0,
                        minHeight: 5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.currentSong!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                provider.currentSong!.artist ??
                                    'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Previous button
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: provider.previous,
                        ),
                        // Play/Pause button
                        IconButton(
                          icon: Icon(
                            provider.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: provider.togglePlayPause,
                        ),
                        // Next button
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: provider.next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, MusicProvider provider) {
    switch (provider.currentFilter) {
      case MusicFilter.songs:
        return _buildSongsList(context, provider);
      case MusicFilter.albums:
        return _buildAlbumsGrid(context, provider);
      case MusicFilter.artists:
        return _buildArtistsList(context, provider);
    }
  }

  Widget _buildSongsList(BuildContext context, MusicProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.displayedSongs.length} song${provider.displayedSongs.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (provider.currentSong != null)
                Text(
                  'Now: ${provider.currentSong!.title}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: provider.displayedSongs.length,
            itemBuilder: (context, index) {
              final song = provider.displayedSongs[index];
              final isCurrentSong = provider.currentSong?.id == song.id;
              final isPinned = provider.metadataService.isPinned(song);
              return SongListTile(
                song: song,
                index: index,
                isPlaying: isCurrentSong && provider.isPlaying,
                isPinned: isPinned,
                onTap: () {
                  provider.playSong(song);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NowPlayingScreen(),
                    ),
                  );
                },
                onPinToggle: () => provider.togglePinSong(song),
                onChangeDate: () => _showChangeDateDialog(context, provider, song),
                onDelete: () => _confirmDeleteSong(context, provider, song),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDeleteSong(BuildContext context, MusicProvider provider, SongModel song) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete song'),
          content: Text(
            'Are you sure you want to delete "${song.title}"?\n\n'
            'This will permanently remove the file from your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final deleted = await provider.deleteSong(song);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      deleted ? '"${song.title}" deleted' : 'Failed to delete "${song.title}"',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showChangeDateDialog(BuildContext context, MusicProvider provider, SongModel song) {
    // Show a date/time picker to change the "date added" of a song
    final initialDate = DateTime.fromMillisecondsSinceEpoch(
      provider.metadataService.effectiveDateAdded(song),
    );

    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Change date added for "${song.title}"',
    ).then((pickedDate) {
      if (pickedDate == null) return;
      if (!context.mounted) return;

      showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: 'Select time',
      ).then((pickedTime) {
        if (pickedTime == null) return;
        if (!context.mounted) return;

        final combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        provider.setCustomDateAdded(song, combined);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Date updated for "${song.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });
  }

  Widget _buildAlbumsGrid(BuildContext context, MusicProvider provider) {
    final filteredAlbums = provider.albums.where((album) {
      if (provider.searchQuery.isEmpty) return true;
      return album.toLowerCase().contains(provider.searchQuery.toLowerCase());
    }).toList();

    if (filteredAlbums.isEmpty) {
      return const Center(child: Text('No albums found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredAlbums.length,
      itemBuilder: (context, index) {
        final albumName = filteredAlbums[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.album,
                    size: 60,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  albumName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsList(BuildContext context, MusicProvider provider) {
    final filteredArtists = provider.artists.where((artist) {
      if (provider.searchQuery.isEmpty) return true;
      return artist.toLowerCase().contains(provider.searchQuery.toLowerCase());
    }).toList();

    if (filteredArtists.isEmpty) {
      return const Center(child: Text('No artists found'));
    }

    return ListView.builder(
      itemCount: filteredArtists.length,
      itemBuilder: (context, index) {
        final artist = filteredArtists[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.2),
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(artist),
          subtitle: Text(
            '${provider.allSongs.where((s) => s.artist == artist).length} songs',
          ),
        );
      },
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

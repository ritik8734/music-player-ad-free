import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../services/song_metadata_service.dart';

enum MusicFilter { songs, albums, artists }

class MusicProvider extends ChangeNotifier {
  final MusicService _musicService = MusicService();
  final PlayerService _playerService = PlayerService();
  final SongMetadataService _metadataService = SongMetadataService();
  Timer? _rescanTimer;
  Set<String> _lastSongPaths = {};

  MusicFilter _currentFilter = MusicFilter.songs;
  List<String> _albums = [];
  List<String> _artists = [];

  List<SongModel> _allSongs = [];
  List<SongModel> _displayedSongs = [];
  SongModel? _currentSong;
  bool _isLoading = false;
  double _scanningPercent = 0.0;
  bool _isPermissionGranted = false;
  String? _error;
  String _searchQuery = '';
  SongSortType _sortType = SongSortType.DATE_ADDED;
  OrderType _orderType = OrderType.DESC_OR_GREATER;

  // Player state
  Duration _position = Duration.zero;
  Duration? _duration;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _loadingPercent = 0.0;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleEnabled = false;

  // Getters
  List<SongModel> get allSongs => _allSongs;
  List<SongModel> get displayedSongs => _displayedSongs;
  SongModel? get currentSong => _currentSong;
  bool get isLoading => _isLoading;
  double get scanningPercent => _scanningPercent;
  bool get isPermissionGranted => _isPermissionGranted;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  SongSortType get sortType => _sortType;
  OrderType get orderType => _orderType;

  Duration get position => _position;
  Duration get bufferedPosition => _bufferedPosition;
  Duration? get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  double get loadingPercent => _loadingPercent;
  LoopMode get loopMode => _loopMode;
  bool get shuffleEnabled => _shuffleEnabled;

  PlayerService get playerService => _playerService;
  SongMetadataService get metadataService => _metadataService;
  MusicFilter get currentFilter => _currentFilter;
  List<String> get albums => _albums;
  List<String> get artists => _artists;

  void setFilter(MusicFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> loadAlbums() async {
    _albums = _allSongs
        .map((s) => s.album ?? 'Unknown Album')
        .toSet()
        .toList()
      ..sort();
    notifyListeners();
  }

  Future<void> loadArtists() async {
    _artists = _allSongs
        .map((s) => s.artist ?? 'Unknown Artist')
        .toSet()
        .toList()
      ..sort();
    notifyListeners();
  }

  Future<void> init() async {
    try {
      await _playerService.init();
    } catch (e) {
      debugPrint('PlayerService.init failed: $e');
      // Continue — playback and UI streams still work without notification service
    }
    await _metadataService.load();
    _listenToPlayerState();
    await scanSongs();
    await Future.wait([loadAlbums(), loadArtists()]);
    _startAutoRescan();
  }

  void _startAutoRescan() {
    _rescanTimer?.cancel();
    // Run once after 30 seconds to catch any changes during startup, then stop
    _rescanTimer = Timer(const Duration(seconds: 30), () {
      _checkForLibraryChanges();
      _rescanTimer = null;
    });
  }

  Future<void> _checkForLibraryChanges() async {
    try {
      final songs = await _musicService.scanSongs();
      final currentPaths = songs.map((s) => s.data).toSet();

      final hasNewSongs = currentPaths.difference(_lastSongPaths).isNotEmpty;
      final hasRemovedSongs = _lastSongPaths.difference(currentPaths).isNotEmpty;

      if (hasNewSongs || hasRemovedSongs) {
        _allSongs = songs;
        _lastSongPaths = currentPaths;
        _applySearchFilter();
        notifyListeners();
      }
    } catch (e) {
      // Silently ignore rescan errors
    }
  }

  Future<void> scanSongs() async {
    _isLoading = true;
    _scanningPercent = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Simulate scanning progress since on_audio_query doesn't provide progress
      final scanFuture = _musicService.scanSongs(
        sortType: _sortType,
        orderType: _orderType,
      );
      while (!await Future.any([
        scanFuture.then((_) => true),
        Future.delayed(const Duration(milliseconds: 100), () => false),
      ])) {
        _scanningPercent = (_scanningPercent + 0.05).clamp(0.0, 0.95);
        notifyListeners();
      }

      _allSongs = await scanFuture;

      // Apply custom date-added overrides: re-sort using the effective date
      // if sorted by DATE_ADDED
      if (_sortType == SongSortType.DATE_ADDED) {
        _applyEffectiveDateSort();
      }

      // Always move pinned songs to the top, regardless of sort mode
      _applyPinnedSortToAll();

      _scanningPercent = 1.0;
      _lastSongPaths = _allSongs.map((s) => s.data).toSet();
      _isPermissionGranted = true;
      _applySearchFilter();
    } catch (e) {
      _error = e.toString();
      // Only mark permission as not granted if the error is actually about permission
      if (e.toString().toLowerCase().contains('permission')) {
        _isPermissionGranted = false;
      }
    } finally {
      _isLoading = false;
      _scanningPercent = 0.0;
      notifyListeners();
    }
  }

  /// Re-sort _allSongs using the effective date added (custom override if set).
  /// Pinned sort is applied separately after this.
  void _applyEffectiveDateSort() {
    _allSongs.sort((a, b) {
      final aDate = _metadataService.effectiveDateAdded(a);
      final bDate = _metadataService.effectiveDateAdded(b);
      return _orderType == OrderType.DESC_OR_GREATER
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });
  }

  /// Reorder _allSongs so that pinned songs appear at the top while preserving
  /// the relative order within each group.
  void _applyPinnedSortToAll() {
    _allSongs = _metadataService.applyPinnedSort(_allSongs);
  }

  void setSortType(SongSortType sortType, OrderType orderType) {
    _sortType = sortType;
    _orderType = orderType;
    scanSongs();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _displayedSongs = List.from(_allSongs);
    } else {
      _displayedSongs = _allSongs.where((song) {
        final query = _searchQuery.toLowerCase();
        final title = song.title.toLowerCase();
        final artist = (song.artist ?? '').toLowerCase();
        final album = (song.album ?? '').toLowerCase();
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    }
  }

  /// Toggle pin state for a song.
  /// Pinning updates the MediaStore DATE_ADDED so the song appears at the
  /// top of "Recently Added" in ALL music apps on the device.
  Future<void> togglePinSong(SongModel song) async {
    final wasPinned = _metadataService.isPinned(song);
    await _metadataService.togglePin(song);
    final nowPinned = !wasPinned;

    if (nowPinned) {
      // Update the actual MediaStore DATE_ADDED on the device so the song
      // appears at the top in all music apps when sorted by "Recently Added"
      final success = await _musicService.pinSongGlobally(song);
      if (success) {
        // Also set an in-app custom date to now for instant local re-order
        await _metadataService.setCustomDateAdded(song, DateTime.now());
      }
    } else {
      // Unpinning: clear the custom date override to restore original order
      await _metadataService.clearCustomDateAdded(song);
    }

    // Re-sort: if DATE_ADDED mode, use effective dates; then always pin to top
    if (_sortType == SongSortType.DATE_ADDED) {
      _applyEffectiveDateSort();
    }
    _applyPinnedSortToAll();
    _applySearchFilter();
    notifyListeners();
  }

  /// Set a custom date added for a song and re-sort if on DATE_ADDED sort.
  Future<void> setCustomDateAdded(SongModel song, DateTime date) async {
    await _metadataService.setCustomDateAdded(song, date);
    if (_sortType == SongSortType.DATE_ADDED) {
      _applyEffectiveDateSort();
    }
    // Pinned songs always go to top regardless of sort mode
    _applyPinnedSortToAll();
    _applySearchFilter();
    notifyListeners();
  }

  /// Clear custom date override for a song, reverting to original.
  Future<void> clearCustomDateAdded(SongModel song) async {
    await _metadataService.clearCustomDateAdded(song);
    if (_sortType == SongSortType.DATE_ADDED) {
      _applyEffectiveDateSort();
    }
    // Pinned songs always go to top regardless of sort mode
    _applyPinnedSortToAll();
    _applySearchFilter();
    notifyListeners();
  }

  Future<void> playSong(SongModel song) async {
    await _playerService.playSong(song, _displayedSongs);
    _currentSong = _playerService.currentSong;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _playerService.togglePlayPause();
  }

  Future<void> next() async {
    await _playerService.next();
    _currentSong = _playerService.currentSong;
    notifyListeners();
  }

  Future<void> previous() async {
    await _playerService.previous();
    _currentSong = _playerService.currentSong;
    notifyListeners();
  }

  Future<bool> deleteSong(SongModel song) async {
    final deleted = await _musicService.deleteSong(song);

    if (deleted) {
      // If the deleted song is currently playing, stop playback
      if (_currentSong?.id == song.id) {
        await _playerService.pause();
        _currentSong = null;
      }
      // Remove from lists
      _allSongs.removeWhere((s) => s.id == song.id);
      _lastSongPaths.remove(song.data);
      _applySearchFilter();
      loadAlbums();
      loadArtists();
      notifyListeners();
    }
    return deleted;
  }

  Future<void> seekTo(Duration position) async {
    await _playerService.seekTo(position);
  }

  Future<void> toggleLoopMode() async {
    await _playerService.toggleLoopMode();
    _loopMode = _playerService.loopMode;
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    await _playerService.enableShuffle(_shuffleEnabled);
    notifyListeners();
  }

  StreamSubscription? _playerStateSub;
  StreamSubscription? _isPlayingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedPositionSub;
  StreamSubscription? _loopModeSub;
  StreamSubscription? _shuffleSub;
  StreamSubscription? _currentIndexSub;

  void _listenToPlayerState() {
    _playerStateSub = _playerService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
                     state.processingState == ProcessingState.loading;
      notifyListeners();
    });

    // Direct playing state notifier - reliable source of truth
    _isPlayingSub = _playerService.isPlayingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _positionSub = _playerService.positionStream.listen((pos) {
      _position = pos;
      // Do not call notifyListeners() here to prevent excessive rebuilds.
      // UIs requiring position should use StreamBuilder on provider.playerService.positionStream
    });

    _durationSub = _playerService.durationStream.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _bufferedPositionSub = _playerService.bufferedPositionStream.listen((buffered) {
      _bufferedPosition = buffered;
      if (_duration != null && _duration!.inMilliseconds > 0) {
        _loadingPercent = buffered.inMilliseconds / _duration!.inMilliseconds;
      } else {
        _loadingPercent = 0.0;
      }
      // Do not call notifyListeners() here to prevent excessive rebuilds.
    });

    _loopModeSub = _playerService.loopModeStream.listen((mode) {
      _loopMode = mode;
      notifyListeners();
    });

    _shuffleSub = _playerService.shuffleModeEnabledStream.listen((enabled) {
      _shuffleEnabled = enabled;
      notifyListeners();
    });

    // Listen for automatic track changes (when song ends and next starts)
    _currentIndexSub = _playerService.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _playerService.songs.length) {
        _currentSong = _playerService.songs[index];
        _playerService.updateNotification(_currentSong!);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _rescanTimer?.cancel();
    _playerStateSub?.cancel();
    _isPlayingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    _loopModeSub?.cancel();
    _shuffleSub?.cancel();
    _currentIndexSub?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

class PlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioHandler? _audioHandler;
  MusicAudioHandler? _innerAudioHandler;
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  List<SongModel> _songs = [];
  int _currentIndex = -1;

  AudioPlayer get audioPlayer => _audioPlayer;
  List<SongModel> get songs => _songs;
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _songs.length
      ? _songs[_currentIndex]
      : null;

  // Direct playing state notifier for reliable UI updates
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject<bool>.seeded(
    false,
  );

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration> get bufferedPositionStream =>
      _audioPlayer.bufferedPositionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<LoopMode> get loopModeStream => _audioPlayer.loopModeStream;
  Stream<bool> get shuffleModeEnabledStream =>
      _audioPlayer.shuffleModeEnabledStream;
  Stream<int?> get currentIndexStream =>
      _audioPlayer.sequenceStateStream.map((state) => state?.currentIndex);

  // Combined stream for UI state
  Stream<PlayerStateInfo> get playerStateInfoStream =>
      Rx.combineLatest2<PlayerState, Duration?, PlayerStateInfo>(
        playerStateStream,
        durationStream,
        (playerState, duration) => PlayerStateInfo(
          processingState: playerState.processingState,
          playing: playerState.playing,
          duration: duration,
        ),
      );

  Future<void> init() async {
    try {
      _innerAudioHandler = MusicAudioHandler(_audioPlayer, isPlayingNotifier);
      _audioHandler = await AudioService.init(
        builder: () => _innerAudioHandler!,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.music_player.channel.audio',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      debugPrint('AudioService.init failed: $e');
      // Continue without notification controls — playback still works
    }
    // Keep isPlayingNotifier synced with actual player state as safety net
    _audioPlayer.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      _isPlayingSubject.add(state.playing);
    });
    // Don't set audio source on empty playlist - it will be set in setPlaylist()
  }

  Future<void> setPlaylist(
    List<SongModel> songs, {
    int initialIndex = 0,
  }) async {
    _songs = songs;
    _currentIndex = initialIndex;

    _playlist.clear();
    for (final song in songs) {
      _playlist.add(AudioSource.uri(Uri.file(song.data), tag: song));
    }

    await _audioPlayer.setAudioSource(_playlist, initialIndex: initialIndex);
  }

  Future<void> playSong(SongModel song, List<SongModel> playlist) async {
    final index = playlist.indexOf(song);
    if (index == -1) {
      await setPlaylist([song]);
    } else {
      if (!identical(_songs, playlist)) {
        await setPlaylist(playlist, initialIndex: index);
      } else {
        await seekToIndex(index);
      }
    }
    updateNotification(song);
    await play();
  }

  Future<void> seekToIndex(int index) async {
    if (index >= 0 && index < _songs.length) {
      _currentIndex = index;
      await _audioPlayer.seek(Duration.zero, index: index);
    }
  }

  Future<void> play() async {
    isPlayingNotifier.value = true;
    await _audioPlayer.play();
    _broadcastPlaybackState();
  }

  Future<void> pause() async {
    isPlayingNotifier.value = false;
    await _audioPlayer.pause();
    _broadcastPlaybackState();
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    if (_currentIndex < _songs.length - 1) {
      await seekToIndex(_currentIndex + 1);
      updateNotification(_songs[_currentIndex]);
      await play();
    }
  }

  Future<void> previous() async {
    // If playing for more than 3 seconds, restart current song
    if (_audioPlayer.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      await seekToIndex(_currentIndex - 1);
      updateNotification(_songs[_currentIndex]);
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _audioPlayer.setLoopMode(mode);
  }

  Future<void> toggleLoopMode() async {
    final currentMode = _audioPlayer.loopMode;
    switch (currentMode) {
      case LoopMode.off:
        await setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await setLoopMode(LoopMode.off);
        break;
    }
  }

  LoopMode get loopMode => _audioPlayer.loopMode;

  Future<void> enableShuffle(bool enabled) async {
    await _audioPlayer.setShuffleModeEnabled(enabled);
  }

  bool get isShuffleEnabled => _audioPlayer.shuffleModeEnabled;

  void updateNotification(SongModel song) {
    _innerAudioHandler?.setMediaItem(song);
  }

  /// Manually push current playback state to the notification
  void _broadcastPlaybackState() {
    _innerAudioHandler?.broadcastCurrentState();
  }

  void dispose() {
    _audioHandler?.stop();
    isPlayingNotifier.dispose();
    _isPlayingSubject.close();
    _audioPlayer.dispose();
  }
}

class PlayerStateInfo {
  final ProcessingState processingState;
  final bool playing;
  final Duration? duration;

  PlayerStateInfo({
    required this.processingState,
    required this.playing,
    this.duration,
  });
}

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final ValueNotifier<bool> isPlayingNotifier;

  MusicAudioHandler(this._player, this.isPlayingNotifier) {
    // Broadcast state on every playback event (position updates, state changes)
    _player.playbackEventStream.listen((_) => broadcastCurrentState());

    // Keep mediaItem duration in sync
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  Future<void> setMediaItem(SongModel song) async {
    // Initial media item with placeholder or no artwork
    final item = MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album ?? 'Unknown Album',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: Uri.parse("https://i.imgur.com/8Km9tLL.jpg"), // Placeholder
    );
    mediaItem.add(item);
    broadcastCurrentState();

    // Fetch and save actual artwork
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 500,
      );

      if (artwork != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/song_${song.id}.jpg');
        await file.writeAsBytes(artwork);
        
        mediaItem.add(item.copyWith(artUri: Uri.file(file.path)));
        broadcastCurrentState();
      }
    } catch (e) {
      debugPrint('Error fetching artwork for notification: $e');
    }
  }

  void broadcastCurrentState() {
    // Only broadcast when we have a media item set
    if (mediaItem.value == null) return;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    isPlayingNotifier.value = true;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    isPlayingNotifier.value = false;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.currentIndex != null &&
        _player.currentIndex! < _player.sequence!.length - 1) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.currentIndex != null && _player.currentIndex! > 0) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}

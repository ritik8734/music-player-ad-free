import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
extension SongModelExt on SongModel {
  String get formattedDuration {
    final dur = duration ?? 0;
    final minutes = dur ~/ 60000;
    final seconds = (dur % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MusicService {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _isPermissionGranted = false;

  bool get isPermissionGranted => _isPermissionGranted;

  Future<bool> requestPermission() async {
    if (_isPermissionGranted) return true;

    if (Platform.isAndroid) {
      final sdkInt = await DeviceInfoPlugin().androidInfo;

      if (sdkInt.version.sdkInt >= 33) {
        // Android 13+
        final audioResult = await Permission.audio.request();
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
        
        if (audioResult.isGranted) {
          _isPermissionGranted = true;
          return true;
        }
      } else {
        // Android <= 12
        final storageResult = await Permission.storage.request();
        if (storageResult.isGranted) {
          _isPermissionGranted = true;
          return true;
        }
      }
    } else {
      // For iOS and other platforms, use on_audio_query's built-in request
      _isPermissionGranted = await _audioQuery.permissionsRequest();
      if (_isPermissionGranted) return true;
    }

    return false;
  }
  /// Minimum duration in milliseconds to consider a file as a song (1 minute)
  static const int _minDurationMs = 60000;

  Future<List<SongModel>> scanSongs({
    SongSortType sortType = SongSortType.TITLE,
    OrderType orderType = OrderType.ASC_OR_SMALLER,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Storage permission is required to scan music files');
    }

    final songs = await _audioQuery.querySongs(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
    );

    // Only show songs longer than 1 minute (filters out ringtones, notifications, etc.)
    return songs.where((song) => (song.duration ?? 0) >= _minDurationMs).toList();
  }

  static const _mediaChannel = MethodChannel('com.example.music_player/media_delete');
  static const _pinChannel = MethodChannel('com.example.music_player/media_pin');

  /// Delete a song file from the device using MediaStore API (scoped storage safe)
  Future<bool> deleteSong(SongModel song) async {
    try {
      final result = await _mediaChannel.invokeMethod<bool>(
        'deleteSong',
        {'path': song.data},
      );
      return result == true;
    } catch (e) {
      debugPrint('deleteSong error: $e');
      return false;
    }
  }

  /// Pin a song globally by updating its MediaStore DATE_ADDED to the current time.
  /// This makes the song appear at the top of "Recently Added" in ALL music apps.
  Future<bool> pinSongGlobally(SongModel song) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _pinChannel.invokeMethod<bool>(
        'pinSongGlobally',
        {'path': song.data},
      );
      return result == true;
    } catch (e) {
      debugPrint('pinSongGlobally error: $e');
      return false;
    }
  }

  Future<List<SongModel>> searchSongs(String query, List<SongModel> allSongs) async {
    if (query.isEmpty) return allSongs;

    final lowerQuery = query.toLowerCase();
    return allSongs.where((song) {
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      final album = (song.album ?? '').toLowerCase();
      return title.contains(lowerQuery) ||
          artist.contains(lowerQuery) ||
          album.contains(lowerQuery);
    }).toList();
  }

  Future<List<String>> scanAlbums() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final albums = await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    return albums.map((album) => album.album).toList();
  }

  Future<List<String>> scanArtists() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );

    final artists = songs
        .map((song) => song.artist ?? 'Unknown Artist')
        .toSet()
        .toList();

    return artists;
  }

  Future<dynamic> getAlbumArt(int albumId) async {
    return await _audioQuery.queryArtwork(albumId, ArtworkType.AUDIO);
  }
}
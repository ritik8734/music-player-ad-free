import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Stores local metadata overrides for songs (pinned state, custom date added)
/// using shared_preferences. These overrides are applied on top of the
/// read-only device metadata from on_audio_query.
class SongMetadataService {
  static const _pinnedKey = 'pinned_songs'; // Set of song IDs (as string)
  static const _dateOverridesKey = 'date_overrides'; // JSON map of song ID -> timestamp millis

  Set<String> _pinnedIds = {};
  Map<int, int> _dateOverrides = {}; // song.id -> custom dateAdded timestamp

  Set<String> get pinnedIds => Set.unmodifiable(_pinnedIds);
  Map<int, int> get dateOverrides => Map.unmodifiable(_dateOverrides);

  bool isPinned(SongModel song) => _pinnedIds.contains(song.id.toString());
  bool isPinnedById(int songId) => _pinnedIds.contains(songId.toString());

  /// Returns the effective date added for sorting: custom override if set,
  /// otherwise the original dateAdded from the song model.
  int effectiveDateAdded(SongModel song) {
    return _dateOverrides[song.id] ?? song.dateAdded ?? 0;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load pinned IDs
    final pinnedList = prefs.getStringList(_pinnedKey) ?? [];
    _pinnedIds = pinnedList.toSet();

    // Load date overrides
    final dateJson = prefs.getString(_dateOverridesKey);
    if (dateJson != null) {
      try {
        final decoded = jsonDecode(dateJson) as Map<String, dynamic>;
        _dateOverrides = decoded.map(
          (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
        );
      } catch (e) {
        debugPrint('Failed to load date overrides: $e');
        _dateOverrides = {};
      }
    }
  }

  /// Pin a song so it appears at the top of the list.
  Future<void> pinSong(SongModel song) async {
    _pinnedIds.add(song.id.toString());
    await _savePinned();
  }

  /// Remove pin from a song.
  Future<void> unpinSong(SongModel song) async {
    _pinnedIds.remove(song.id.toString());
    await _savePinned();
  }

  /// Toggle pin state for a song. Returns the new pin state (true = pinned).
  Future<bool> togglePin(SongModel song) async {
    if (_pinnedIds.contains(song.id.toString())) {
      await unpinSong(song);
      return false;
    } else {
      await pinSong(song);
      return true;
    }
  }

  /// Set a custom date added for a song (in milliseconds since epoch).
  Future<void> setCustomDateAdded(SongModel song, DateTime date) async {
    _dateOverrides[song.id] = date.millisecondsSinceEpoch;
    await _saveDateOverrides();
  }

  /// Remove custom date override, reverting to the original dateAdded.
  Future<void> clearCustomDateAdded(SongModel song) async {
    _dateOverrides.remove(song.id);
    await _saveDateOverrides();
  }

  Future<void> _savePinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, _pinnedIds.toList());
  }

  Future<void> _saveDateOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      _dateOverrides.map((key, value) => MapEntry(key.toString(), value)),
    );
    await prefs.setString(_dateOverridesKey, json);
  }

  /// Apply pin sorting: pinned songs appear first, then the rest.
  /// Within each group, the original order is preserved.
  List<SongModel> applyPinnedSort(List<SongModel> songs) {
    final pinned = <SongModel>[];
    final unpinned = <SongModel>[];
    for (final song in songs) {
      if (_pinnedIds.contains(song.id.toString())) {
        pinned.add(song);
      } else {
        unpinned.add(song);
      }
    }
    return [...pinned, ...unpinned];
  }
}
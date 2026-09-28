import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistController extends ChangeNotifier {
  static const String _fileName = 'playlists.json';

  final List<Playlist> _playlists = [];
  bool _loaded = false;
  bool _saving = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isLoaded => _loaded;

  Future<Directory> _directory() async {
    return getApplicationSupportDirectory();
  }

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}/$_fileName');
  }

  String songKey(Song song) {
    final uri = song.uri?.trim();
    if (uri != null && uri.isNotEmpty) return 'uri:$uri';
    if (song.id != null) return 'id:${song.id}';
    return 'meta:${song.title}|${song.artist}|${song.album ?? ''}';
  }

  bool containsSong(Playlist playlist, Song song) {
    return playlist.songKeys.contains(songKey(song));
  }

  List<Song> songsForPlaylist(Playlist playlist, List<Song> allSongs) {
    final byKey = <String, Song>{
      for (final song in allSongs) songKey(song): song,
    };
    return playlist.songKeys
        .map((key) => byKey[key])
        .whereType<Song>()
        .toList();
  }

  Future<void> load() async {
    if (_loaded) return;

    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _playlists
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((item) => Playlist.fromJson(
                        Map<String, dynamic>.from(item),
                      )),
            );
        }
      }
    } catch (error) {
      debugPrint('Playlist load failed: $error');
    }

    _loaded = true;
    notifyListeners();
  }

  Playlist createPlaylist(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Playlist name cannot be empty');
    }

    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      songKeys: const [],
      createdAt: DateTime.now(),
    );

    _playlists.insert(0, playlist);
    notifyListeners();
    unawaitedFlush();
    return playlist;
  }

  void renamePlaylist(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index == -1) return;
    _playlists[index] = _playlists[index].copyWith(name: trimmed);
    notifyListeners();
    unawaitedFlush();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((playlist) => playlist.id == id);
    notifyListeners();
    unawaitedFlush();
  }

  void addSong(String playlistId, Song song) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index == -1) return;

    final key = songKey(song);
    final playlist = _playlists[index];
    if (playlist.songKeys.contains(key)) return;

    final keys = [...playlist.songKeys, key];
    _playlists[index] = playlist.copyWith(songKeys: keys);
    notifyListeners();
    unawaitedFlush();
  }

  void addSongs(String playlistId, Iterable<Song> songs) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    final keys = [...playlist.songKeys];
    for (final song in songs) {
      final key = songKey(song);
      if (!keys.contains(key)) keys.add(key);
    }

    _playlists[index] = playlist.copyWith(songKeys: keys);
    notifyListeners();
    unawaitedFlush();
  }

  void reorderSongs(String playlistId, int oldIndex, int newIndex) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    final keys = [...playlist.songKeys];
    if (oldIndex < 0 || oldIndex >= keys.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= keys.length) newIndex = keys.length - 1;
    if (oldIndex == newIndex) return;

    final moved = keys.removeAt(oldIndex);
    keys.insert(newIndex, moved);
    _playlists[index] = playlist.copyWith(songKeys: keys);
    notifyListeners();
    unawaitedFlush();
  }

  void removeSong(String playlistId, Song song) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index == -1) return;

    final key = songKey(song);
    final playlist = _playlists[index];
    final keys = playlist.songKeys.where((item) => item != key).toList();
    _playlists[index] = playlist.copyWith(songKeys: keys);
    notifyListeners();
    unawaitedFlush();
  }

  Future<void> flush() async {
    if (_saving) return;
    _saving = true;
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final json = jsonEncode(_playlists.map((playlist) => playlist.toJson()).toList());
      await file.writeAsString(json, flush: true);
    } catch (error) {
      debugPrint('Playlist save failed: $error');
    } finally {
      _saving = false;
    }
  }

  void unawaitedFlush() {
    flush();
  }
}

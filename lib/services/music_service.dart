import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/song.dart';

class MusicService {
  // ==========================================================
  // METHOD CHANNEL
  // ==========================================================

  static const MethodChannel _channel =
      MethodChannel('music_player/device_music');

  // ==========================================================
  // FUNCTION: REQUEST MUSIC PERMISSION
  // ==========================================================

  Future<bool> requestMusicPermission() async {
    final bool result =
        await _channel.invokeMethod<bool>(
              'requestMusicPermission',
            ) ??
            false;

    return result;
  }

  // ==========================================================
  // FUNCTION: GET DEVICE SONGS
  // ==========================================================

  Future<List<Song>> getDeviceSongs() async {
    final List<dynamic> result =
        await _channel.invokeMethod<List<dynamic>>(
              'getDeviceSongs',
            ) ??
            [];

    return result.map((item) {
      final Map<dynamic, dynamic> data =
          item as Map<dynamic, dynamic>;

      return Song(
        id: data['id'] is int
            ? data['id'] as int
            : int.tryParse(
                data['id']?.toString() ?? '',
              ),
        title:
            data['title']?.toString() ??
                'Unknown title',
        artist:
            data['artist']?.toString() ??
                'Unknown artist',
        album:
            data['album']?.toString(),
        duration:
            data['duration'] is int
                ? data['duration'] as int
                : int.tryParse(
                    data['duration']?.toString() ?? '',
                  ),
        uri:
            data['uri']?.toString(),
      );
    }).toList();
  }

  // ==========================================================
  // FUNCTION: PLAY SONG
  // ==========================================================

  Future<bool> playSong(Song song) async {
    if (song.uri == null || song.uri!.isEmpty) {
      return false;
    }

    final bool result =
        await _channel.invokeMethod<bool>(
              'playSong',
              {
                'uri': song.uri,
              },
            ) ??
            false;

    return result;
  }

  // ==========================================================
  // FUNCTION: PAUSE SONG
  // ==========================================================

  Future<void> pauseSong() async {
    await _channel.invokeMethod(
      'pauseSong',
    );
  }

  // ==========================================================
  // FUNCTION: RESUME SONG
  // ==========================================================

  Future<void> resumeSong() async {
    await _channel.invokeMethod(
      'resumeSong',
    );
  }

  // ==========================================================
  // FUNCTION: STOP SONG
  // ==========================================================

  Future<void> stopSong() async {
    await _channel.invokeMethod(
      'stopSong',
    );
  }

  // ==========================================================
  // FUNCTION: SEEK SONG
  // ==========================================================

  Future<void> seekTo(
    int positionMilliseconds,
  ) async {
    await _channel.invokeMethod(
      'seekTo',
      {
        'position': positionMilliseconds,
      },
    );
  }

  // ==========================================================
  // FUNCTION: GET PLAYBACK POSITION
  // ==========================================================

  Future<int> getPlaybackPosition() async {
    final int position =
        await _channel.invokeMethod<int>(
              'getPlaybackPosition',
            ) ??
            0;

    return position;
  }

  // ==========================================================
  // FUNCTION: GET SONG DURATION
  // ==========================================================

  Future<int> getSongDuration() async {
    final int duration =
        await _channel.invokeMethod<int>(
              'getSongDuration',
            ) ??
            0;

    return duration;
  }

  // ==========================================================
  // FUNCTION: CHECK PLAYING STATE
  // ==========================================================

  Future<bool> isPlaying() async {
    final bool playing =
        await _channel.invokeMethod<bool>(
              'isPlaying',
            ) ??
            false;

    return playing;
  }

  // ==========================================================
  // FUNCTION: CHECK ACTIVE PLAYER
  // ==========================================================

  Future<bool> hasActivePlayer() async {
    final bool active =
        await _channel.invokeMethod<bool>(
              'hasActivePlayer',
            ) ??
            false;

    return active;
  }

// ============================================================
// FUNCTION: GET SONG ARTWORK
// ============================================================

  // Two-level artwork cache:
  // 1. In-memory Future cache keeps the same artwork instance available
  //    while the app is running.
  // 2. Persistent on-device cache avoids extracting artwork again after
  //    Home <-> Library navigation or after restarting the app.
  static final Map<String, Future<Uint8List?>> _artworkCache = {};
  static final Map<String, Uint8List?> _artworkBytesCache = {};
  static Future<Directory>? _artworkDirectoryFuture;

  /// Returns artwork that has already been loaded during this app session.
  /// This is synchronous so rebuilt widgets can keep showing the existing
  /// image instead of briefly showing their placeholder.
  Uint8List? getCachedArtwork(Song song) {
    final String key = _songArtworkCacheKey(song);
    if (key.isEmpty) return null;
    return _artworkBytesCache[key];
  }

  Future<Uint8List?> getArtwork(Song song) {
    final String? uri = song.uri;

    if (uri == null || uri.isEmpty) {
      return Future<Uint8List?>.value(null);
    }

    final String cacheKey = _songArtworkCacheKey(song);
    final Future<Uint8List?>? cached = _artworkCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final Future<Uint8List?> future = _loadArtworkWithDiskCache(uri);
    _artworkCache[cacheKey] = future;
    future.then((bytes) {
      _artworkBytesCache[cacheKey] = bytes;
    });
    return future;
  }


  String _songArtworkCacheKey(Song song) {
    if (song.id != null && song.id! > 0) {
      return 'id:${song.id}';
    }
    final String? uri = song.uri;
    if (uri == null || uri.isEmpty) return '';
    return 'uri:$uri';
  }

  Future<Uint8List?> _loadArtworkWithDiskCache(String uri) async {
    try {
      final Directory directory = await _getArtworkDirectory();
      final String key = _stableArtworkKey(uri);
      final File artworkFile = File('${directory.path}/$key.bin');
      final File missingFile = File('${directory.path}/$key.none');

      // A successful lookup is persisted as raw image bytes. Image.memory
      // can decode the original PNG/JPEG bytes directly.
      if (await artworkFile.exists()) {
        final Uint8List bytes = await artworkFile.readAsBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        }
      }

      // Persist failed lookups as well, so files without artwork don't cause
      // Android MediaMetadataRetriever to be called again on every screen.
      if (await missingFile.exists()) {
        return null;
      }

      final Uint8List? artwork =
          await _channel.invokeMethod<Uint8List>(
        'getArtwork',
        {'uri': uri},
      );

      if (artwork == null || artwork.isEmpty) {
        await missingFile.writeAsString('missing');
        return null;
      }

      await artworkFile.writeAsBytes(artwork, flush: true);
      return artwork;
    } catch (e) {
      // A cache/storage failure must never prevent playback or the UI from
      // working. Fall back to the normal in-memory lookup.
      debugPrint('Persistent artwork cache unavailable: $e');
      return _loadArtworkFromAndroid(uri);
    }
  }

  Future<Uint8List?> _loadArtworkFromAndroid(String uri) async {
    try {
      final Uint8List? artwork =
          await _channel.invokeMethod<Uint8List>(
        'getArtwork',
        {'uri': uri},
      );

      if (artwork == null || artwork.isEmpty) {
        return null;
      }

      return artwork;
    } catch (e) {
      debugPrint('Artwork unavailable: $e');
      return null;
    }
  }

  Future<Directory> _getArtworkDirectory() async {
    _artworkDirectoryFuture ??= _createArtworkDirectory();
    return _artworkDirectoryFuture!;
  }

  Future<Directory> _createArtworkDirectory() async {
    // Application support storage survives normal app launches and is not
    // treated as disposable cache storage by Android.
    final Directory root = await getApplicationSupportDirectory();
    final Directory directory = Directory('${root.path}/artwork_cache');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  // Stable FNV-1a hash. Unlike Object.hashCode, this remains stable across
  // app launches, so the same song URI maps to the same disk-cache file.
  String _stableArtworkKey(String value) {
    int hash = 0x811c9dc5;

    for (final int byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ==========================================================
  // FUNCTION: GET SONGS
  // ==========================================================

  List<Song> getSongs() {
    return const [];
  }
}
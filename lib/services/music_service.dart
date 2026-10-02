import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:content_resolver/content_resolver.dart';

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
  // FUNCTION: RENAME SONG FILE
  // ==========================================================

  Future<bool> renameSong(Song song, String newName) async {
    final uri = song.uri;
    if (uri == null || uri.isEmpty || newName.trim().isEmpty) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'renameSong',
            {'uri': uri, 'newName': newName.trim()},
          ) ??
          false;
    } catch (e) {
      debugPrint('Rename song failed: $e');
      return false;
    }
  }

  // ==========================================================
  // FUNCTION: DELETE SONG FILE
  // ==========================================================

  Future<bool> deleteSong(Song song) async {
    final uri = song.uri;
    if (uri == null || uri.isEmpty) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'deleteSong',
            {'uri': uri},
          ) ??
          false;
    } catch (e) {
      debugPrint('Delete song failed: $e');
      return false;
    }
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
                'title': song.title,
                'artist': song.artist,
                'album': song.album ?? 'Unknown album',
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
  static final ImagePicker _imagePicker = ImagePicker();
  static final Map<String, Future<Uint8List?>> _artworkCache = {};
  static final Map<String, Uint8List?> _artworkBytesCache = {};
  static Future<Directory>? _artworkDirectoryFuture;

  /// Picks, crops and EMBEDS artwork into the actual audio file metadata.
  ///
  /// The old implementation stored artwork only inside the app's private
  /// cache. That meant renaming/re-indexing a song could make the artwork
  /// disappear and the artwork was not included when the audio file was
  /// shared. The new implementation writes the artwork into the audio tags.
  Future<Uint8List?> pickCustomArtwork(Song song) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return null;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 94,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Artwork',
            toolbarColor: const Color(0xFF171820),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF111214),
            activeControlsWidgetColor: const Color(0xFF9B8CFF),
            dimmedLayerColor: const Color(0x99000000),
            cropFrameColor: const Color(0xFF9B8CFF),
            cropGridColor: const Color(0x669B8CFF),
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
        ],
      );

      if (cropped == null) return null;

      final bytes = await File(cropped.path).readAsBytes();
      if (bytes.isEmpty) return null;

      final written = await _writeArtworkToAudioFile(song, bytes);
      if (!written) {
        debugPrint('Could not embed artwork into ${song.uri}');
        return null;
      }

      // The audio file is now the source of truth. Remove any old private
      // custom-artwork/cache entries so the UI cannot show stale artwork.
      await _clearArtworkDiskCache(song.uri);

      final key = _songArtworkCacheKey(song);
      _artworkCache.remove(key);
      _artworkBytesCache[key] = bytes;
      return bytes;
    } catch (e, stack) {
      debugPrint('Embedding artwork failed: $e');
      debugPrint('$stack');
      return null;
    }
  }

  /// Removes embedded artwork from the actual audio file metadata.
  Future<void> removeCustomArtwork(Song song) async {
    try {
      final written = await _writeArtworkToAudioFile(song, null);
      if (!written) {
        debugPrint('Could not remove embedded artwork from ${song.uri}');
        return;
      }

      await _clearArtworkDiskCache(song.uri);

      final cacheKey = _songArtworkCacheKey(song);
      _artworkCache.remove(cacheKey);
      _artworkBytesCache.remove(cacheKey);
    } catch (e) {
      debugPrint('Embedded artwork removal failed: $e');
    }
  }

  Future<bool> hasCustomArtwork(Song song) async {
    try {
      final artwork = await _readEmbeddedArtwork(song);
      return artwork != null && artwork.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _writeArtworkToAudioFile(
    Song song,
    Uint8List? artwork,
  ) async {
    final uri = song.uri;
    if (uri == null || uri.isEmpty) return false;

    // audio_metadata_reader performs a partial metadata update: it reads the
    // existing tag, changes only the fields modified in the callback, and
    // writes the result back. This preserves title, artist, album, genre,
    // year, track number, lyrics, and other metadata we do not touch.
    //
    // The Android app uses MediaStore content:// URIs, so we first copy the
    // actual audio bytes to a temporary file, update its embedded artwork,
    // then write the complete modified file back to the same URI.
    if (uri.startsWith('content://')) {
      final content = await ContentResolver.resolveContent(uri);
      final originalBytes = content.data;
      if (originalBytes.isEmpty) return false;

      final extension = _audioExtension(song, content.fileName);
      if (!_supportsMetadataWrite(extension)) {
        debugPrint(
          'Embedded artwork writing is not supported for .$extension files.',
        );
        return false;
      }

      // Android MediaStore items may belong to another app.
      // Android 11+ requires user authorization before modifying them.
      if (Platform.isAndroid) {
        final canWrite = await _channel.invokeMethod<bool>(
          'requestMediaWriteAccess',
          {'uri': uri},
        );

        if (canWrite != true) {
          debugPrint(
            'MediaStore write access was not granted for $uri',
          );
          return false;
        }
      }

      final directory = await getTemporaryDirectory();
      final tempFile = File(
        '${directory.path}/music_artwork_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );

      try {
        await tempFile.writeAsBytes(originalBytes, flush: true);
        await _updateEmbeddedArtwork(tempFile, artwork);
        final modifiedBytes = await tempFile.readAsBytes();
        await ContentResolver.writeContent(uri, modifiedBytes);
        return true;
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    final path = uri.startsWith('file://')
        ? Uri.parse(uri).toFilePath()
        : uri;
    final file = File(path);
    if (!await file.exists()) return false;

    final extension = _audioExtension(song, file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : null);
    if (!_supportsMetadataWrite(extension)) {
      debugPrint(
        'Embedded artwork writing is not supported for .$extension files.',
      );
      return false;
    }

    await _updateEmbeddedArtwork(file, artwork);
    return true;
  }

  Future<void> _updateEmbeddedArtwork(
    File file,
    Uint8List? artwork,
  ) async {
    updateMetadata(
      file,
      (metadata) {
        if (artwork == null || artwork.isEmpty) {
          metadata.setPictures(const <Picture>[]);
          return;
        }

        metadata.setPictures(<Picture>[
          Picture(
            artwork,
            'image/jpeg',
            PictureType.coverFront,
          ),
        ]);
      },
    );
  }

  bool _supportsMetadataWrite(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp3':
      case 'm4a':
      case 'mp4':
      case 'flac':
      case 'wav':
      case 'ape':
        return true;
      default:
        return false;
    }
  }

  Future<Uint8List?> _readEmbeddedArtwork(Song song) async {
    final uri = song.uri;
    if (uri == null || uri.isEmpty) return null;

    // Android's MediaMetadataRetriever already reads the embedded picture
    // from the real MediaStore file, so there is no second artwork database
    // to keep in sync.
    if (uri.startsWith('content://')) {
      return _loadArtworkFromAndroid(uri);
    }

    // For file:// / ordinary filesystem paths, use the same Android channel
    // when available. The normal Android library path is content://, so this
    // branch is only a compatibility fallback.
    return _loadArtworkFromAndroid(uri);
  }

  String _audioExtension(Song song, String? fileName) {
    final name = fileName ?? '';
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }

    final uri = song.uri ?? '';
    final uriPath = Uri.tryParse(uri)?.path ?? uri;
    final uriDot = uriPath.lastIndexOf('.');
    if (uriDot >= 0 && uriDot < uriPath.length - 1) {
      return uriPath.substring(uriDot + 1).toLowerCase();
    }

    return 'mp3';
  }


  Future<void> _clearArtworkDiskCache(String? uri) async {
    if (uri == null || uri.isEmpty) return;
    try {
      final directory = await _getArtworkDirectory();
      final key = _stableArtworkKey(uri);
      final artworkFile = File('${directory.path}/$key.bin');
      final missingFile = File('${directory.path}/$key.none');
      if (await artworkFile.exists()) await artworkFile.delete();
      if (await missingFile.exists()) await missingFile.delete();
    } catch (_) {}
  }

  /// Returns artwork that has already been loaded into the in-memory cache.
  ///
  /// This is kept as a synchronous compatibility API for widgets that use
  /// cached artwork as FutureBuilder.initialData. The source of truth is still
  /// the artwork embedded in the audio file; this method does not maintain a
  /// separate custom-artwork database.
  Uint8List? getCachedArtwork(Song song) {
    final String cacheKey = _songArtworkCacheKey(song);
    if (cacheKey.isEmpty) return null;
    return _artworkBytesCache[cacheKey];
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
    final String? uri = song.uri;
    if (uri == null || uri.isEmpty) {
      return song.id != null && song.id! > 0 ? 'id:${song.id}' : '';
    }
    // Include the URI even when a MediaStore ID exists. IDs can be reused
    // after media is removed/re-indexed; the URI is the actual file identity.
    return 'uri:$uri|id:${song.id ?? ''}';
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
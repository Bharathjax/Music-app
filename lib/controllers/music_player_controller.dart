import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import '../services/music_service.dart';


// ================================================================
// REPEAT MODE
// ================================================================

enum PlayerRepeatMode {
  off,
  all,
  one,
}


// ================================================================
// MUSIC PLAYER CONTROLLER
// ================================================================

class MusicPlayerController
    extends ChangeNotifier {

  final MusicService musicService =
      MusicService();


  // ==============================================================
  // CONSTRUCTOR
  // ==============================================================

  MusicPlayerController() {
    _listenForSongCompletion();
  }


  // ==============================================================
  // PLAYBACK TIMER
  // ==============================================================

  Timer? _positionTimer;
  bool _positionReadInFlight = false;


  // ==============================================================
  // NATIVE COMPLETION EVENT
  // ==============================================================

  StreamSubscription<dynamic>?
      _completionSubscription;


  static const EventChannel
      _completionChannel =
      EventChannel(
    'music_player/song_events',
  );


  // ==============================================================
  // SONG DATA
  // ==============================================================

  List<Song> songs = [];

  int currentSongIndex = 0;

  // Playback queue. Playlist playback replaces this with only the
  // playlist's song indexes; normal library playback uses all songs.
  List<int> _playbackQueue = [];

  // Name of the playlist that supplied the current playback queue.
  // Null means the song is playing from the general library/queue.
  String? _playbackSourceName;
  String? _playbackSourcePlaylistId;

  String? get playbackSourceName => _playbackSourceName;
  String? get playbackSourcePlaylistId => _playbackSourcePlaylistId;
  List<int> get playbackQueue => List<int>.unmodifiable(_playbackQueue);

  // ==============================================================
  // SHUFFLE DATA
  // ==============================================================

  List<int> _shuffleOrder = [];

  int _shufflePosition = 0;

  final Random _random =
      Random();


  // ==============================================================
  // PLAYER STATE
  // ==============================================================

  bool isPlaying = false;

  /// True after playback has actually been used or a saved playback
  /// context has been restored.
  bool get hasPlaybackContext =>
      _hasActivePlayer ||
      (_persistentStateLoaded && _persistedPlaybackSongKey != null);

  /// True once the persisted player state has finished loading.
  bool get playbackContextReady => _persistentStateLoaded;

  bool isShuffle = false;

  PlayerRepeatMode repeatMode =
      PlayerRepeatMode.off;


  // ==============================================================
  // CURRENT PROGRESS
  // ==============================================================

  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  // Rebuild UI that depends on player state, but not on 500ms progress ticks.
  final ValueNotifier<int> uiStateNotifier = ValueNotifier<int>(0);

  void _notifyUi() {
    uiStateNotifier.value++;
    notifyListeners();
  }

  double _progress = 0.0;

  double get progress => _progress;

  set progress(double value) {
    _progress = value;
    if (progressNotifier.value != value) {
      progressNotifier.value = value;
    }
  }


  // ==============================================================
  // CURRENT SONG DURATION
  // ==============================================================

  int songDuration = 0;


  // ==============================================================
  // PLAYER STATUS
  // ==============================================================

  bool _hasActivePlayer = false;

  bool _completionHandled = false;

  // Serializes competing async playback requests. A newer request invalidates
  // an older one before it can overwrite player state.
  int _playbackOperationId = 0;


  // ==============================================================
  // FAVORITES
  // ==============================================================

  final Set<int> favoriteSongs = {};

  // Most recently selected songs, newest first.
  final List<int> recentlyPlayedIndexes = [];

  bool _persistentStateLoaded = false;
  Future<void> _persistentSave = Future<void>.value();

  // Home Hero playback context. Playback position is intentionally not saved.
  String? _persistedPlaybackSongKey;
  String? _persistedPlaybackSourceName;
  String? _persistedPlaybackSourcePlaylistId;
  List<String> _persistedPlaybackQueueKeys = [];


  // ==============================================================
  // LOADING STATE
  // ==============================================================

  bool isLoadingSongs = false;

  bool permissionDenied = false;


  // ==============================================================
  // COMPATIBILITY GETTER
  // ==============================================================

  bool get isRepeat =>
      repeatMode != PlayerRepeatMode.off;


  // ==============================================================
  // CURRENT SONG
  // ==============================================================

  Song? get currentSong {

    if (songs.isEmpty) {
      return null;
    }


    if (currentSongIndex >=
        songs.length) {

      currentSongIndex = 0;
    }


    return songs[currentSongIndex];
  }


  // ==============================================================
  // UPCOMING SONG
  // ==============================================================

  Song? get upcomingSong {
    if (songs.isEmpty) return null;

    if (isShuffle &&
        _shuffleOrder.isNotEmpty &&
        _shufflePosition < _shuffleOrder.length - 1) {
      final index = _shuffleOrder[_shufflePosition + 1];
      if (index >= 0 && index < songs.length) return songs[index];
    }

    final queue = _playbackQueue.isEmpty
        ? List<int>.generate(songs.length, (index) => index)
        : _playbackQueue;
    final position = queue.indexOf(currentSongIndex);
    if (position >= 0 && position < queue.length - 1) {
      return songs[queue[position + 1]];
    }

    if (repeatMode == PlayerRepeatMode.all && queue.isNotEmpty) {
      return songs[queue.first];
    }

    return null;
  }


  // ==============================================================
  // LIVE UPCOMING QUEUE
  // ==============================================================

  List<int> get upcomingQueue {
    if (songs.isEmpty) return const <int>[];

    if (isShuffle && _shuffleOrder.isNotEmpty) {
      final currentPosition = _shuffleOrder.indexOf(currentSongIndex);
      if (currentPosition >= 0 && currentPosition < _shuffleOrder.length - 1) {
        return List<int>.from(_shuffleOrder.sublist(currentPosition + 1));
      }
      return const <int>[];
    }

    final queue = _playbackQueue.isEmpty
        ? List<int>.generate(songs.length, (index) => index)
        : _playbackQueue;
    final position = queue.indexOf(currentSongIndex);
    if (position < 0 || queue.length <= 1) {
      return const <int>[];
    }

    // Repeat All is a circular queue. Once we reach the end of the
    // current cycle, the songs before the current song become the
    // upcoming songs in the next cycle. This keeps the Next in Queue
    // drawer populated even when playback has wrapped around.
    if (repeatMode == PlayerRepeatMode.all) {
      final upcoming = <int>[
        ...queue.sublist(position + 1),
        ...queue.sublist(0, position),
      ];
      return upcoming;
    }

    if (position >= queue.length - 1) {
      return const <int>[];
    }

    return List<int>.from(queue.sublist(position + 1));
  }

  List<Song> get upcomingSongs => upcomingQueue
      .where((index) => index >= 0 && index < songs.length)
      .map((index) => songs[index])
      .toList(growable: false);

  /// Reorders only the songs that are still ahead of the current song.
  /// The current song and already-played portion of the queue are untouched.
  void reorderPlaybackQueue(int oldIndex, int newIndex) {
    final upcoming = upcomingQueue.toList();
    if (oldIndex < 0 || oldIndex >= upcoming.length) return;
    if (newIndex < 0 || newIndex >= upcoming.length) return;

    final moved = upcoming.removeAt(oldIndex);
    upcoming.insert(newIndex, moved);

    final queue = _playbackQueue.isEmpty
        ? List<int>.generate(songs.length, (index) => index)
        : List<int>.from(_playbackQueue);
    final currentPosition = queue.indexOf(currentSongIndex);
    if (currentPosition < 0) return;

    final List<int> rebuilt;

    if (!isShuffle && repeatMode == PlayerRepeatMode.all) {
      // In Repeat All the displayed queue is circular and may contain
      // songs from the beginning of the source after the current song.
      // After a reorder, make the current song the new cycle anchor and
      // keep the reordered upcoming songs as the next cycle.
      rebuilt = <int>[
        currentSongIndex,
        ...upcoming,
      ];
    } else {
      final prefix = queue.sublist(0, currentPosition + 1);
      rebuilt = <int>[...prefix, ...upcoming];
    }

    _playbackQueue = rebuilt;
    if (isShuffle) {
      _shuffleOrder = List<int>.from(rebuilt);
      _shufflePosition = _shuffleOrder.indexOf(currentSongIndex);
    }

    _savePersistentState();
    _notifyUi();
  }

  Future<void> playQueuedSong(int songIndex) async {
    if (!upcomingQueue.contains(songIndex)) return;
    await _selectSongInternal(songIndex, forceRestart: true);
  }


  // ==============================================================
  // PERSISTENT FAVORITES / RECENTLY PLAYED
  // ==============================================================

  Future<File> _playerStateFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/player_state.json');
  }

  String _songKey(Song song) {
    final uri = song.uri?.trim();
    if (uri != null && uri.isNotEmpty) return 'uri:$uri';
    if (song.id != null) return 'id:${song.id}';
    return 'meta:${song.title}|${song.artist}|${song.album ?? ''}';
  }

  Future<void> _loadPersistentState() async {
    if (_persistentStateLoaded) return;

    try {
      final file = await _playerStateFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final savedShuffle = decoded['shuffle'];
          if (savedShuffle is bool) {
            isShuffle = savedShuffle;
          }

          final savedRepeat = decoded['repeatMode'];
          if (savedRepeat is int &&
              savedRepeat >= 0 &&
              savedRepeat < PlayerRepeatMode.values.length) {
            repeatMode = PlayerRepeatMode.values[savedRepeat];
          }

          final favoriteKeys =
              (decoded['favorites'] as List<dynamic>? ?? const [])
                  .map((value) => value.toString())
                  .toSet();
          final recentKeys =
              (decoded['recentlyPlayed'] as List<dynamic>? ?? const [])
                  .map((value) => value.toString())
                  .toList();

          final savedPlaybackSongKey =
              decoded['lastPlaybackSong']?.toString();
          final savedPlaybackSourceName =
              decoded['lastPlaybackSourceName']?.toString();
          final savedPlaybackPlaylistId =
              decoded['lastPlaybackPlaylistId']?.toString();
          final savedQueueKeys =
              (decoded['lastPlaybackQueue'] as List<dynamic>? ?? const [])
                  .map((value) => value.toString())
                  .toList();

          final keyToIndex = <String, int>{};
          for (var i = 0; i < songs.length; i++) {
            keyToIndex[_songKey(songs[i])] = i;
          }

          favoriteSongs
            ..clear()
            ..addAll(
              favoriteKeys
                  .map((key) => keyToIndex[key])
                  .whereType<int>(),
            );

          recentlyPlayedIndexes
            ..clear()
            ..addAll(
              recentKeys
                  .map((key) => keyToIndex[key])
                  .whereType<int>()
                  .take(8),
            );

          final savedSongIndex = savedPlaybackSongKey == null
              ? null
              : keyToIndex[savedPlaybackSongKey];

          if (savedSongIndex != null) {
            _persistedPlaybackSongKey = savedPlaybackSongKey;
            _persistedPlaybackSourceName = savedPlaybackSourceName;
            _persistedPlaybackSourcePlaylistId = savedPlaybackPlaylistId;
            _persistedPlaybackQueueKeys = savedQueueKeys;

            currentSongIndex = savedSongIndex;
            _playbackSourceName = savedPlaybackSourceName;
            _playbackSourcePlaylistId = savedPlaybackPlaylistId;

            final restoredQueue = savedQueueKeys
                .map((key) => keyToIndex[key])
                .whereType<int>()
                .toList();

            _playbackQueue = restoredQueue.isNotEmpty
                ? restoredQueue
                : List<int>.generate(songs.length, (index) => index);
          } else {
            _persistedPlaybackSongKey = null;
            _persistedPlaybackSourceName = null;
            _persistedPlaybackSourcePlaylistId = null;
            _persistedPlaybackQueueKeys = [];
          }
        }
      }
    } catch (error) {
      debugPrint('Player state load failed: $error');
    } finally {
      _persistentStateLoaded = true;
    }
  }

  void _savePersistentState() {
    _persistentSave = _persistentSave.then((_) async {
      try {
        final file = await _playerStateFile();
        await file.parent.create(recursive: true);

        final favoriteKeys = favoriteSongs
            .where((index) => index >= 0 && index < songs.length)
            .map((index) => _songKey(songs[index]))
            .toList();

        final recentKeys = recentlyPlayedIndexes
            .where((index) => index >= 0 && index < songs.length)
            .map((index) => _songKey(songs[index]))
            .take(8)
            .toList();

        final playbackSong = currentSong;
        final playbackSongKey = playbackSong == null
            ? _persistedPlaybackSongKey
            : _songKey(playbackSong);

        final playbackSourceName =
            _playbackSourceName ?? _persistedPlaybackSourceName;
        final playbackPlaylistId =
            _playbackSourcePlaylistId ?? _persistedPlaybackSourcePlaylistId;

        final playbackQueueKeys = _playbackQueue
            .where((index) => index >= 0 && index < songs.length)
            .map((index) => _songKey(songs[index]))
            .toList();

        await file.writeAsString(
          jsonEncode({
            'favorites': favoriteKeys,
            'recentlyPlayed': recentKeys,
            'shuffle': isShuffle,
            'repeatMode': repeatMode.index,
            'lastPlaybackSong': playbackSongKey,
            'lastPlaybackSourceName': playbackSourceName,
            'lastPlaybackPlaylistId': playbackPlaylistId,
            'lastPlaybackQueue': playbackQueueKeys,
          }),
          flush: true,
        );
      } catch (error) {
        debugPrint('Player state save failed: $error');
      }
    });
  }

  Future<File> _songCacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/song_library_cache.json');
  }

  Map<String, dynamic> _songToJson(Song song) => {
        'title': song.title,
        'artist': song.artist,
        'id': song.id,
        'album': song.album,
        'duration': song.duration,
        'uri': song.uri,
      };

  Song? _songFromJson(dynamic value) {
    if (value is! Map) return null;
    return Song(
      title: value['title']?.toString() ?? 'Unknown title',
      artist: value['artist']?.toString() ?? 'Unknown artist',
      id: value['id'] is int
          ? value['id'] as int
          : int.tryParse(value['id']?.toString() ?? ''),
      album: value['album']?.toString(),
      duration: value['duration'] is int
          ? value['duration'] as int
          : int.tryParse(value['duration']?.toString() ?? ''),
      uri: value['uri']?.toString(),
    );
  }

  Future<void> _loadCachedSongs() async {
    try {
      final file = await _songCacheFile();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      final cached = decoded.map(_songFromJson).whereType<Song>().toList();
      if (cached.isEmpty) return;
      songs = cached;
      currentSongIndex = 0;
      _shuffleOrder.clear();
      _shufflePosition = 0;
      await _loadPersistentState();
      if (isShuffle && songs.isNotEmpty) {
        _createShuffleOrder(keepCurrentFirst: true);
      }
      _notifyUi();
    } catch (error) {
      debugPrint('Song cache load failed: $error');
    }
  }

  Future<void> _saveCachedSongs(List<Song> value) async {
    try {
      final file = await _songCacheFile();
      await file.writeAsString(
        jsonEncode(value.map(_songToJson).toList()),
        flush: true,
      );
    } catch (error) {
      debugPrint('Song cache save failed: $error');
    }
  }

  Future<void> loadDeviceSongs() async {
    // Show the previous library immediately. The MediaStore refresh below
    // replaces it only when the current device library is available.
    await _loadCachedSongs();

    isLoadingSongs = false;
    permissionDenied = false;
    _notifyUi();

    try {
      final bool permission = await musicService.requestMusicPermission();

      if (!permission) {
        permissionDenied = songs.isEmpty;
        _notifyUi();
        return;
      }

      final List<Song> deviceSongs = await musicService.getDeviceSongs();
      final currentKey = currentSong == null ? null : _songKey(currentSong!);
      final oldQueueKeys = _playbackQueue
          .where((index) => index >= 0 && index < songs.length)
          .map((index) => _songKey(songs[index]))
          .toList();
      final wasPlaying = isPlaying;

      songs = deviceSongs;
      await _saveCachedSongs(deviceSongs);
      _persistentStateLoaded = false;
      await _loadPersistentState();

      final keyToNewIndex = <String, int>{
        for (var i = 0; i < songs.length; i++) _songKey(songs[i]): i,
      };
      final remappedQueue = oldQueueKeys
          .map((key) => keyToNewIndex[key])
          .whereType<int>()
          .toList();

      if (songs.isEmpty) {
        currentSongIndex = 0;
        _playbackQueue = [];
      } else {
        final preservedIndex = currentKey == null ? null : keyToNewIndex[currentKey];
        currentSongIndex = preservedIndex ?? currentSongIndex.clamp(0, songs.length - 1).toInt();
        _playbackQueue = remappedQueue.isNotEmpty
            ? remappedQueue
            : List<int>.generate(songs.length, (index) => index);
      }
      _shuffleOrder.clear();
      _shufflePosition = 0;
      if (isShuffle && songs.isNotEmpty) {
        _createShuffleOrder(keepCurrentFirst: true);
      }

      if (songs.isEmpty || (wasPlaying && currentKey != null && !keyToNewIndex.containsKey(currentKey))) {
        _playbackOperationId++;
        try { await musicService.stopSong(); } catch (_) {}
        isPlaying = false;
        songDuration = 0;
        progress = 0.0;
        _hasActivePlayer = false;
        _positionTimer?.cancel();
      }
    } catch (e) {
      debugPrint('Error loading device songs: $e');
    }

    isLoadingSongs = false;
    _notifyUi();
  }

  // ==============================================================
  // START POSITION TRACKING
  // ==============================================================

  void startPositionTracking() {
    _positionTimer?.cancel();

    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        if ((!isPlaying && !_hasActivePlayer) ||
            _positionReadInFlight) {
          return;
        }

        _positionReadInFlight = true;

        try {
          // Always verify the real native playback state.
          //
          // This is important for external events such as:
          // - headphones being unplugged
          // - Bluetooth device disconnecting
          // - notification/media-session pause
          // - Android stopping the native player
          final bool nativeIsPlaying =
              await musicService.isPlaying();

          if (!nativeIsPlaying) {
            isPlaying = false;
            _positionTimer?.cancel();
            _notifyUi();
            return;
          }

          final int position =
              await musicService.getPlaybackPosition();

          final int duration =
              await musicService.getSongDuration();

          if (duration <= 0) {
            return;
          }

          songDuration = duration;

          progress = (position / duration).clamp(0.0, 1.0);

          // Progress is delivered through progressNotifier only.
          // Do not rebuild Home/Library on every 500ms tick.
        } catch (e) {
          debugPrint(
            'Error tracking playback position: $e',
          );
        } finally {
          _positionReadInFlight = false;
        }
      },
    );
  }


  // ==============================================================
  // LISTEN FOR NATIVE SONG COMPLETION
  // ==============================================================

  void _listenForSongCompletion() {

    _completionSubscription =
        _completionChannel
            .receiveBroadcastStream()
            .listen(
      (event) {

        if (event ==
            'songCompleted') {

          _handleNativeSongCompletion();

        } else if (event ==
            'nextSong') {

          nextSong();

        } else if (event ==
            'previousSong') {

          previousSong();

        } else if (event ==
            'paused') {

          // Native playback was paused outside Flutter,
          // for example when headphones are disconnected.
          if (isPlaying) {
            isPlaying = false;
            _notifyUi();
          }

          // Keep polling so Flutter can detect native playback
          // resuming when headphones are connected again.
          if (_hasActivePlayer) {
            startPositionTracking();
          }

        } else if (event ==
            'resumed') {

          // Native playback resumed outside Flutter, for example
          // when headphones are connected again.
          if (!isPlaying) {
            isPlaying = true;
            _notifyUi();
          }

          startPositionTracking();
        }
      },

      onError: (error) {

        debugPrint(
          'Song completion listener error: $error',
        );
      },
    );
  }


  // ==============================================================
  // HANDLE NATIVE COMPLETION EVENT
  // ==============================================================

  void _handleNativeSongCompletion() {

    /*
     * Prevent duplicate completion handling.
     */
    if (_completionHandled) {
      return;
    }


    /*
     * If Flutter already considers playback paused/stopped,
     * ignore the event.
     */
    if (!isPlaying) {
      return;
    }


    _completionHandled = true;


    /*
     * Do not await here.
     *
     * The native event callback is synchronous.
     * _handleSongCompletion() performs the async transition.
     */
    _handleSongCompletion();
  }


  // ==============================================================
  // HANDLE SONG COMPLETION
  // ==============================================================

  Future<void>
      _handleSongCompletion() async {
    final operationId = ++_playbackOperationId;

    if (songs.isEmpty) {
      return;
    }


    // ------------------------------------------------------------
    // REPEAT ONE
    // ------------------------------------------------------------

    if (repeatMode ==
        PlayerRepeatMode.one) {

      final Song? song =
          currentSong;


      if (song == null) {
        return;
      }


      try {

        progress = 0.0;


        final bool started =
            await musicService
                .playSong(song);

        if (operationId != _playbackOperationId) return;

        if (!started) {

          isPlaying = false;

          _hasActivePlayer = false;

          _positionTimer?.cancel();

          _notifyUi();

          return;
        }


        _hasActivePlayer = true;

        isPlaying = true;


        final duration = await musicService.getSongDuration();
        if (operationId != _playbackOperationId) return;
        songDuration = duration;


        /*
         * Allow the next native completion event.
         */
        _completionHandled = false;


        startPositionTracking();


        _notifyUi();

      } catch (e) {

        isPlaying = false;

        _hasActivePlayer = false;

        _positionTimer?.cancel();


        debugPrint(
          'Error repeating song: $e',
        );


        _notifyUi();
      }


      return;
    }


    // ------------------------------------------------------------
    // NORMAL / REPEAT ALL / SHUFFLE
    // ------------------------------------------------------------

    await nextSong(
      automatic: true,
    );
  }


  // ==============================================================
  // HOME HERO: CONTINUE LAST PLAYBACK
  // ==============================================================

  /// Restores the saved song/source/queue and starts the song from 0.
  /// Playback position is intentionally never restored.
  Future<void> continuePlaybackFromHero() async {
    if (isPlaying) {
      await togglePlay();
      return;
    }

    if (!_persistentStateLoaded) {
      await _loadPersistentState();
    }

    if (songs.isEmpty) return;

    final keyToIndex = <String, int>{
      for (var i = 0; i < songs.length; i++) _songKey(songs[i]): i,
    };

    final savedSongKey = _persistedPlaybackSongKey;
    if (savedSongKey == null) {
      await togglePlay();
      return;
    }

    final targetIndex = keyToIndex[savedSongKey];
    if (targetIndex == null) return;

    final restoredQueue = _persistedPlaybackQueueKeys
        .map((key) => keyToIndex[key])
        .whereType<int>()
        .toList();

    _playbackQueue = restoredQueue.isNotEmpty
        ? restoredQueue
        : <int>[targetIndex];

    if (!_playbackQueue.contains(targetIndex)) {
      _playbackQueue.insert(0, targetIndex);
    }

    _playbackSourceName = _persistedPlaybackSourceName;
    _playbackSourcePlaylistId = _persistedPlaybackSourcePlaylistId;

    await _selectSongInternal(targetIndex, forceRestart: true);
  }

  // ==============================================================
  // TOGGLE PLAY
  // ==============================================================

  Future<void> togglePlay() async {
    final operationId = ++_playbackOperationId;

    final Song? song =
        currentSong;


    if (song == null) {
      return;
    }


    try {

      // ----------------------------------------------------------
      // PAUSE
      // ----------------------------------------------------------

      if (isPlaying) {

        await musicService
            .pauseSong();

        if (operationId != _playbackOperationId) return;


        isPlaying = false;


        _positionTimer?.cancel();


        _notifyUi();

        return;
      }


      // ----------------------------------------------------------
      // RESUME
      // ----------------------------------------------------------

      if (_hasActivePlayer) {

        await musicService
            .resumeSong();

        if (operationId != _playbackOperationId) return;


        isPlaying = true;


        _completionHandled = false;


        startPositionTracking();


        _notifyUi();

        return;
      }


      // ----------------------------------------------------------
      // START NEW SONG
      // ----------------------------------------------------------

      if (song.uri == null ||
          song.uri!.isEmpty) {

        return;
      }


      final bool started =
          await musicService
              .playSong(song);

      if (operationId != _playbackOperationId) return;

      if (!started) {
        isPlaying = false;
        _hasActivePlayer = false;
        _positionTimer?.cancel();
        _notifyUi();
        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;

      progress = 0.0;


      final duration = await musicService.getSongDuration();
      if (operationId != _playbackOperationId) return;
      songDuration = duration;


      _completionHandled = false;


      startPositionTracking();


      _notifyUi();

    } catch (e) {

      debugPrint(
        'Error toggling playback: $e',
      );
    }
  }


  // ==============================================================
  // SELECT SONG
  // ==============================================================

  Future<void> selectSong(int index) async {
    _playbackSourceName = null;
    _playbackSourcePlaylistId = null;
    _playbackQueue =
        List<int>.generate(songs.length, (index) => index);
    await _selectSongInternal(index, forceRestart: false);
  }

  // ==============================================================
  // HOME: PLAY ALL
  // ==============================================================

  Future<void> playAllSongs() async {
    if (songs.isEmpty) return;

    if (isPlaying && _playbackSourceName == 'All Songs') {
      await togglePlay();
      return;
    }

    await playSongQueue(
      List<int>.generate(songs.length, (index) => index),
      startPosition: 0,
      sourceName: 'All Songs',
    );
  }

  // ==============================================================
  // RENAME SONG FILE
  // ==============================================================

  Future<bool> renameSong(int index, String newName) async {
    if (index < 0 || index >= songs.length) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    final oldSong = songs[index];
    final ok = await musicService.renameSong(oldSong, trimmed);
    if (!ok) return false;

    final renamed = Song(
      title: _displayTitleWithoutExtension(trimmed, oldSong.title),
      artist: oldSong.artist,
      id: oldSong.id,
      album: oldSong.album,
      duration: oldSong.duration,
      uri: oldSong.uri,
    );
    songs[index] = renamed;
    await _saveCachedSongs(songs);
    _notifyUi();
    return true;
  }

  String _displayTitleWithoutExtension(String name, String fallback) {
    final value = name.trim();
    final dot = value.lastIndexOf('.');
    if (dot > 0 && dot < value.length - 1) return value.substring(0, dot);
    return value.isEmpty ? fallback : value;
  }

  // ==============================================================
  // DELETE SONG FILE
  // ==============================================================

  Future<bool> deleteSong(int index) async {
    if (index < 0 || index >= songs.length) return false;

    final song = songs[index];
    final wasCurrent = currentSongIndex == index;

    final ok = await musicService.deleteSong(song);
    if (!ok) return false;

    if (wasCurrent) {
      _playbackOperationId++;
      try {
        await musicService.stopSong();
      } catch (_) {}
      isPlaying = false;
      _hasActivePlayer = false;
      progress = 0.0;
      songDuration = 0;
      _positionTimer?.cancel();
    }

    songs.removeAt(index);

    favoriteSongs
      ..removeWhere((item) => item == index)
      ..removeWhere((item) => item < 0 || item >= songs.length);

    final updatedFavorites = favoriteSongs.map((item) {
      return item > index ? item - 1 : item;
    }).toSet();
    favoriteSongs
      ..clear()
      ..addAll(updatedFavorites);

    recentlyPlayedIndexes
      ..removeWhere((item) => item == index)
      ..replaceRange(0, recentlyPlayedIndexes.length, recentlyPlayedIndexes.map((item) => item > index ? item - 1 : item));

    _playbackQueue = _playbackQueue
        .where((item) => item != index)
        .map((item) => item > index ? item - 1 : item)
        .where((item) => item >= 0 && item < songs.length)
        .toList();

    _shuffleOrder = _shuffleOrder
        .where((item) => item != index)
        .map((item) => item > index ? item - 1 : item)
        .where((item) => item >= 0 && item < songs.length)
        .toList();

    if (songs.isEmpty) {
      currentSongIndex = 0;
      _playbackQueue = [];
      _shuffleOrder = [];
      _shufflePosition = 0;
    } else if (wasCurrent) {
      currentSongIndex = index.clamp(0, songs.length - 1).toInt();
    } else if (currentSongIndex > index) {
      currentSongIndex--;
    } else {
      currentSongIndex = currentSongIndex.clamp(0, songs.length - 1).toInt();
    }

    await _saveCachedSongs(songs);
    _savePersistentState();
    _notifyUi();
    return true;
  }

  // Add one song to the end of the current playback queue without
  // interrupting the song that is currently playing. This is a temporary
  // playback-queue operation; it does not modify Favorites or saved playlists.
  void addToQueue(int songIndex) {
    if (songIndex < 0 || songIndex >= songs.length) return;

    // If there is no explicit queue, establish the normal library queue first.
    // This keeps Add to Queue consistent whether playback was started from
    // a playlist/favorites or directly from the library.
    if (_playbackQueue.isEmpty) {
      _playbackQueue = List<int>.generate(songs.length, (index) => index);
    }

    // Do not de-duplicate here. A playback queue can intentionally contain
    // the same song more than once.
    _playbackQueue.add(songIndex);

    if (isShuffle) {
      // Preserve the current shuffle cycle and place the manually queued song
      // after the songs already present in that cycle.
      if (_shuffleOrder.length == _playbackQueue.length - 1) {
        _shuffleOrder.add(songIndex);
      } else {
        _createShuffleOrder(keepCurrentFirst: true);
      }
    }

    _notifyUi();
  }

  // Start a song using a specific queue. This is used by playlists so
  // Next/Previous/automatic completion stay inside the playlist.
  /// Updates the current playback queue without restarting the current song.
  /// Used when a playlist is reordered while it is playing.
  void updatePlaybackQueue(List<int> queue, {String? sourceName}) {
    if (sourceName != null && sourceName != _playbackSourceName) return;

    final cleaned = queue
        .where((index) => index >= 0 && index < songs.length)
        .toList();
    if (cleaned.isEmpty) return;

    _playbackQueue = List<int>.from(cleaned);
    if (isShuffle) {
      _createShuffleOrder(keepCurrentFirst: true);
    }
    _notifyUi();
  }

  Future<void> playSongQueue(
    List<int> indexes, {
    int startPosition = 0,
    String? sourceName,
    String? sourcePlaylistId,
  }) async {
    final queue = indexes
        .where((index) => index >= 0 && index < songs.length)
        .toList();
    if (queue.isEmpty) return;

    _playbackQueue = List<int>.from(queue);
    _playbackSourceName = sourceName;
    _playbackSourcePlaylistId = sourcePlaylistId;
    final int safePosition =
        startPosition.clamp(0, queue.length - 1).toInt();
    await _selectSongInternal(queue[safePosition], forceRestart: true);
  }

  Future<void> _selectSongInternal(int index, {required bool forceRestart}) async {
    final operationId = ++_playbackOperationId;

    if (index < 0 ||
        index >= songs.length) {

      return;
    }


    // ------------------------------------------------------------
    // SAME SONG
    // ------------------------------------------------------------

    if (index == currentSongIndex && _hasActivePlayer && !forceRestart) {
      await togglePlay();
      return;
    }


    // ------------------------------------------------------------
    // NEW SONG
    // ------------------------------------------------------------

    final Song song =
        songs[index];

    currentSongIndex =
        index;

    _persistedPlaybackSongKey = _songKey(song);
    _persistedPlaybackSourceName = _playbackSourceName;
    _persistedPlaybackSourcePlaylistId = _playbackSourcePlaylistId;
    _persistedPlaybackQueueKeys = _playbackQueue
        .where((item) => item >= 0 && item < songs.length)
        .map((item) => _songKey(songs[item]))
        .toList();

    recentlyPlayedIndexes.remove(index);
    recentlyPlayedIndexes.insert(0, index);
    if (recentlyPlayedIndexes.length > 8) {
      recentlyPlayedIndexes.removeLast();
    }

    _savePersistentState();

    progress = 0.0;

    songDuration =
        song.duration ?? 0;


    _completionHandled =
        false;


    _notifyUi();


    // ------------------------------------------------------------
    // UPDATE SHUFFLE
    // ------------------------------------------------------------

    if (isShuffle) {

      _createShuffleOrder(
        keepCurrentFirst: true,
      );
    }


    // ------------------------------------------------------------
    // CHECK URI
    // ------------------------------------------------------------

    if (song.uri == null ||
        song.uri!.isEmpty) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();

      _notifyUi();

      return;
    }


    // ------------------------------------------------------------
    // PLAY SONG
    // ------------------------------------------------------------

    try {

      final bool started =
          await musicService
              .playSong(song);

      if (operationId != _playbackOperationId) return;

      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      final duration = await musicService.getSongDuration();
      if (operationId != _playbackOperationId) return;
      songDuration = duration;

      startPositionTracking();

    } catch (e) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();


      debugPrint(
        'Error playing selected song: $e',
      );
    }


    _notifyUi();
  }


  // ==============================================================
  // CREATE SHUFFLE ORDER
  // ==============================================================

  void _createShuffleOrder({
    bool keepCurrentFirst = true,
  }) {

    if (songs.isEmpty) {

      _shuffleOrder.clear();

      _shufflePosition = 0;

      return;
    }


    final List<int> indexes =
        (_playbackQueue.isEmpty
                ? List<int>.generate(
                    songs.length,
                    (index) => index,
                  )
                : List<int>.from(_playbackQueue));


    indexes.remove(
      currentSongIndex,
    );


    indexes.shuffle(
      _random,
    );


    if (keepCurrentFirst) {

      _shuffleOrder = [
        currentSongIndex,
        ...indexes,
      ];

      _shufflePosition = 0;

    } else {

      _shuffleOrder =
          indexes;

      _shufflePosition = 0;
    }
  }


  // ==============================================================
  // TOGGLE SHUFFLE
  // ==============================================================

  void toggleShuffle() {

    isShuffle =
        !isShuffle;


    if (isShuffle) {

      _createShuffleOrder(
        keepCurrentFirst: true,
      );

    } else {

      _shuffleOrder.clear();

      _shufflePosition = 0;
    }


    _savePersistentState();
    _notifyUi();
  }


  // ==============================================================
  // NEXT SONG
  // ==============================================================

  Future<void> nextSong({
    bool automatic = false,
  }) async {
    final operationId = ++_playbackOperationId;

    if (songs.isEmpty) {
      return;
    }


    // ------------------------------------------------------------
    // SHUFFLE MODE
    // ------------------------------------------------------------

    if (isShuffle) {

      final queueLength = _playbackQueue.isEmpty
          ? songs.length
          : _playbackQueue.length;

      if (_shuffleOrder.length != queueLength) {

        _createShuffleOrder(
          keepCurrentFirst: true,
        );
      }


      // ----------------------------------------------------------
      // ONLY ONE SONG
      // ----------------------------------------------------------

      if (_shuffleOrder.length == 1) {

        currentSongIndex =
            _shuffleOrder.first;
      }


      // ----------------------------------------------------------
      // NEXT IN CURRENT CYCLE
      // ----------------------------------------------------------

      else if (_shufflePosition <
          _shuffleOrder.length - 1) {

        _shufflePosition++;


        currentSongIndex =
            _shuffleOrder[
                _shufflePosition];
      }


      // ----------------------------------------------------------
      // END OF SHUFFLE CYCLE
      // ----------------------------------------------------------

      else {

        /*
         * Automatic playback + Repeat OFF:
         * stop at the end.
         */
        if (automatic &&
            repeatMode ==
                PlayerRepeatMode.off) {

          await _stopAtEnd();

          return;
        }


        /*
         * Repeat ALL:
         * create another shuffle cycle.
         */
        _createShuffleOrder(
          keepCurrentFirst: true,
        );


        if (_shuffleOrder.length > 1) {

          _shufflePosition = 1;


          currentSongIndex =
              _shuffleOrder[1];

        } else {

          currentSongIndex =
              _shuffleOrder.first;
        }
      }
    }


    // ------------------------------------------------------------
    // NORMAL MODE
    // ------------------------------------------------------------

    else {

      final queue = _playbackQueue.isEmpty
          ? List<int>.generate(songs.length, (index) => index)
          : _playbackQueue;
      final position = queue.indexOf(currentSongIndex);

      if (position >= 0 && position < queue.length - 1) {
        currentSongIndex = queue[position + 1];
      } else {
        if (automatic && repeatMode == PlayerRepeatMode.off) {
          await _stopAtEnd();
          return;
        }
        currentSongIndex = queue.first;
      }
    }


    progress = 0.0;

    songDuration = 0;

    _completionHandled = false;


    final Song? song =
        currentSong;


    if (song == null ||
        song.uri == null ||
        song.uri!.isEmpty) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();

      _notifyUi();

      return;
    }


    try {

      final bool started =
          await musicService
              .playSong(song);

      if (operationId != _playbackOperationId) return;

      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      final duration = await musicService.getSongDuration();
      if (operationId != _playbackOperationId) return;
      songDuration = duration;

      startPositionTracking();

    } catch (e) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();


      debugPrint(
        'Error playing next song: $e',
      );
    }


    _notifyUi();
  }


  // ==============================================================
  // STOP AT END
  // ==============================================================

  Future<void>
      _stopAtEnd() async {
    ++_playbackOperationId;

    try {

      await musicService
          .stopSong();

    } catch (e) {

      debugPrint(
        'Error stopping at end: $e',
      );
    }


    isPlaying = false;

    _hasActivePlayer = false;

    progress = 1.0;

    _positionTimer?.cancel();


    _notifyUi();
  }


  // ==============================================================
  // PREVIOUS SONG
  // ==============================================================

  Future<void> previousSong() async {
    final operationId = ++_playbackOperationId;

    if (songs.isEmpty) {
      return;
    }


    // ------------------------------------------------------------
    // SHUFFLE MODE
    // ------------------------------------------------------------

    final queueLength = _playbackQueue.isEmpty
        ? songs.length
        : _playbackQueue.length;

    if (isShuffle &&
        _shuffleOrder.length == queueLength) {

      if (_shuffleOrder.length == 1) {

        currentSongIndex =
            _shuffleOrder.first;

      } else if (_shufflePosition > 0) {

        _shufflePosition--;


        currentSongIndex =
            _shuffleOrder[
                _shufflePosition];

      } else {

        _shufflePosition =
            _shuffleOrder.length - 1;


        currentSongIndex =
            _shuffleOrder[
                _shufflePosition];
      }
    }


    // ------------------------------------------------------------
    // NORMAL MODE
    // ------------------------------------------------------------

    else {

      final queue = _playbackQueue.isEmpty
          ? List<int>.generate(songs.length, (index) => index)
          : _playbackQueue;
      final position = queue.indexOf(currentSongIndex);

      if (position > 0) {
        currentSongIndex = queue[position - 1];
      } else {
        currentSongIndex = queue.last;
      }
    }


    progress = 0.0;

    songDuration = 0;

    _completionHandled = false;


    final Song? song =
        currentSong;


    if (song == null ||
        song.uri == null ||
        song.uri!.isEmpty) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();

      _notifyUi();

      return;
    }


    try {

      final bool started =
          await musicService
              .playSong(song);

      if (operationId != _playbackOperationId) return;


      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      final duration = await musicService.getSongDuration();
      if (operationId != _playbackOperationId) return;
      songDuration = duration;

      startPositionTracking();

    } catch (e) {

      isPlaying = false;

      _hasActivePlayer = false;

      _positionTimer?.cancel();


      debugPrint(
        'Error playing previous song: $e',
      );
    }


    _notifyUi();
  }


  // ==============================================================
  // TOGGLE REPEAT
  // ==============================================================

  void toggleRepeat() {

    switch (repeatMode) {

      case PlayerRepeatMode.off:

        repeatMode =
            PlayerRepeatMode.all;

        break;


      case PlayerRepeatMode.all:

        repeatMode =
            PlayerRepeatMode.one;

        break;


      case PlayerRepeatMode.one:

        repeatMode =
            PlayerRepeatMode.off;

        break;
    }


    _savePersistentState();
    _notifyUi();
  }


  // ==============================================================
  // TOGGLE FAVORITE
  // ==============================================================

  void toggleFavorite(
    int index,
  ) {

    if (favoriteSongs.contains(
        index)) {

      favoriteSongs.remove(
        index,
      );

    } else {

      favoriteSongs.add(
        index,
      );
    }

    _savePersistentState();
    _notifyUi();
  }


  // ==============================================================
  // REORDER FAVORITES
  // ==============================================================

  void reorderFavorites(int oldIndex, int newIndex) {
    final ordered = favoriteSongs.toList();
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex < 0 || newIndex > ordered.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ordered.removeAt(oldIndex);
    final target = newIndex.clamp(0, ordered.length).toInt();
    ordered.insert(target, moved);

    favoriteSongs
      ..clear()
      ..addAll(ordered);

    _savePersistentState();
    _notifyUi();
  }

  // ==============================================================
  // CHANGE PROGRESS
  // ==============================================================

  void changeProgress(
    double value,
  ) {

    progress =
        value.clamp(
      0.0,
      1.0,
    );


    if (songDuration > 0) {

      final int position =
          (songDuration * progress)
              .round();


      musicService.seekTo(
        position,
      );
    }


    _notifyUi();
  }


  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    ++_playbackOperationId;

    _positionTimer?.cancel();

    _completionSubscription?.cancel();


    musicService.stopSong();


    progressNotifier.dispose();
    uiStateNotifier.dispose();

    super.dispose();
  }
}

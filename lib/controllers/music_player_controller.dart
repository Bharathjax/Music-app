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


  // ==============================================================
  // FAVORITES
  // ==============================================================

  final Set<int> favoriteSongs = {};

  // Most recently selected songs, newest first.
  final List<int> recentlyPlayedIndexes = [];

  bool _persistentStateLoaded = false;
  Future<void> _persistentSave = Future<void>.value();


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

          final favoriteKeys = (decoded['favorites'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toSet();
          final recentKeys = (decoded['recentlyPlayed'] as List<dynamic>? ?? const [])
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
        await file.writeAsString(
          jsonEncode({
            'favorites': favoriteKeys,
            'recentlyPlayed': recentKeys,
            'shuffle': isShuffle,
            'repeatMode': repeatMode.index,
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
      songs = deviceSongs;
      await _saveCachedSongs(deviceSongs);
      _persistentStateLoaded = false;
      await _loadPersistentState();

      if (songs.isEmpty) {
        currentSongIndex = 0;
      } else {
        currentSongIndex = currentSongIndex.clamp(0, songs.length - 1).toInt();
      }
      _shuffleOrder.clear();
      _shufflePosition = 0;
      if (isShuffle && songs.isNotEmpty) {
        _createShuffleOrder(keepCurrentFirst: true);
      }

      if (songs.isEmpty) {
        isPlaying = false;
        songDuration = 0;
        progress = 0.0;
        _hasActivePlayer = false;
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


    _positionTimer =
        Timer.periodic(
      const Duration(
        milliseconds: 500,
      ),
      (_) async {

        if (!isPlaying) {
          return;
        }


        try {

          final int position =
              await musicService
                  .getPlaybackPosition();


          final int duration =
              await musicService
                  .getSongDuration();


          if (duration <= 0) {
            return;
          }


          songDuration =
              duration;


          progress =
              (position / duration)
                  .clamp(
            0.0,
            1.0,
          );


          /*
           * IMPORTANT:
           *
           * We intentionally do NOT detect song completion
           * here anymore.
           *
           * Android MediaPlayer sends the exact completion
           * event through EventChannel.
           */
          // Progress is delivered through progressNotifier only.
          // Do not rebuild Home/Library on every 500ms tick.

        } catch (e) {

          debugPrint(
            'Error tracking playback position: $e',
          );
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


        if (!started) {

          isPlaying = false;

          _hasActivePlayer = false;

          _positionTimer?.cancel();

          _notifyUi();

          return;
        }


        _hasActivePlayer = true;

        isPlaying = true;


        songDuration =
            await musicService
                .getSongDuration();


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
  // TOGGLE PLAY
  // ==============================================================

  Future<void> togglePlay() async {

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


      if (!started) {
        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;

      progress = 0.0;


      songDuration =
          await musicService
              .getSongDuration();


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
    await _selectSongInternal(index);
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
    await _selectSongInternal(queue[safePosition]);
  }

  Future<void> _selectSongInternal(int index) async {

    if (index < 0 ||
        index >= songs.length) {

      return;
    }


    // ------------------------------------------------------------
    // SAME SONG
    // ------------------------------------------------------------

    if (index ==
            currentSongIndex &&
        _hasActivePlayer) {

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


      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      songDuration =
          await musicService
              .getSongDuration();


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


      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      songDuration =
          await musicService
              .getSongDuration();


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


      if (!started) {

        isPlaying = false;

        _hasActivePlayer = false;

        _notifyUi();

        return;
      }


      _hasActivePlayer = true;

      isPlaying = true;


      songDuration =
          await musicService
              .getSongDuration();


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

    _positionTimer?.cancel();

    _completionSubscription?.cancel();


    musicService.stopSong();


    progressNotifier.dispose();
    uiStateNotifier.dispose();

    super.dispose();
  }
}

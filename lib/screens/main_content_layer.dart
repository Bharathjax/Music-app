import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart';
import '../controllers/playlist_controller.dart';
import '../delegates/music_search_delegate.dart';
import '../models/song.dart';
import '../widgets/app_header.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'settings_screen.dart';

class MainContentLayer extends StatefulWidget {
  final MusicPlayerController playerController;
  final PlaylistController playlistController;
  final ValueNotifier<int> selectedTabNotifier;
  final ValueNotifier<bool> transitionActiveNotifier;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainContentLayer({
    super.key,
    required this.playerController,
    required this.playlistController,
    required this.selectedTabNotifier,
    required this.transitionActiveNotifier,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<MainContentLayer> createState() => MainContentLayerState();
}

class MainContentLayerState extends State<MainContentLayer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<LibraryScreenState> _libraryKey =
      GlobalKey<LibraryScreenState>();
  int? _transitionFrom;
  int? _transitionTo;
  LibraryCategory? _pendingLibraryCategory;
  bool _updatingTabNotifier = false;
  late final AnimationController _pageTransitionController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedTabNotifier.value;
    widget.selectedTabNotifier.addListener(_handleExternalTabChange);
    widget.playerController.uiStateNotifier.addListener(_handlePlayerUiStateChange);
    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.transitionActiveNotifier.value = false;
          setState(() {
            _transitionFrom = null;
            _transitionTo = null;
          });
        }
      });
  }

  /// Handles Android/system Back without popping the app route.
  /// A Library subsection consumes the first Back and returns to Library.
  /// The Library root then returns Home. Other top-level sections return Home.
  bool handleSystemBack() {
    if (!mounted) return false;

    if (_currentIndex == 1) {
      final consumed = _libraryKey.currentState?.handleSystemBack() ?? false;
      if (consumed) {
        // A category opened from the Library root must return to the
        // Library root. Clear any stale Home-shortcut entry before the
        // Library widget is rebuilt, otherwise its initialCategory can
        // immediately reopen the old subsection.
        _pendingLibraryCategory = null;
        return true;
      }

      _pendingLibraryCategory = null;
      _selectTab(0);
      return true;
    }

    if (_currentIndex != 0) {
      _selectTab(0);
      return true;
    }

    return false;
  }


  void _handleExternalTabChange() {
    if (_updatingTabNotifier) return;
    final index = widget.selectedTabNotifier.value;
    // A Home shortcut can request a specific Library subsection. Preserve
    // that request when the ValueNotifier listener fires synchronously.
    _selectTab(
      index,
      updateNotifier: false,
      libraryCategory: index == 1 ? _pendingLibraryCategory : null,
    );
  }

  void _handlePlayerUiStateChange() {
    // Do not rebuild the content layer while Home/Library is moving.
    // The persistent player layer handles its own high-frequency updates.
    // If playback state changes during the transition, refresh once after
    // the transition has completed instead of rebuilding both page layers.
    if (!mounted || _transitionFrom != null) return;
    setState(() {});
  }

  void _selectTab(
    int index, {
    bool updateNotifier = true,
    LibraryCategory? libraryCategory,
  }) {
    if (index == 2) {
      openSearch();
      return;
    }

    // Always update the pending Library entry before the same-tab early
    // return. This prevents a stale Home shortcut from changing the Back
    // destination after navigating within Library.
    _pendingLibraryCategory =
        index == 1 && libraryCategory != null
            ? libraryCategory
            : null;

    if (index == _currentIndex && _transitionFrom == null) {
      if (index == 1 && libraryCategory == null) {
        _pendingLibraryCategory = null;
        _libraryKey.currentState?.returnToLibraryRoot();
      }
      return;
    }

    // A normal Library-root visit has no pending Home shortcut.

    final isHomeLibrary =
        (_currentIndex == 0 && index == 1) ||
        (_currentIndex == 1 && index == 0);

    if (updateNotifier && widget.selectedTabNotifier.value != index) {
      _updatingTabNotifier = true;
      try {
        widget.selectedTabNotifier.value = index;
      } finally {
        _updatingTabNotifier = false;
      }
    }

    if (isHomeLibrary) {
      widget.transitionActiveNotifier.value = true;
      setState(() {
        _transitionFrom = _currentIndex;
        _transitionTo = index;
        _currentIndex = index;
      });
      _pageTransitionController.forward(from: 0);
      return;
    }

    setState(() => _currentIndex = index);
  }

  void openSearch() {
    showSearch<Song?>(
      context: context,
      delegate: MusicSearchDelegate(
        songs: widget.playerController.songs,
        onSongSelected: widget.playerController.selectSong,
      ),
    );
  }

  Widget _buildPageForIndex(int index) {
    switch (index) {
      case 1:
        return LibraryScreen(
          key: _libraryKey,
          songs: widget.playerController.songs,
          favoriteSongs: widget.playerController.favoriteSongs,
          recentlyPlayedIndexes: widget.playerController.recentlyPlayedIndexes,
          onSearch: openSearch,
          onSongSelected: widget.playerController.selectSong,
          currentSongIndex: widget.playerController.currentSongIndex,
          isPlaying: widget.playerController.isPlaying,
          onFavorite: widget.playerController.toggleFavorite,
          onAddToQueue: widget.playerController.addToQueue,
          onRenameSong: (index, name) => widget.playerController.renameSong(index, name),
          onDeleteSong: (index) => widget.playerController.deleteSong(index),
          playerController: widget.playerController,
          onPlayQueue: (indexes, startPosition) =>
              widget.playerController.playSongQueue(
                indexes,
                startPosition: startPosition,
              ),
          playlistController: widget.playlistController,
          initialCategory: _pendingLibraryCategory,
          returnToHomeOnCategoryBack: _pendingLibraryCategory != null,
          onSystemBackHome: () {
            _pendingLibraryCategory = null;
            widget.selectedTabNotifier.value = 0;
          },
          onCategoryBackToLibraryRoot: () {
            // Explicitly entering a subsection from Library must discard any
            // previous Home-shortcut category source. Otherwise a rebuild can
            // reopen that old category and the next Back appears to go Home.
            _pendingLibraryCategory = null;
          },
        );
      case 3:
        return SettingsScreen(
          key: const ValueKey('settings'),
          currentThemeMode: widget.currentThemeMode,
          onThemeChanged: widget.onThemeChanged,
        );
      case 0:
      default:
        return Column(
          children: [
            AppHeader(onSearch: openSearch),
            Expanded(
              child: HomeScreen(
                key: const ValueKey('home'),
                songs: widget.playerController.songs,
                currentSongIndex: widget.playerController.currentSongIndex,
                isPlaying: widget.playerController.isPlaying,
                isLoadingSongs: widget.playerController.isLoadingSongs,
                permissionDenied: widget.playerController.permissionDenied,
                favoriteSongs: widget.playerController.favoriteSongs,
                playlistCount: widget.playlistController.playlists.length,
                onSongSelected: widget.playerController.selectSong,
                onPlayPause: widget.playerController.togglePlay,
                onAddToQueue: widget.playerController.addToQueue,
                onRenameSong: (index, name) => widget.playerController.renameSong(index, name),
                onDeleteSong: (index) => widget.playerController.deleteSong(index),
                onFavorite: widget.playerController.toggleFavorite,
                onOpenLibraryCategory: (category) => _selectTab(
                  1,
                  libraryCategory: category,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPage() => _buildPageForIndex(_currentIndex);

  Widget _buildHomeLibraryTransition() {
    final from = _transitionFrom;
    final to = _transitionTo;
    if (from == null || to == null) return _buildPage();

    final incomingFromRight = from == 0 && to == 1;
    final animation = CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );

    final fromPage = RepaintBoundary(child: _buildPageForIndex(from));
    final toPage = RepaintBoundary(child: _buildPageForIndex(to));

    return AnimatedBuilder(
      animation: animation,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [fromPage, toPage],
      ),
      builder: (context, child) {
        final value = animation.value;
        final width = MediaQuery.sizeOf(context).width;
        final outgoingOffset = incomingFromRight ? -width * value : width * value;
        final incomingOffset = incomingFromRight
            ? width * (1 - value)
            : -width * (1 - value);
        final stack = child! as Stack;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Transform.translate(
              offset: Offset(outgoingOffset, 0),
              child: stack.children.first,
            ),
            Transform.translate(
              offset: Offset(incomingOffset, 0),
              child: stack.children.last,
            ),
          ],
        );
      },
    );
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (_transitionFrom != null || _transitionTo != null) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 350) return;

    // Swipe left: Home -> Library.
    if (_currentIndex == 0 && velocity < 0) {
      _selectTab(1);
      return;
    }

    // Swipe right: Library -> Home.
    if (_currentIndex == 1 && velocity > 0) {
      _selectTab(0);
    }
  }

  Widget _buildStablePage() => _buildPage();

  @override
  Widget build(BuildContext context) {
    final content = (_transitionFrom != null && _transitionTo != null)
        ? _buildHomeLibraryTransition()
        : _buildStablePage();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleHorizontalSwipe,
      child: content,
    );
  }

  @override
  void dispose() {
    widget.transitionActiveNotifier.value = false;
    widget.selectedTabNotifier.removeListener(_handleExternalTabChange);
    widget.playerController.uiStateNotifier.removeListener(_handlePlayerUiStateChange);
    _pageTransitionController.dispose();
    super.dispose();
  }
}

/// Kept here only as a thin bridge so Now Playing remains visually and
/// behaviorally unchanged while living outside the Home/Library page tree.
class NowPlayingPageBridge extends StatelessWidget {
  final MusicPlayerController playerController;
  final PlaylistController playlistController;
  final Song song;
  final double progress;

  const NowPlayingPageBridge({
    super.key,
    required this.playerController,
    required this.playlistController,
    required this.song,
    required this.progress,
  });

  List<Song> _currentPlayingPlaylistSongs() {
    final source = playerController.playbackSourceName;
    final playlistId = playerController.playbackSourcePlaylistId;

    if (source == 'Favorites' && playlistId == null) {
      return playerController.playbackQueue
          .where((index) => index >= 0 && index < playerController.songs.length)
          .map((index) => playerController.songs[index])
          .toList();
    }

    if (playlistId == null) return const [];
    final matches = playlistController.playlists.where((p) => p.id == playlistId);
    if (matches.isEmpty) return const [];

    // playbackQueue may contain songs manually added with "Add to Queue".
    // Use it for the Now Playing queue so those temporary additions are
    // visible and play after the original playlist songs.
    return playerController.playbackQueue
        .where((index) => index >= 0 && index < playerController.songs.length)
        .map((index) => playerController.songs[index])
        .toList();
  }

  void _reorderNowPlayingPlaylist(int oldIndex, int newIndex) {
    final playlistId = playerController.playbackSourcePlaylistId;
    if (playlistId == null) {
      if (playerController.playbackSourceName != 'Favorites') return;
      final reordered = List<int>.from(playerController.playbackQueue);
      if (oldIndex < 0 || oldIndex >= reordered.length) return;
      final target = newIndex.clamp(0, reordered.length).toInt();
      final moved = reordered.removeAt(oldIndex);
      reordered.insert((target > oldIndex ? target - 1 : target).clamp(0, reordered.length), moved);
      playerController.updatePlaybackQueue(reordered, sourceName: 'Favorites');
      return;
    }

    final matches = playlistController.playlists.where((p) => p.id == playlistId);
    if (matches.isEmpty) return;

    playlistController.reorderSongs(playlistId, oldIndex, newIndex);
    final playlist = playlistController.playlists.firstWhere((p) => p.id == playlistId);
    final reordered = playlistController
        .songsForPlaylist(playlist, playerController.songs)
        .map(playerController.songs.indexOf)
        .where((index) => index >= 0)
        .toList();

    playerController.updatePlaybackQueue(
      reordered,
      sourceName: playlist.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NowPlayingPage(
      song: song,
      nextSong: playerController.upcomingSong,
      playlistName: playerController.playbackSourceName,
      playlistSongs: _currentPlayingPlaylistSongs(),
      onReorderPlaylist: _reorderNowPlayingPlaylist,
      isPlaying: playerController.isPlaying,
      isShuffle: playerController.isShuffle,
      repeatMode: playerController.repeatMode,
      durationMilliseconds: playerController.songDuration,
      progress: progress,
      onPlayPause: playerController.togglePlay,
      onNext: () => playerController.nextSong(),
      onPrevious: playerController.previousSong,
      onShuffle: playerController.toggleShuffle,
      onRepeat: playerController.toggleRepeat,
      onProgressChanged: playerController.changeProgress,
    );
  }
}

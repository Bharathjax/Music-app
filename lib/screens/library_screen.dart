import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/music_player_controller.dart';
import '../controllers/playlist_controller.dart';

import '../models/playlist.dart';

import '../models/song.dart';
import '../services/music_service.dart';
import '../widgets/song_tile.dart';

class LibraryScreen extends StatefulWidget {
  final List<Song> songs;
  final Set<int> favoriteSongs;
  final List<int> recentlyPlayedIndexes;
  final VoidCallback? onSearch;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Function(int)? onFavorite;
  final MusicPlayerController? playerController;
  final Function(List<int>, int)? onPlayQueue;
  final PlaylistController playlistController;
  final LibraryCategory? initialCategory;
  final bool returnToHomeOnCategoryBack;
  final VoidCallback? onSystemBackHome;
  final VoidCallback? onCategoryBackToLibraryRoot;

  const LibraryScreen({
    super.key,
    required this.songs,
    required this.favoriteSongs,
    this.recentlyPlayedIndexes = const <int>[],
    this.onSearch,
    this.onSongSelected,
    this.currentSongIndex = -1,
    this.isPlaying = false,
    this.onFavorite,
    this.playerController,
    this.onPlayQueue,
    required this.playlistController,
    this.initialCategory,
    this.returnToHomeOnCategoryBack = false,
    this.onSystemBackHome,
    this.onCategoryBackToLibraryRoot,
  });

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  LibraryCategory? _selectedCategory;
  String? _openedPlaylistId;
  bool _returnToHomeForCurrentCategory = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _returnToHomeForCurrentCategory = widget.returnToHomeOnCategoryBack;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // LibraryScreen is kept alive by MainContentLayer's GlobalKey. Therefore
    // initState() is not called again when switching between Home and Library.
    // Synchronize externally requested Library navigation here so a stale
    // Home-shortcut category can never survive a later Library-root visit.
    if (widget.initialCategory != oldWidget.initialCategory ||
        widget.returnToHomeOnCategoryBack !=
            oldWidget.returnToHomeOnCategoryBack) {
      setState(() {
        _selectedCategory = widget.initialCategory;
        _openedPlaylistId = null;
        _returnToHomeForCurrentCategory =
            widget.returnToHomeOnCategoryBack &&
                widget.initialCategory != null;
      });
    }
  }
  PlaylistController get _playlistController => widget.playlistController;


  /// Explicitly returns to the Library root. Used when the Library tab is
  /// selected while already on Library, so a stale shortcut category cannot
  /// remain active.
  void returnToLibraryRoot() {
    if (!mounted) return;
    setState(() {
      _selectedCategory = null;
      _openedPlaylistId = null;
      _returnToHomeForCurrentCategory = false;
    });
  }

  /// Handles a system Back request from the app shell.
  /// Returns true when Library consumed the request.
  bool handleSystemBack() {
    if (!mounted) return false;

    if (_openedPlaylistId != null) {
      setState(() => _openedPlaylistId = null);
      return true;
    }

    if (_selectedCategory != null) {
      if (_returnToHomeForCurrentCategory &&
          widget.onSystemBackHome != null) {
        widget.onSystemBackHome!();
      } else {
        setState(() => _selectedCategory = null);
        widget.onCategoryBackToLibraryRoot?.call();
      }
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // System Back is handled by the app-shell PopScope in MusicHomePage.
    // Library is an embedded page, so it must not install a second PopScope
    // that can consume the same navigation event and accidentally send the
    // user from a Library subsection all the way back to Home.
    return _buildLibraryContent(context);
  }

  Widget _buildLibraryContent(BuildContext context) {
    if (_openedPlaylistId != null) {
      final playlist = _playlistController.playlists
          .where((item) => item.id == _openedPlaylistId)
          .firstOrNull;
      if (playlist != null) {
        return _PlaylistDetailView(
          playlist: playlist,
          playlistController: _playlistController,
          songs: widget.songs,
          favoriteSongs: widget.favoriteSongs,
          onSongSelected: widget.onSongSelected,
          currentSongIndex: widget.currentSongIndex,
          isPlaying: widget.isPlaying,
          onFavorite: widget.onFavorite,
          playerController: widget.playerController,
          onPlayQueue: widget.onPlayQueue,
          onBack: () => setState(() => _openedPlaylistId = null),
          embedded: true,
        );
      }
    }

    if (_selectedCategory != null) {
      return LibraryCategoryScreen(
        category: _selectedCategory!,
        songs: widget.songs,
        favoriteSongs: widget.favoriteSongs,
        recentlyPlayedIndexes: widget.recentlyPlayedIndexes,
        onSongSelected: widget.onSongSelected,
        currentSongIndex: widget.currentSongIndex,
        isPlaying: widget.isPlaying,
        onFavorite: widget.onFavorite,
        playerController: widget.playerController,
        onPlayQueue: widget.onPlayQueue,
        playlistController: _playlistController,
        onBack: () {
          setState(() => _selectedCategory = null);
          if (!_returnToHomeForCurrentCategory) {
            widget.onCategoryBackToLibraryRoot?.call();
          }
        },
        onOpenPlaylist: (playlist) => setState(() => _openedPlaylistId = playlist.id),
        onCreatePlaylist: _createPlaylist,
        embedded: true,
      );
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LibraryHeader(onSearch: widget.onSearch),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  _LibraryItem(
                    icon: Icons.music_note_rounded,
                    title: 'All Songs',
                    subtitle: '${widget.songs.length} songs',
                    color: const Color(0xFFDCEFF1),
                    iconColor: const Color(0xFF4C929A),
                    onTap: () => _openCategory(LibraryCategory.allSongs),
                  ),
                  _LibraryItem(
                    icon: Icons.format_list_bulleted_rounded,
                    title: 'Playlists',
                    subtitle: '${_playlistController.playlists.length} ${_playlistController.playlists.length == 1 ? 'playlist' : 'playlists'}',
                    color: const Color(0xFFF5DCEB),
                    iconColor: const Color(0xFFC24788),
                    onTap: () => _openCategory(LibraryCategory.playlists),
                  ),
                  _LibraryItem(
                    icon: Icons.favorite_rounded,
                    title: 'Favorites',
                    subtitle: '${widget.favoriteSongs.length} songs',
                    color: const Color(0xFFF7DEDE),
                    iconColor: const Color(0xFFC75C59),
                    onTap: () => _openCategory(LibraryCategory.favorites),
                  ),
                  _LibraryItem(
                    icon: Icons.history_rounded,
                    title: 'Recently Played',
                    subtitle: '${widget.recentlyPlayedIndexes.length} songs',
                    color: const Color(0xFFE7E0F6),
                    iconColor: const Color(0xFF7659A8),
                    onTap: () => _openCategory(LibraryCategory.recentlyPlayed),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(LibraryCategory category) {
    // This is an explicit Library-root -> subsection navigation. It must
    // always return to the Library root, never Home.
    setState(() {
      _selectedCategory = category;
      _returnToHomeForCurrentCategory = false;
    });
  }

  Future<void> _createPlaylist() async {
    // Keep the TextEditingController inside the dialog widget itself.
    // Disposing a controller immediately after showDialog returns can race
    // with Flutter finishing the dialog route teardown and trigger framework
    // assertions such as "_dependents.isEmpty" on Android.
    final name = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create playlist',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const _CreatePlaylistDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted || name == null) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // Wait one frame after the dialog route has completely disappeared before
    // notifying the playlist list. This prevents the dialog teardown and the
    // AnimatedBuilder rebuild from happening in the same framework phase.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    _playlistController.createPlaylist(trimmed);
    await _playlistController.flush();

    if (!mounted) return;

    setState(() {
      _selectedCategory = LibraryCategory.playlists;
      _openedPlaylistId = null;
    });
  }

}


class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    // Let the dialog finish its entrance animation before opening the IME.
    // This prevents the popup animation and keyboard animation from competing
    // for the same frame budget on Android.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 210), () {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 10,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create playlist',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Playlist name',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum LibraryCategory {
  allSongs,
  playlists,
  albums,
  artists,
  favorites,
  recentlyPlayed,
}

class LibraryCategoryScreen extends StatelessWidget {
  final LibraryCategory category;
  final List<Song> songs;
  final Set<int> favoriteSongs;
  final List<int> recentlyPlayedIndexes;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Function(int)? onFavorite;
  final MusicPlayerController? playerController;
  final Function(List<int>, int)? onPlayQueue;
  final PlaylistController playlistController;
  final ValueChanged<Playlist>? onOpenPlaylist;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback? onBack;
  final bool embedded;

  const LibraryCategoryScreen({
    super.key,
    required this.category,
    required this.songs,
    required this.favoriteSongs,
    this.recentlyPlayedIndexes = const <int>[],
    this.onSongSelected,
    this.currentSongIndex = -1,
    this.isPlaying = false,
    this.onFavorite,
    this.playerController,
    this.onPlayQueue,
    required this.playlistController,
    this.onOpenPlaylist,
    this.onCreatePlaylist,
    this.onBack,
    this.embedded = false,
  });

  String get _title {
    switch (category) {
      case LibraryCategory.allSongs:
        return 'All Songs';
      case LibraryCategory.playlists:
        return 'Playlists';
      case LibraryCategory.albums:
        return 'Albums';
      case LibraryCategory.artists:
        return 'Artists';
      case LibraryCategory.favorites:
        return 'Favorites';
      case LibraryCategory.recentlyPlayed:
        return 'Recently Played';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (category != LibraryCategory.favorites)
          _CategoryHeader(
            title: _title,
            showAdd: category == LibraryCategory.playlists,
            onAdd: onCreatePlaylist,
            onBack: onBack,
          ),
        Expanded(child: _buildContent(context)),
      ],
    );

    // When embedded in MusicHomePage, system Back is handled centrally by
    // the app-shell PopScope. Keep the visible back button wired to onBack,
    // but do not add another PopScope here. Nested PopScopes can both receive
    // the same system-back event and cause Library -> Home to happen twice.
    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = playerController;
    if (controller == null) {
      return _buildContentForState(
        currentIndex: currentSongIndex,
        playing: isPlaying,
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return _buildContentForState(
          currentIndex: controller.currentSongIndex,
          playing: controller.isPlaying,
        );
      },
    );
  }

  Widget _buildContentForState({
    required int currentIndex,
    required bool playing,
  }) {
    switch (category) {
      case LibraryCategory.allSongs:
        return _SongList(
          songs: songs,
          onSongSelected: onSongSelected,
          currentSongIndex: currentIndex,
          isPlaying: playing,
          favoriteSongs: favoriteSongs,
          onFavorite: onFavorite,
        );
      case LibraryCategory.favorites:
        final favoriteList = favoriteSongs
            .where((index) => index >= 0 && index < songs.length)
            .map((index) => _IndexedSong(index: index, song: songs[index]))
            .toList();
        return _FavoritesSection(
          favoriteList: favoriteList,
          favoriteCount: favoriteList.length,
          onBack: onBack,
          onSongSelected: onSongSelected,
          currentSongIndex: currentIndex,
          isPlaying: playing,
          favoriteSongs: favoriteSongs,
          onFavorite: onFavorite,
          playerController: playerController,
          onPlayQueue: onPlayQueue,
          songs: songs,
        );
      case LibraryCategory.recentlyPlayed:
        final recentList = recentlyPlayedIndexes
            .where((index) => index >= 0 && index < songs.length)
            .map((index) => _IndexedSong(index: index, song: songs[index]))
            .toList();
        return _SongList(
          indexedSongs: recentList,
          emptyTitle: 'No recently played songs',
          emptySubtitle: 'Songs you play will appear here.',
          onSongSelected: onSongSelected,
          currentSongIndex: currentIndex,
          isPlaying: playing,
          favoriteSongs: favoriteSongs,
          onFavorite: onFavorite,
        );
      case LibraryCategory.albums:
        return _AlbumList(songs: songs);
      case LibraryCategory.artists:
        return _ArtistList(songs: songs);
      case LibraryCategory.playlists:
        return _PlaylistList(
          controller: playlistController,
          onOpen: onOpenPlaylist,
          onCreate: onCreatePlaylist,
        );
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final bool showAdd;
  final VoidCallback? onAdd;
  final VoidCallback? onBack;

  const _CategoryHeader({
    required this.title,
    required this.showAdd,
    this.onAdd,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
            ),
          ),
          if (showAdd)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 28),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}


class _FavoritesSection extends StatefulWidget {
  final List<_IndexedSong> favoriteList;
  final int favoriteCount;
  final VoidCallback? onBack;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Set<int> favoriteSongs;
  final Function(int)? onFavorite;
  final MusicPlayerController? playerController;
  final Function(List<int>, int)? onPlayQueue;
  final List<Song> songs;

  const _FavoritesSection({
    required this.favoriteList,
    required this.favoriteCount,
    required this.onBack,
    required this.onSongSelected,
    required this.currentSongIndex,
    required this.isPlaying,
    required this.favoriteSongs,
    required this.onFavorite,
    required this.playerController,
    required this.onPlayQueue,
    required this.songs,
  });

  @override
  State<_FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<_FavoritesSection>
    with TickerProviderStateMixin {
  late final AnimationController _cascadeController;
  late final AnimationController _heroController;
  late List<_IndexedSong> _items;

  @override
  void initState() {
    super.initState();
    _items = List<_IndexedSong>.from(widget.favoriteList);
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _FavoritesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final valid = widget.favoriteList.map((item) => item.index).toSet();
    final current = _items.where((item) => valid.contains(item.index)).toList();
    final currentIds = current.map((item) => item.index).toSet();
    for (final item in widget.favoriteList) {
      if (!currentIds.contains(item.index)) current.add(item);
    }
    _items = current;
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cascadeController.dispose();
    super.dispose();
  }

  Animation<double> _itemAnimation(int index) {
    final start = (index * 0.055).clamp(0.0, 0.62);
    final end = (start + 0.38).clamp(0.38, 1.0);
    return CurvedAnimation(
      parent: _cascadeController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _playFavorites() async {
    final indexes = _items.map((item) => item.index).toList();
    if (indexes.isEmpty) return;
    final controller = widget.playerController;
    if (controller != null) {
      final currentPosition = indexes.indexOf(widget.currentSongIndex);
      if (widget.isPlaying && currentPosition >= 0 &&
          controller.playbackSourceName == 'Favorites') {
        await controller.togglePlay();
        return;
      }
      await controller.playSongQueue(
        indexes,
        startPosition: currentPosition >= 0 ? currentPosition : 0,
        sourceName: 'Favorites',
      );
      return;
    }
    widget.onPlayQueue?.call(indexes, 0);
  }

  Future<void> _showAddFavorites(BuildContext context) async {
    final selected = <int>{};
    final available = widget.songs
        .asMap()
        .entries
        .where((entry) => !widget.favoriteSongs.contains(entry.key))
        .toList();

    if (available.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add to Favorites',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final entry = available[index];
                          final checked = selected.contains(entry.key);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(entry.value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(entry.value.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Checkbox(
                              value: checked,
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(entry.key);
                                  } else {
                                    selected.remove(entry.key);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setSheetState(() {
                                if (checked) {
                                  selected.remove(entry.key);
                                } else {
                                  selected.add(entry.key);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  for (final index in selected) {
                                    widget.onFavorite?.call(index);
                                  }
                                  Navigator.of(sheetContext).pop();
                                },
                          icon: const Icon(Icons.favorite_rounded),
                          label: Text(selected.isEmpty
                              ? 'Add selected songs'
                              : 'Add ${selected.length} ${selected.length == 1 ? 'song' : 'songs'}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasFavorites = _items.isNotEmpty;
    final favoriteAccent = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF6B7A)
        : const Color(0xFFD94F5C);
    final favoriteSoft = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF442033)
        : const Color(0xFFFFDDE5);
    final favoriteHeroStart = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF24152A)
        : const Color(0xFFFFE4EA);
    final playingFavorites = widget.isPlaying &&
        widget.playerController?.playbackSourceName == 'Favorites';
    final heroGlow = _heroController.value;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: favoriteHeroStart,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _heroController,
            builder: (context, _) => SizedBox(
            height: 272,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.1 + heroGlow * .25, -1.0),
                    end: Alignment(1.1, 1.0 - heroGlow * .2),
                    colors: [
                      Color.lerp(
                        isDark ? const Color(0xFF24152A) : const Color(0xFFFFDCE5),
                        isDark ? const Color(0xFF3A214A) : const Color(0xFFFFA0B0),
                        heroGlow * .35,
                      )!,
                      Color.lerp(
                        isDark ? const Color(0xFF3A214A) : const Color(0xFFFFA0B0),
                        isDark ? const Color(0xFF4A3545) : const Color(0xFFE8B8C8),
                        heroGlow * .25,
                      )!,
                      isDark ? const Color(0xFF15131F) : const Color(0xFFFFF0E8),
                    ],
                    stops: const [0.0, 0.56, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: -54,
                right: -28,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFFB38CFF) : const Color(0xFFFF8FA3)).withValues(alpha: isDark ? 0.10 : 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -66,
                left: -30,
                child: Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFF8C6BFF) : const Color(0xFFFFB6C2)).withValues(alpha: isDark ? 0.08 : 0.08),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.chevron_left_rounded, size: 30),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.70),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.onSurface.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Icon(Icons.favorite_rounded, size: 19, color: favoriteAccent),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? const [
                                      Color(0xFFFFF0F4),
                                      Color(0xFFFFB5C1),
                                      Color(0xFFFFD1D9),
                                    ]
                                  : const [
                                      Color(0xFF542B37),
                                      Color(0xFFB84F62),
                                      Color(0xFFD96A7B),
                                    ],
                            ).createShader(bounds),
                            child: Text(
                              'Favorites',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 38,
                                height: 1.02,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isDark ? .10 : .42,
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: isDark ? .12 : .20,
                                ),
                              ),
                            ),
                            child: Text(
                              '${_items.length} ${_items.length == 1 ? 'song' : 'songs'}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF66545A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PlaylistPlayButton(
                                isPlaying: playingFavorites,
                                enabled: hasFavorites,
                                onTap: hasFavorites ? _playFavorites : null,
                                accentColor: favoriteAccent,
                              ),
                              const SizedBox(width: 10),
                              _PlaylistShuffleButton(
                                active: widget.playerController?.isShuffle ?? false,
                                enabled: widget.playerController != null && hasFavorites,
                                onTap: widget.playerController == null || !hasFavorites
                                    ? null
                                    : widget.playerController!.toggleShuffle,
                                activeColor: favoriteAccent,
                                activeBackground: favoriteSoft,
                              ),
                              const SizedBox(width: 10),
                              _PlaylistAddButton(onTap: () => _showAddFavorites(context)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: !hasFavorites
              ? const _EmptyLibraryState(
                  title: 'No favorite songs yet',
                  subtitle: 'Tap the heart on a song to build your collection.',
                )
              : ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => child,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  itemCount: _items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final target = newIndex.clamp(0, _items.length).toInt();
                    final moved = _items.removeAt(oldIndex);
                    final adjusted = target > oldIndex ? target - 1 : target;
                    _items.insert(adjusted.clamp(0, _items.length), moved);
                    widget.playerController?.reorderFavorites(oldIndex, newIndex);

                    final indexes = _items.map((item) => item.index).toList();
                    if (widget.playerController?.playbackSourceName == 'Favorites') {
                      widget.playerController?.updatePlaybackQueue(
                        indexes,
                        sourceName: 'Favorites',
                      );
                    }
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final animation = _itemAnimation(index);
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('favorite-${item.index}-${item.song.uri}'),
                      index: index,
                      child: AnimatedBuilder(
                        animation: animation,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _LibrarySongRow(
                            song: item.song,
                            isCurrentSong: item.index == widget.currentSongIndex,
                            isPlaying: widget.isPlaying,
                            isFavorite: true,
                            onTap: () {
                              final indexes = _items.map((entry) => entry.index).toList();
                              if (widget.playerController != null) {
                                widget.playerController!.playSongQueue(
                                  indexes,
                                  startPosition: index,
                                  sourceName: 'Favorites',
                                );
                              } else {
                                widget.onSongSelected?.call(item.index);
                              }
                            },
                            onFavorite: widget.onFavorite == null
                                ? null
                                : () => widget.onFavorite!(item.index),
                          ),
                        ),
                        builder: (context, child) {
                          final value = animation.value;
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: Transform.scale(
                                scale: 0.985 + (0.015 * value),
                                alignment: Alignment.center,
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _SongList extends StatefulWidget {
  final List<Song>? songs;
  final List<_IndexedSong>? indexedSongs;
  final String emptyTitle;
  final String emptySubtitle;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Set<int> favoriteSongs;
  final Function(int)? onFavorite;

  const _SongList({
    this.songs,
    this.indexedSongs,
    this.emptyTitle = 'No songs found',
    this.emptySubtitle = 'Your music will appear here.',
    this.onSongSelected,
    this.currentSongIndex = -1,
    this.isPlaying = false,
    this.favoriteSongs = const <int>{},
    this.onFavorite,
  });

  @override
  State<_SongList> createState() => _SongListState();
}

class _SongListState extends State<_SongList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _itemAnimation(int index) {
    final start = (index * 0.055).clamp(0.0, 0.62);
    final end = (start + 0.38).clamp(0.38, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.indexedSongs ??
        (widget.songs ?? [])
            .asMap()
            .entries
            .map((entry) => _IndexedSong(index: entry.key, song: entry.value))
            .toList();

    if (items.isEmpty) {
      return _EmptyLibraryState(
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final item = items[index];
        final animation = _itemAnimation(index);
        return AnimatedBuilder(
          animation: animation,
          child: _LibrarySongRow(
            key: ValueKey('${item.song.uri}-$index'),
            song: item.song,
            isCurrentSong: item.index == widget.currentSongIndex,
            isPlaying: widget.isPlaying,
            isFavorite: widget.favoriteSongs.contains(item.index),
            onTap: widget.onSongSelected == null
                ? null
                : () => widget.onSongSelected!(item.index),
            onFavorite: widget.onFavorite == null
                ? null
                : () => widget.onFavorite!(item.index),
          ),
          builder: (context, child) {
            final value = animation.value;
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: Transform.scale(
                  scale: 0.985 + (0.015 * value),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumList extends StatelessWidget {
  final List<Song> songs;

  const _AlbumList({required this.songs});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> groups = {};
    for (final song in songs) {
      final album = (song.album ?? '').trim();
      if (album.isEmpty) continue;
      groups.putIfAbsent(album, () => []).add(song);
    }

    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (entries.isEmpty) {
      return const _EmptyLibraryState(
        title: 'No albums found',
        subtitle: 'Album information is not available for your songs.',
      );
    }

    return _CascadeList(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _CollectionRow(
          title: entry.key,
          subtitle: '${entry.value.length} songs',
          artworkSong: entry.value.first,
        );
      },
    );
  }
}

class _ArtistList extends StatelessWidget {
  final List<Song> songs;

  const _ArtistList({required this.songs});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> groups = {};
    for (final song in songs) {
      final artist = song.artist.trim();
      if (artist.isEmpty) continue;
      groups.putIfAbsent(artist, () => []).add(song);
    }

    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (entries.isEmpty) {
      return const _EmptyLibraryState(
        title: 'No artists found',
        subtitle: 'Artist information is not available for your songs.',
      );
    }

    return _CascadeList(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _CollectionRow(
          title: entry.key,
          subtitle: '${entry.value.length} songs',
          artworkSong: entry.value.first,
        );
      },
    );
  }
}

class _CascadeList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _CascadeList({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_CascadeList> createState() => _CascadeListState();
}

class _CascadeListState extends State<_CascadeList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: widget.itemCount,
      separatorBuilder: (_, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final start = (index * 0.055).clamp(0.0, 0.62);
        final end = (start + 0.38).clamp(0.38, 1.0);
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        return AnimatedBuilder(
          animation: animation,
          child: widget.itemBuilder(context, index),
          builder: (context, child) {
            final value = animation.value;
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: Transform.scale(
                  scale: 0.985 + (0.015 * value),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  final PlaylistController controller;
  final ValueChanged<Playlist>? onOpen;
  final VoidCallback? onCreate;

  const _PlaylistList({
    required this.controller,
    this.onOpen,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isLoaded) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.playlists.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 50,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No playlists yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a playlist to start organizing your music.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Playlist'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          itemCount: controller.playlists.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final playlist = controller.playlists[index];
            return _PlaylistCard(
              playlist: playlist,
              onTap: onOpen == null ? null : () => onOpen!(playlist),
              onDelete: () => controller.deletePlaylist(playlist.id),
            );
          },
        );
      },
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.playlist,
    this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: colors.primaryContainer,
                ),
                child: Icon(Icons.queue_music_rounded, color: colors.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.songKeys.length} ${playlist.songKeys.length == 1 ? 'song' : 'songs'}',
                      style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: const Text('Delete playlist'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onDelete();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;
  final PlaylistController playlistController;
  final List<Song> songs;
  final Set<int> favoriteSongs;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Function(int)? onFavorite;
  final MusicPlayerController? playerController;
  final Function(List<int>, int)? onPlayQueue;
  final VoidCallback onBack;
  final bool embedded;

  const _PlaylistDetailView({
    required this.playlist,
    required this.playlistController,
    required this.songs,
    required this.favoriteSongs,
    this.onSongSelected,
    required this.currentSongIndex,
    required this.isPlaying,
    this.onFavorite,
    this.playerController,
    this.onPlayQueue,
    required this.onBack,
    this.embedded = false,
  });

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView>
    with TickerProviderStateMixin {
  late final AnimationController _cascadeController;
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _cascadeController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  Animation<double> _itemAnimation(int index) {
    final start = (index * 0.055).clamp(0.0, 0.62);
    final end = (start + 0.38).clamp(0.38, 1.0);
    return CurvedAnimation(
      parent: _cascadeController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    final content = AnimatedBuilder(
      animation: widget.playlistController,
      builder: (context, _) {
        final currentPlaylist = widget.playlistController.playlists
            .where((item) => item.id == widget.playlist.id)
            .firstOrNull;
        if (currentPlaylist == null) return const SizedBox.shrink();

        final playlistSongs = widget.playlistController.songsForPlaylist(
          currentPlaylist,
          widget.songs,
        );
        final indexes = playlistSongs
            .map((song) => widget.songs.indexOf(song))
            .where((index) => index >= 0)
            .toList();
        final currentIndex =
            widget.playerController?.currentSongIndex ?? widget.currentSongIndex;
        final playing = widget.playerController?.isPlaying ?? widget.isPlaying;
        final playlistIsPlaying =
            playing && indexes.contains(currentIndex);

        final heroStart = isLight
            ? colors.primary
            : const Color(0xFF211C31);
        final heroMid = isLight
            ? const Color(0xFFB7A9E8)
            : const Color(0xFF3A314D);
        final heroEnd = isLight
            ? const Color(0xFFE8B8C8)
            : const Color(0xFF4A3545);
        final glow = _heroController.value;
        final panelColor = theme.scaffoldBackgroundColor;

        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Stack(
            children: [
              Column(
                children: [
                  // Compact, modern widget.playlist header.
                  AnimatedBuilder(
                    animation: _heroController,
                    builder: (context, _) => Container(
                    width: double.infinity,
                    height: 272,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.1 + glow * .08, -1.0),
                        end: Alignment(1.1, 1.0 - glow * .06),
                        colors: [
                          Color.lerp(heroStart, heroMid, glow * .12)!,
                          Color.lerp(heroMid, heroEnd, glow * .08)!,
                          heroEnd,
                        ],
                        stops: const [0.0, 0.56, 1.0],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -72,
                          right: -38,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF9E8BFF)).withValues(
                                alpha: isLight ? .16 : .05,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -70,
                          bottom: -115,
                          child: Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isLight ? const Color(0xFFE8B8C8) : const Color(0xFFB69CFF)).withValues(
                                alpha: isLight ? .06 : .06,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 50, 24, 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'PLAYLIST',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: isLight
                                      ? const Color(0xFF625B70)
                                      : Colors.white.withValues(alpha: .68),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isLight
                                      ? const [
                                          Color(0xFF3D3550),
                                          Color(0xFF6B5B8E),
                                          Color(0xFF8A596D),
                                        ]
                                      : const [
                                          Color(0xFFF3EEFF),
                                          Color(0xFFD8CCF5),
                                          Color(0xFFE7C5D0),
                                        ],
                                ).createShader(bounds),
                                child: Text(
                                  currentPlaylist.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontSize: 26,
                                    height: 1.08,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: isLight ? .42 : .10,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: isLight ? .20 : .12),
                                  ),
                                ),
                                child: Text(
                                  '${playlistSongs.length} ${playlistSongs.length == 1 ? 'song' : 'songs'}',
                                  style: TextStyle(
                                    color: isLight
                                        ? const Color(0xFF5F596C)
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PlaylistPlayButton(
                                    isPlaying: playlistIsPlaying,
                                    enabled: indexes.isNotEmpty,
                                    onTap: indexes.isEmpty
                                        ? null
                                        : () => _handlePlaylistPlay(
                                              indexes,
                                              currentIndex,
                                              playing,
                                              currentPlaylist.name,
                                            ),
                                  ),
                                  const SizedBox(width: 10),
                                  _PlaylistShuffleButton(
                                    active: widget.playerController?.isShuffle ?? false,
                                    enabled: widget.playerController != null && indexes.isNotEmpty,
                                    onTap: widget.playerController == null || indexes.isEmpty
                                        ? null
                                        : widget.playerController!.toggleShuffle,
                                  ),
                                  const SizedBox(width: 10),
                                  _PlaylistAddButton(
                                    onTap: () => _showAddSongs(context, currentPlaylist),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: playlistSongs.isEmpty
                          ? _EmptyLibraryState(
                              title: 'Playlist is empty',
                              subtitle: 'Tap + to add songs from your library.',
                            )
                          : ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) {
                                return child;
                              },
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                              itemCount: playlistSongs.length,
                              onReorderItem: (oldIndex, newIndex) {
                                widget.playlistController.reorderSongs(
                                  currentPlaylist.id,
                                  oldIndex,
                                  newIndex,
                                );

                                final reordered = List<Song>.from(playlistSongs);
                                final moved = reordered.removeAt(oldIndex);
                                reordered.insert(newIndex, moved);

                                final reorderedIndexes = reordered
                                    .map((song) => widget.songs.indexOf(song))
                                    .where((index) => index >= 0)
                                    .toList();
                                if (widget.playerController != null &&
                                    widget.playerController!.playbackSourceName == currentPlaylist.name) {
                                  widget.playerController!.updatePlaybackQueue(
                                    reorderedIndexes,
                                    sourceName: currentPlaylist.name,
                                  );
                                }
                              },
                              itemBuilder: (context, index) {
                                final song = playlistSongs[index];
                                final globalIndex = widget.songs.indexOf(song);
                                final animation = _itemAnimation(index);

                                return ReorderableDelayedDragStartListener(
                                  key: ValueKey(
                                    '${currentPlaylist.id}-${widget.playlistController.songKey(song)}',
                                  ),
                                  index: index,
                                  child: AnimatedBuilder(
                                    animation: animation,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Dismissible(
                                        key: ValueKey(
                                          'dismiss-${currentPlaylist.id}-${widget.playlistController.songKey(song)}',
                                        ),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 24),
                                          decoration: BoxDecoration(
                                            color: colors.errorContainer,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: colors.onErrorContainer,
                                          ),
                                        ),
                                        confirmDismiss: (_) async {
                                          widget.playlistController.removeSong(
                                            currentPlaylist.id,
                                            song,
                                          );
                                          return false;
                                        },
                                        child: SongTile(
                                          song: song,
                                          isCurrentSong: globalIndex == currentIndex,
                                          isPlaying: playing,
                                          isFavorite: globalIndex >= 0 &&
                                              widget.favoriteSongs.contains(globalIndex),
                                          onTap: globalIndex < 0
                                              ? () {}
                                              : () {
                                                  final position = indexes.indexOf(globalIndex);
                                                  if (position >= 0) {
                                                    if (widget.playerController != null) {
                                                      widget.playerController!.playSongQueue(
                                                        indexes,
                                                        startPosition: position,
                                                        sourceName: currentPlaylist.name,
                                                        sourcePlaylistId: currentPlaylist.id,
                                                      );
                                                    } else if (widget.onPlayQueue != null) {
                                                      widget.onPlayQueue!(indexes, position);
                                                    } else {
                                                      widget.onSongSelected?.call(globalIndex);
                                                    }
                                                    return;
                                                  }
                                                  widget.onSongSelected?.call(globalIndex);
                                                },
                                          onFavorite: globalIndex < 0 || widget.onFavorite == null
                                              ? () {}
                                              : () => widget.onFavorite!(globalIndex),
                                        ),
                                      ),
                                    ),
                                    builder: (context, child) {
                                      final value = animation.value;
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 18 * (1 - value)),
                                          child: Transform.scale(
                                            scale: 0.985 + (0.015 * value),
                                            alignment: Alignment.center,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                left: 10,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: isLight ? .65 : .12),
                    foregroundColor: isLight ? const Color(0xFF292536) : Colors.white,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: IconButton(
                  tooltip: 'Playlist options',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) => SafeArea(
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline_rounded),
                          title: const Text('Delete playlist'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            widget.playlistController.deletePlaylist(currentPlaylist.id);
                            widget.onBack();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.more_vert_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: isLight ? .65 : .12),
                    foregroundColor: isLight ? const Color(0xFF292536) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(child: content),
    );
  }

  Future<void> _handlePlaylistPlay(
    List<int> indexes,
    int currentIndex,
    bool playing,
    String playlistName,
  ) async {
    final currentIsInPlaylist = indexes.contains(currentIndex);
    if (playing && currentIsInPlaylist && widget.playerController != null) {
      await widget.playerController!.togglePlay();
      return;
    }
    if (widget.playerController != null) {
      final position = indexes.indexOf(currentIndex);
      await widget.playerController!.playSongQueue(
        indexes,
        startPosition: position >= 0 ? position : 0,
        sourceName: playlistName,
        sourcePlaylistId: widget.playlist.id,
      );
      return;
    }
    if (widget.onPlayQueue != null) {
      widget.onPlayQueue!(indexes, 0);
    } else if (indexes.isNotEmpty) {
      widget.onSongSelected?.call(indexes.first);
    }
  }

  Future<void> _showAddSongs(BuildContext context, Playlist target) async {
    final selected = <String>{
      ...target.songKeys,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add songs',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        itemCount: widget.songs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final song = widget.songs[index];
                          final key = widget.playlistController.songKey(song);
                          final checked = selected.contains(key);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Checkbox(
                              value: checked,
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(key);
                                  } else {
                                    selected.remove(key);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setSheetState(() {
                                if (checked) {
                                  selected.remove(key);
                                } else {
                                  selected.add(key);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            widget.playlistController.addSongs(
                              target.id,
                              widget.songs.where((song) => selected.contains(widget.playlistController.songKey(song))),
                            );
                            Navigator.of(sheetContext).pop();
                          },
                          child: Text('Save ${selected.isNotEmpty ? '(${selected.length})' : ''}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IndexedSong {
  final int index;
  final Song song;

  const _IndexedSong({required this.index, required this.song});
}

class _LibrarySongRow extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  const _LibrarySongRow({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.isFavorite,
    this.onTap,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SongTile(
      song: song,
      isCurrentSong: isCurrentSong,
      isPlaying: isPlaying,
      isFavorite: isFavorite,
      onTap: onTap ?? () {},
      onFavorite: onFavorite ?? () {},
    );
  }
}

class _CollectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Song artworkSong;

  const _CollectionRow({
    required this.title,
    required this.subtitle,
    required this.artworkSong,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _Artwork(song: artworkSong, size: 56, radius: 9),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistAddButton extends StatelessWidget {
  const _PlaylistAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.12),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            size: 20,
            color: colors.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}


class _PlaylistPlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? accentColor;

  const _PlaylistPlayButton({
    required this.isPlaying,
    required this.enabled,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = accentColor ?? const Color(0xFF6D5CE7);
    return SizedBox(
      width: 62,
      height: 62,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          // Distinct primary action: rich lavender with a clean white icon.
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor: colors.onSurfaceVariant,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _PlaylistShuffleButton extends StatelessWidget {
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? activeColor;
  final Color? activeBackground;

  const _PlaylistShuffleButton({
    required this.active,
    required this.enabled,
    required this.onTap,
    this.activeColor,
    this.activeBackground,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Warm accent keeps shuffle visually distinct from the primary play action.
    final activeAccent = activeColor ?? const Color(0xFFE98B67);
    final activeSurface = activeBackground ?? const Color(0xFFFFE5DA);
    final inactiveBackground = colors.surfaceContainerHighest;

    return IconButton(
      onPressed: enabled ? onTap : null,
      tooltip: active ? 'Shuffle on' : 'Shuffle off',
      icon: Icon(
        Icons.shuffle_rounded,
        color: active
            ? activeAccent
            : (enabled ? colors.onSurface : colors.onSurfaceVariant),
      ),
      style: IconButton.styleFrom(
        foregroundColor: active ? activeAccent : colors.onSurface,
        backgroundColor: active ? activeSurface : inactiveBackground,
        disabledBackgroundColor: inactiveBackground,
        side: BorderSide(
          color: active
              ? activeAccent.withValues(alpha: 0.60)
              : colors.onSurface.withValues(alpha: 0.06),
          width: active ? 1.1 : 0.7,
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final Song song;
  final double size;
  final double radius;

  const _Artwork({
    required this.song,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MusicService().getArtwork(song),
      initialData: MusicService().getCachedArtwork(song),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.music_note_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyLibraryState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 48,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final VoidCallback? onSearch;

  const _LibraryHeader({this.onSearch});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Your Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                  color: colors.onSurface,
                ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.search_rounded, size: 25),
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _LibraryItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                          letterSpacing: -0.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

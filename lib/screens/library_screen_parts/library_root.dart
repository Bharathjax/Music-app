part of '../library_screen.dart';

class LibraryScreen extends StatefulWidget {
  final List<Song> songs;
  final Set<int> favoriteSongs;
  final List<int> recentlyPlayedIndexes;
  final VoidCallback? onSearch;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Function(int)? onFavorite;
  final Function(int)? onAddToQueue;
  final Future<bool> Function(int, String)? onRenameSong;
  final Future<bool> Function(int)? onDeleteSong;
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
    this.onAddToQueue,
    this.onRenameSong,
    this.onDeleteSong,
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
          onAddToQueue: widget.onAddToQueue,
          onRenameSong: widget.onRenameSong,
          onDeleteSong: widget.onDeleteSong,
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
        onAddToQueue: widget.onAddToQueue,
        onRenameSong: widget.onRenameSong,
        onDeleteSong: widget.onDeleteSong,
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

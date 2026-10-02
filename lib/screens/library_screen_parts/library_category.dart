part of '../library_screen.dart';

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
  final Function(int)? onAddToQueue;
  final Future<bool> Function(int, String)? onRenameSong;
  final Future<bool> Function(int)? onDeleteSong;
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
    this.onAddToQueue,
    this.onRenameSong,
    this.onDeleteSong,
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
          onAddToQueue: onAddToQueue,
          onRenameSong: onRenameSong,
          onDeleteSong: onDeleteSong,
          onPlayPause: playerController == null ? null : () => playerController!.togglePlay(),
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
          onAddToQueue: onAddToQueue,
          onRenameSong: onRenameSong,
          onDeleteSong: onDeleteSong,
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
          onAddToQueue: onAddToQueue,
          onRenameSong: onRenameSong,
          onDeleteSong: onDeleteSong,
          onPlayPause: playerController == null ? null : () => playerController!.togglePlay(),
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

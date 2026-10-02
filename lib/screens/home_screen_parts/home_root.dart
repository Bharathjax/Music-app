part of '../home_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Song> songs;
  final int currentSongIndex;
  final bool isPlaying;
  final bool isLoadingSongs;
  final bool permissionDenied;
  final Set<int> favoriteSongs;
  final int playlistCount;
  final Function(int) onSongSelected;
  final Function(int) onFavorite;
  final ValueChanged<LibraryCategory> onOpenLibraryCategory;
  final VoidCallback onPlayPause;
  final Function(int) onAddToQueue;
  final Future<bool> Function(int, String) onRenameSong;
  final Future<bool> Function(int) onDeleteSong;

  const HomeScreen({
    super.key,
    required this.songs,
    required this.currentSongIndex,
    required this.isPlaying,
    required this.isLoadingSongs,
    required this.permissionDenied,
    required this.favoriteSongs,
    required this.playlistCount,
    required this.onSongSelected,
    required this.onFavorite,
    required this.onOpenLibraryCategory,
    required this.onPlayPause,
    required this.onAddToQueue,
    required this.onRenameSong,
    required this.onDeleteSong,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoriteCount = widget.favoriteSongs.length;
    final songCount = widget.songs.length;

    return CustomScrollView(
      key: const PageStorageKey('reference-home'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _HomeHero(
              animation: _heroController,
              songCount: songCount,
              favoriteCount: favoriteCount,
              playlistCount: widget.playlistCount,
              isPlaying: widget.isPlaying,
              onPlay: songCount == 0 ? null : () => widget.onSongSelected(0),
              onPlayPause: widget.onPlayPause,
              onFavorites: () => widget.onOpenLibraryCategory(
                LibraryCategory.favorites,
              ),
              onQuickAction: widget.onOpenLibraryCategory,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const _SectionHeader(title: 'All Songs'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (widget.isLoadingSongs)
          const SliverToBoxAdapter(child: _LoadingState())
        else if (widget.permissionDenied)
          const SliverToBoxAdapter(child: _PermissionState())
        else if (widget.songs.isEmpty)
          const SliverToBoxAdapter(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: widget.songs.length,
              itemBuilder: (context, index) {
                final song = widget.songs[index];
                return _SongRow(
                  key: ValueKey('home-song-$index'),
                  song: song,
                  isCurrentSong: index == widget.currentSongIndex,
                  isPlaying: widget.isPlaying,
                  isFavorite: widget.favoriteSongs.contains(index),
                  onTap: () => widget.onSongSelected(index),
                  onFavorite: () => widget.onFavorite(index),
                  onPlayPause: widget.onPlayPause,
                  onAddToQueue: () => widget.onAddToQueue(index),
                  onRenameSong: (name) => widget.onRenameSong(index, name),
                  onDeleteSong: () => widget.onDeleteSong(index),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }
}

part of '../library_screen.dart';

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
  final Function(int)? onAddToQueue;
  final Future<bool> Function(int, String)? onRenameSong;
  final Future<bool> Function(int)? onDeleteSong;
  final VoidCallback? onPlayPause;

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
    this.onAddToQueue,
    this.onRenameSong,
    this.onDeleteSong,
    this.onPlayPause,
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
            onAddToQueue: widget.onAddToQueue == null
                ? null
                : () => widget.onAddToQueue!(item.index),
            onRenameSong: widget.onRenameSong == null
                ? null
                : (name) => widget.onRenameSong!(item.index, name),
            onDeleteSong: widget.onDeleteSong == null
                ? null
                : () => widget.onDeleteSong!(item.index),
            onPlayPause: widget.currentSongIndex == item.index
                ? widget.onPlayPause
                : null,
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
class _LibrarySongRow extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToQueue;
  final Future<bool> Function(String)? onRenameSong;
  final Future<bool> Function()? onDeleteSong;
  final VoidCallback? onPlayPause;

  const _LibrarySongRow({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.isFavorite,
    this.onTap,
    this.onFavorite,
    this.onAddToQueue,
    this.onRenameSong,
    this.onDeleteSong,
    this.onPlayPause,
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
      onAddToQueue: onAddToQueue,
      onRenameSong: onRenameSong,
      onDeleteSong: onDeleteSong,
      onPlayPause: onPlayPause,
    );
  }
}

part of '../library_screen.dart';

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

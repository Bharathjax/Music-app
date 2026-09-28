import 'package:flutter/material.dart';

import '../models/song.dart';
import 'library_screen.dart';
import '../widgets/song_tile.dart';

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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _HomeHero(
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
                const SizedBox(height: 18),
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
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }
}



class _HomeHero extends StatelessWidget {
  final Animation<double> animation;
  final int songCount;
  final int favoriteCount;
  final int playlistCount;
  final VoidCallback? onPlay;
  final VoidCallback onPlayPause;
  final VoidCallback onFavorites;
  final bool isPlaying;
  final ValueChanged<LibraryCategory>? onQuickAction;

  const _HomeHero({
    required this.animation,
    required this.songCount,
    required this.favoriteCount,
    required this.playlistCount,
    required this.onPlay,
    required this.onPlayPause,
    required this.onFavorites,
    required this.isPlaying,
    this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroStart = isDark ? const Color(0xFF121022) : const Color(0xFF8C82B2);
    final heroMid = isDark ? const Color(0xFF211A35) : const Color(0xFFA092C4);
    final heroEnd = isDark ? const Color(0xFF32202F) : const Color(0xFFC895A8);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final glow = Curves.easeInOut.transform(t);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + glow * .35, -1.0),
              end: Alignment(1.15, 1.0 - glow * .25),
              colors: [
                Color.lerp(heroStart, heroMid, glow)!,
                Color.lerp(heroMid, heroEnd, glow)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: .14),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -62 + glow * 18,
                top: -72,
                child: _GlowOrb(size: 170, opacity: .045),
              ),
              Positioned(
                left: -54 - glow * 12,
                bottom: -86,
                child: _GlowOrb(size: 150, opacity: .03),
              ),
              Positioned(
                right: 18,
                top: 72 + glow * 8,
                child: Transform.rotate(
                  angle: -.12 + glow * .08,
                  child: _MusicWaveMark(
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isDark
                                      ? const [Color(0xFFFFFFFF), Color(0xFFD8CCFF)]
                                      : const [Color(0xFFFFFFFF), Color(0xFFF4D8FF)],
                                ).createShader(bounds),
                                child: const Text(
                                  'Your music.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 31,
                                    height: .98,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Your moment.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .82),
                                  fontSize: 22,
                                  height: 1.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.65,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF8E79E8).withValues(alpha: .78)
                                : const Color(0xFF8D78E8).withValues(alpha: .88),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFC5B8FF).withValues(alpha: .62)
                                  : const Color(0xFFB9AAFF).withValues(alpha: .72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? const Color(0xFF9B86FF).withValues(alpha: .28)
                                    : const Color(0xFF9A88F2).withValues(alpha: .20),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: onPlayPause,
                            padding: EdgeInsets.zero,
                            tooltip: isPlaying ? 'Pause' : 'Play all',
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 46,
                      child: _HeroQuickActions(
                        playlistCount: playlistCount,
                        favoriteCount: favoriteCount,
                        onSelected: (category) {
                          if (category == LibraryCategory.favorites) {
                            onFavorites();
                          } else {
                            onQuickAction?.call(category);
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroQuickActions extends StatelessWidget {
  final int playlistCount;
  final int favoriteCount;
  final ValueChanged<LibraryCategory> onSelected;

  const _HeroQuickActions({
    required this.playlistCount,
    required this.favoriteCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeroQuickChip(
          icon: Icons.queue_music_rounded,
          label: 'Playlists',
          count: playlistCount,
          accent: const Color(0xFF9B86F5),
          onTap: () => onSelected(LibraryCategory.playlists),
        ),
        const SizedBox(width: 12),
        _HeroQuickChip(
          icon: Icons.favorite_rounded,
          label: 'Favorites',
          count: favoriteCount,
          accent: const Color(0xFFF06F86),
          onTap: () => onSelected(LibraryCategory.favorites),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

class _HeroQuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _HeroQuickChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroSurface = accent.withValues(alpha: isDark ? .62 : .82);
    final heroBorder = accent.withValues(alpha: isDark ? .80 : .92);

    return Expanded(
      child: Material(
        color: heroSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: heroBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicWaveMark extends StatelessWidget {
  final Color color;

  const _MusicWaveMark({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [22.0, 42.0, 58.0, 34.0, 48.0, 27.0, 40.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final height in heights)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowOrb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: colors.onSurface,
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _SongRow({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SongTile(
      song: song,
      isCurrentSong: isCurrentSong,
      isPlaying: isPlaying,
      isFavorite: isFavorite,
      onTap: onTap,
      onFavorite: onFavorite,
    );
  }
}


class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading your music…',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.folder_off_rounded, size: 32, color: colors.onSurface.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text('Music permission is required', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
          const SizedBox(height: 5),
          Text('Allow access to your device music to build your library.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.4, color: colors.onSurface.withValues(alpha: 0.52))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const _icon = Icons.music_off_rounded;
  static const _title = 'No music found';
  static const _subtitle = 'Add music to your device to build your library.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Icon(
            _icon,
            size: 32,
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: colors.onSurface.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

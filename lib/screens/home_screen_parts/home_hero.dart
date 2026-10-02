part of '../home_screen.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          height: 206,
          margin: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? const [
                      Color(0xFFF4F2FF),
                      Color(0xFFEDEAFF),
                      Color(0xFFF8F5FF),
                    ]
                  : const [
                      Color(0xFF211C31),
                      Color(0xFF252037),
                      Color(0xFF171820),
                    ],
            ),
            border: Border.all(
              color: isLight
                  ? Colors.white.withValues(alpha: .9)
                  : Colors.white.withValues(alpha: .07),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: isLight ? .08 : .10),
                blurRadius: 28,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -55,
                right: -35,
                child: Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: isLight ? .09 : .08),
                  ),
                ),
              ),
              Positioned(
                bottom: -72,
                left: 70,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: .045),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF6657E8),
                                Color(0xFF9A5DE8),
                                Color(0xFFE85D8F),
                                Color(0xFFFF6B5E),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'Your music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 25,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.7,
                              ),
                            ),
                          ),
                        ),
                        _HomeIconBadge(color: colors.primary),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(21),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isLight
                                  ? const [Color(0xFF6256D8), Color(0xFF8A65D8)]
                                  : const [Color(0xFF9B8CFF), Color(0xFF6554B8)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .22),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your collection',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _HomePrimaryAction(
                            icon: isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            label: isPlaying ? 'Pause' : 'Play all',
                            enabled: songCount > 0,
                            color: colors.primary,
                            onTap: songCount == 0 ? null : onPlayPause,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _HomeIconAction(
                            icon: Icons.favorite_rounded,
                            enabled: favoriteCount > 0,
                            onTap: onFavorites,
                            color: const Color(0xFFF06F86),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _HomeIconAction(
                            icon: Icons.queue_music_rounded,
                            enabled: playlistCount > 0,
                            onTap: () => onQuickAction?.call(LibraryCategory.playlists),
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
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

class _HomeIconBadge extends StatelessWidget {
  final Color color;
  const _HomeIconBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Icon(Icons.home_rounded, color: color, size: 21),
    );
  }
}

class _HomePrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _HomePrimaryAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : color.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIconAction extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final Color color;

  const _HomeIconAction({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Material(
      color: enabled ? surface : surface.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 21,
            color: enabled ? color : color.withValues(alpha: .40),
          ),
        ),
      ),
    );
  }
}

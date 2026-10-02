part of '../library_screen.dart';

class _FavoritesSection extends StatefulWidget {
  final List<_IndexedSong> favoriteList;
  final int favoriteCount;
  final VoidCallback? onBack;
  final Function(int)? onSongSelected;
  final int currentSongIndex;
  final bool isPlaying;
  final Set<int> favoriteSongs;
  final Function(int)? onFavorite;
  final Function(int)? onAddToQueue;
  final Future<bool> Function(int, String)? onRenameSong;
  final Future<bool> Function(int)? onDeleteSong;
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
    this.onAddToQueue,
    required this.onRenameSong,
    required this.onDeleteSong,
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
      if (widget.isPlaying && controller.playbackSourceName == 'Favorites') {
        await controller.togglePlay();
        return;
      }
      // Starting Favorites from another source always begins at song one.
      await controller.playSongQueue(
        indexes,
        startPosition: 0,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasFavorites = _items.isNotEmpty;
    final playingFavorites = widget.isPlaying &&
        widget.playerController?.playbackSourceName == 'Favorites';

    final favoriteAccent = isDark
        ? const Color(0xFFFF8FA3)
        : const Color(0xFFD84F68);
    final favoriteSoft = isDark
        ? const Color(0xFF38202B)
        : const Color(0xFFFFE7EC);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Column(
        children: [
          // Modern floating Favorites header instead of a full-width rectangle.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AnimatedBuilder(
              animation: _heroController,
              builder: (context, _) {
                final glow = _heroController.value;
                return Container(
                  height: 206,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [
                              Color(0xFF211A2B),
                              Color(0xFF241A25),
                              Color(0xFF171820),
                            ]
                          : const [
                              Color(0xFFFFF5F7),
                              Color(0xFFFFE9EE),
                              Color(0xFFF7F4FB),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: favoriteAccent.withValues(alpha: isDark ? 0.10 : 0.08),
                        blurRadius: 28,
                        spreadRadius: -10,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -55 + (glow * 8),
                        right: -35,
                        child: Container(
                          width: 155,
                          height: 155,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: favoriteAccent.withValues(
                              alpha: isDark ? 0.09 : 0.11,
                            ),
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
                            color: colors.primary.withValues(alpha: 0.055),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _FavoritesBackButton(
                                  onTap: widget.onBack,
                                ),
                                const Spacer(),
                                _FavoritesIconBadge(
                                  color: favoriteAccent,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        favoriteAccent,
                                        isDark
                                            ? const Color(0xFFB95B9B)
                                            : const Color(0xFF8A65D8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: favoriteAccent.withValues(alpha: 0.25),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 31,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Favorites',
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontSize: 28,
                                          height: 1,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.7,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_items.length} ${_items.length == 1 ? 'song' : 'songs'} you love',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _FavoritesPrimaryAction(
                                    icon: playingFavorites
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    label: playingFavorites ? 'Pause' : 'Play all',
                                    enabled: hasFavorites,
                                    color: favoriteAccent,
                                    onTap: hasFavorites ? _playFavorites : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _FavoritesIconAction(
                                  icon: Icons.shuffle_rounded,
                                  active: widget.playerController?.isShuffle ?? false,
                                  enabled: widget.playerController != null && hasFavorites,
                                  activeColor: favoriteAccent,
                                  activeBackground: favoriteSoft,
                                  onTap: widget.playerController == null || !hasFavorites
                                      ? null
                                      : widget.playerController!.toggleShuffle,
                                ),
                                const SizedBox(width: 8),
                                _FavoritesIconAction(
                                  icon: Icons.add_rounded,
                                  enabled: true,
                                  activeColor: colors.onSurface,
                                  activeBackground: colors.surface.withValues(alpha: 0.82),
                                  onTap: () => _showAddFavorites(context),
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
            ),
          ),
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
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
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
                            padding: const EdgeInsets.only(bottom: 5),
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
                              onAddToQueue: widget.onAddToQueue == null
                                  ? null
                                  : () => widget.onAddToQueue!(item.index),
                              onRenameSong: widget.onRenameSong == null
                                  ? null
                                  : (name) => widget.onRenameSong!(item.index, name),
                              onDeleteSong: widget.onDeleteSong == null
                                  ? null
                                  : () => widget.onDeleteSong!(item.index),
                            ),
                          ),
                          builder: (context, child) {
                            final value = animation.value;
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - value)),
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

class _FavoritesBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _FavoritesBackButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.76),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.chevron_left_rounded, size: 27),
        ),
      ),
    );
  }
}

class _FavoritesIconBadge extends StatelessWidget {
  final Color color;

  const _FavoritesIconBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.76),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.favorite_rounded, size: 18, color: color),
    );
  }
}

class _FavoritesPrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _FavoritesPrimaryAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesIconAction extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool enabled;
  final Color activeColor;
  final Color activeBackground;
  final VoidCallback? onTap;

  const _FavoritesIconAction({
    required this.icon,
    this.active = false,
    required this.enabled,
    required this.activeColor,
    required this.activeBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = active
        ? activeBackground
        : colors.surface.withValues(alpha: 0.76);
    final foreground = active ? activeColor : colors.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 21,
            color: enabled
                ? foreground
                : foreground.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

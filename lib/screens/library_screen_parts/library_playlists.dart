part of '../library_screen.dart';

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
  final Function(int)? onAddToQueue;
  final Future<bool> Function(int, String)? onRenameSong;
  final Future<bool> Function(int)? onDeleteSong;
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
    this.onAddToQueue,
    this.onRenameSong,
    this.onDeleteSong,
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

  @override
  void initState() {
    super.initState();
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
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

        final panelColor = theme.scaffoldBackgroundColor;

        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      height: 206,
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
                                    _FavoritesBackButton(onTap: widget.onBack),
                                    const Spacer(),
                                    _FavoritesIconBadge(color: colors.primary),
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
                                          colors: [
                                            isLight
                                                ? const Color(0xFF6256D8)
                                                : const Color(0xFF9B8CFF),
                                            isLight
                                                ? const Color(0xFF8A65D8)
                                                : const Color(0xFF6554B8),
                                          ],
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
                                        Icons.queue_music_rounded,
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
                                            currentPlaylist.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontSize: 23,
                                              height: 1.05,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -.5,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            '${playlistSongs.length} ${playlistSongs.length == 1 ? 'song' : 'songs'}',
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
                                      child: _FavoritesPrimaryAction(
                                        icon: playlistIsPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        label: playlistIsPlaying ? 'Pause' : 'Play all',
                                        enabled: indexes.isNotEmpty,
                                        color: colors.primary,
                                        onTap: indexes.isEmpty
                                            ? null
                                            : () => _handlePlaylistPlay(
                                                  indexes,
                                                  currentIndex,
                                                  playing,
                                                  currentPlaylist.name,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _FavoritesIconAction(
                                      icon: Icons.shuffle_rounded,
                                      active: widget.playerController?.isShuffle ?? false,
                                      enabled: widget.playerController != null && indexes.isNotEmpty,
                                      activeColor: colors.primary,
                                      activeBackground: colors.primary.withValues(alpha: 0.12),
                                      onTap: widget.playerController == null || indexes.isEmpty
                                          ? null
                                          : widget.playerController!.toggleShuffle,
                                    ),
                                    const SizedBox(width: 8),
                                    _FavoritesIconAction(
                                      icon: Icons.add_rounded,
                                      enabled: true,
                                      activeColor: colors.onSurface,
                                      activeBackground: colors.surface.withValues(alpha: 0.76),
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
                                          onAddToQueue: globalIndex < 0 || widget.onAddToQueue == null
                                              ? null
                                              : () => widget.onAddToQueue!(globalIndex),
                                          onRenameSong: globalIndex < 0 || widget.onRenameSong == null
                                              ? null
                                              : (name) => widget.onRenameSong!(globalIndex, name),
                                          onDeleteSong: globalIndex < 0 || widget.onDeleteSong == null
                                              ? null
                                              : () => widget.onDeleteSong!(globalIndex),
                                          onPlayPause: globalIndex == currentIndex && widget.playerController != null
                                              ? widget.playerController!.togglePlay
                                              : null,
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
    if (widget.playerController != null) {
      if (playing &&
          widget.playerController!.playbackSourcePlaylistId == widget.playlist.id) {
        await widget.playerController!.togglePlay();
        return;
      }
      // Starting this playlist from another source always begins at song one.
      await widget.playerController!.playSongQueue(
        indexes,
        startPosition: 0,
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

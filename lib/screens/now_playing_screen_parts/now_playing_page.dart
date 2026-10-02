part of '../now_playing_screen.dart';

class NowPlayingPage extends StatefulWidget {
  final Song song;
  final Song? nextSong;
  final String? playlistName;
  final List<Song> playlistSongs;
  final void Function(int oldIndex, int newIndex)? onReorderPlaylist;

  final bool isPlaying;
  final bool isShuffle;

  final player.PlayerRepeatMode repeatMode;

  final double progress;
  final int durationMilliseconds;

  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  final ValueChanged<double>
      onProgressChanged;

  const NowPlayingPage({
    super.key,
    required this.song,
    required this.nextSong,
    this.playlistName,
    this.playlistSongs = const [],
    this.onReorderPlaylist,
    required this.isPlaying,
    required this.isShuffle,
    required this.repeatMode,
    required this.progress,
    required this.durationMilliseconds,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    required this.onProgressChanged,
  });

  @override
  State<NowPlayingPage> createState() =>
      _NowPlayingPageState();
}
class _NowPlayingPageState
    extends State<NowPlayingPage> {

  // ============================================================
  // MUSIC SERVICE
  // ============================================================

  final MusicService _musicService =
      MusicService();

  // ============================================================
  // ARTWORK
  // ============================================================

  Future<Uint8List?>? _artworkFuture;

  Future<Uint8List?>? _nextArtworkFuture;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadArtwork();

    _loadNextArtwork();
  }

  // ============================================================
  // LOAD CURRENT ARTWORK
  // ============================================================

  void _loadArtwork() {
    if (widget.song.uri == null ||
        widget.song.uri!.isEmpty) {
      _artworkFuture =
          Future<Uint8List?>.value(null);

      return;
    }

    final Uint8List? cached =
        _musicService.getCachedArtwork(widget.song);

    if (cached != null && cached.isNotEmpty) {
      _artworkFuture = Future<Uint8List?>.value(cached);
      return;
    }

    _artworkFuture =
        _musicService.getArtwork(
      widget.song,
    );
  }

  // ============================================================
  // LOAD NEXT ARTWORK
  // ============================================================

  void _loadNextArtwork() {
    if (widget.nextSong == null ||
        widget.nextSong!.uri == null ||
        widget.nextSong!.uri!.isEmpty) {
      _nextArtworkFuture =
          Future<Uint8List?>.value(null);

      return;
    }

    final Uint8List? cached =
        _musicService.getCachedArtwork(widget.nextSong!);

    if (cached != null && cached.isNotEmpty) {
      _nextArtworkFuture = Future<Uint8List?>.value(cached);
      return;
    }

    _nextArtworkFuture = _musicService.getArtwork(
      widget.nextSong!,
    );
  }

  // ============================================================
  // UPDATE WIDGET
  // ============================================================

  @override
  void didUpdateWidget(
    covariant NowPlayingPage oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.song.uri !=
        widget.song.uri) {
      _loadArtwork();
    }

    if (oldWidget.nextSong?.uri !=
        widget.nextSong?.uri) {
      _loadNextArtwork();
    }
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String formatDuration(
    int milliseconds,
  ) {
    if (milliseconds <= 0) {
      return '0:00';
    }

    final Duration duration =
        Duration(
      milliseconds:
          milliseconds,
    );

    final int hours =
        duration.inHours;

    final int minutes =
        duration.inMinutes.remainder(60);

    final int seconds =
        duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CURRENT POSITION
  // ============================================================

  String getCurrentPosition() {
    if (widget.durationMilliseconds <= 0) {
      return '0:00';
    }

    final int position =
        (widget.durationMilliseconds *
                widget.progress)
            .round();

    return formatDuration(
      position,
    );
  }


  // ============================================================
  // REPEAT ICON
  // ============================================================

  IconData get repeatIcon {
    if (widget.repeatMode ==
        player.PlayerRepeatMode.one) {
      return Icons.repeat_one_rounded;
    }

    return Icons.repeat_rounded;
  }

  // ============================================================
  // REPEAT LABEL
  // ============================================================

  String get repeatLabel {
    if (widget.repeatMode ==
        player.PlayerRepeatMode.off) {
      return 'Repeat Off';
    }

    if (widget.repeatMode ==
        player.PlayerRepeatMode.all) {
      return 'Repeat All';
    }

    return 'Repeat One';
  }

  // ============================================================
  // PLAYLIST QUEUE SHEET
  // ============================================================

  Future<void> _showPlaylistQueue() async {
    if (widget.playlistSongs.length < 2 ||
        widget.onReorderPlaylist == null) {
      return;
    }

    final items = List<Song>.from(widget.playlistSongs);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.playlistName ?? 'Playlist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Drag songs to change the order',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      physics: const BouncingScrollPhysics(),
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          shadowColor: Colors.transparent,
                          type: MaterialType.transparency,
                          child: child,
                        );
                      },
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final adjustedNewIndex =
                            newIndex > oldIndex ? newIndex + 1 : newIndex;
                        final moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                        setSheetState(() {});
                        widget.onReorderPlaylist?.call(
                          oldIndex,
                          adjustedNewIndex,
                        );
                      },
                      itemBuilder: (context, index) {
                        final song = items[index];
                        return Container(
                          key: ValueKey(song.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.primary.withValues(alpha: 0.10),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: colors.onSurface.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    final Color primary =
        colors.primary;

    final Color textColor =
        colors.onSurface;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title:
            const Text(
          'Now Playing',
        ),
        backgroundColor:
            Colors.transparent,
        elevation: 0,
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child:
            SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              24,
              4,
              24,
              30,
            ),

            child:
                Column(
              children: [

                // ==================================================
                // ALBUM ARTWORK
                // ==================================================

                FutureBuilder<Uint8List?>(
                  future:
                      _artworkFuture,
                  initialData:
                      _musicService.getCachedArtwork(widget.song),

                  builder: (
                    context,
                    snapshot,
                  ) {
                    final Uint8List?
                        artwork =
                        snapshot.data;

                    return FractionallySizedBox(
                      widthFactor: 0.82,
                      child: AspectRatio(
                        aspectRatio: 1,

                        child:
                            ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),

                        child:
                            artwork != null &&
                                    artwork
                                        .isNotEmpty
                                ? Image.memory(
                                    artwork,
                                    fit:
                                        BoxFit.cover,
                                    gaplessPlayback:
                                        true,
                                  )
                                : Container(
                                    decoration:
                                        BoxDecoration(
                                      gradient:
                                          LinearGradient(
                                        begin:
                                            Alignment.topLeft,
                                        end:
                                            Alignment.bottomRight,
                                        colors: [
                                          primary,
                                          colors.secondary,
                                        ],
                                      ),
                                    ),

                                    child:
                                        Center(
                                      child:
                                          const Icon(
                                          Icons.music_note_rounded,
                                          size: 110,
                                          color: Colors.white,
                                        ),
                                    ),
                                  ),
                        ),
                      ),
                    );
                  },
                ),

                // ==================================================
                // TITLE
                // ==================================================

                const SizedBox(
                  height: 20,
                ),

                Text(
                  widget.song.title,

                  textAlign:
                      TextAlign.center,

                  maxLines: 2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      TextStyle(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        textColor,
                  ),
                ),

                if (widget.playlistName != null &&
                    widget.playlistName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: primary.withValues(alpha: 0.16)),
                          ),
                          child: Text(
                            'Playing from · ${widget.playlistName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                      if (widget.playlistSongs.length > 1 &&
                          widget.onReorderPlaylist != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _showPlaylistQueue,
                          icon: Icon(Icons.queue_music_rounded, size: 17, color: primary),
                          label: const Text('Queue'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                            backgroundColor: primary.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // ==================================================
                // WAVEFORM
                // ==================================================

                const SizedBox(
                  height: 18,
                ),

                _WaveProgressBar(
                  progress:
                      widget.progress,

                  activeColor:
                      primary,

                  inactiveColor:
                      textColor.withValues(
                    alpha: 0.12,
                  ),

                  currentTime:
                      getCurrentPosition(),

                  totalTime:
                      formatDuration(
                    widget.durationMilliseconds,
                  ),

                  onChanged:
                      widget.onProgressChanged,
                ),

                // ==================================================
                // PLAYER CONTROLS
                // ==================================================

                const SizedBox(
                  height: 28,
                ),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                  children: [

                    // ----------------------------------------------
                    // SHUFFLE
                    // ----------------------------------------------

                    _PlayerControl(
                      icon:
                          Icons.shuffle_rounded,

                      active:
                          widget.isShuffle,

                      color:
                          primary,

                      tooltip:
                          widget.isShuffle
                              ? 'Shuffle On'
                              : 'Shuffle Off',

                      onTap:
                          widget.onShuffle,
                    ),

                    // ----------------------------------------------
                    // PREVIOUS
                    // ----------------------------------------------

                    _PlayerControl(
                      icon:
                          Icons
                              .skip_previous_rounded,

                      color:
                          textColor,

                      tooltip:
                          'Previous',

                      onTap:
                          widget.onPrevious,

                      iconSize:
                          34,
                    ),

                    // ----------------------------------------------
                    // PLAY / PAUSE
                    // ----------------------------------------------

                    GestureDetector(
                      onTap:
                          widget.onPlayPause,

                      child:
                          Container(
                        width: 70,
                        height: 70,

                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,

                          color:
                              primary,

                          boxShadow: [
                            BoxShadow(
                              color:
                                  primary.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius:
                                  18,
                              spreadRadius:
                                  1,
                            ),
                          ],
                        ),

                        child:
                            Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,

                          size: 38,

                          color:
                              colors.onPrimary,
                        ),
                      ),
                    ),

                    // ----------------------------------------------
                    // NEXT
                    // ----------------------------------------------

                    _PlayerControl(
                      icon:
                          Icons
                              .skip_next_rounded,

                      color:
                          textColor,

                      tooltip:
                          'Next',

                      onTap:
                          widget.onNext,

                      iconSize:
                          34,
                    ),

                    // ----------------------------------------------
                    // REPEAT
                    // ----------------------------------------------

                    _PlayerControl(
                      icon:
                          repeatIcon,

                      active:
                          widget.repeatMode !=
                              player.PlayerRepeatMode.off,

                      color:
                          primary,

                      tooltip:
                          repeatLabel,

                      onTap:
                          widget.onRepeat,
                    ),
                  ],
                ),

                // ==================================================
                // NEXT UP
                // ==================================================

                if (widget.nextSong != null) ...[

                  const SizedBox(
                    height: 30,
                  ),

                  Align(
                    alignment:
                        Alignment.centerLeft,

                    child:
                        Text(
                      'NEXT UP',

                      style:
                          TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        letterSpacing:
                            1.4,
                        color:
                            textColor.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _NextSongGlassCard(
                    song:
                        widget.nextSong!,

                    artworkFuture:
                        _nextArtworkFuture,

                    cachedArtwork:
                        _musicService.getCachedArtwork(widget.nextSong!),

                    primary:
                        primary,

                    textColor:
                        textColor,

                    onTap:
                        widget.onNext,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// WIDGET: WAVEFORM PROGRESS BAR
// ==================================================================

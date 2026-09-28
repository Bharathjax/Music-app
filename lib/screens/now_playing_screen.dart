import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart' as player;
import '../models/song.dart';
import '../services/music_service.dart';

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

class _WaveProgressBar
    extends StatelessWidget {

  final double progress;

  final Color activeColor;
  final Color inactiveColor;

  final String currentTime;
  final String totalTime;

  final ValueChanged<double>
      onChanged;

  const _WaveProgressBar({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.currentTime,
    required this.totalTime,
    required this.onChanged,
  });

  void _updateProgress(
    Offset position,
    double width,
  ) {
    final double value =
        (position.dx / width)
            .clamp(0.0, 1.0);

    onChanged(value);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double width =
            constraints.maxWidth;

        return Column(
          children: [

            GestureDetector(
              behavior:
                  HitTestBehavior.opaque,

              onTapDown: (
                details,
              ) {
                _updateProgress(
                  details.localPosition,
                  width,
                );
              },

              onHorizontalDragUpdate: (
                details,
              ) {
                _updateProgress(
                  details.localPosition,
                  width,
                );
              },

              child:
                  SizedBox(
                width:
                    width,

                height:
                    42,

                child:
                    CustomPaint(
                  painter:
                      _WaveformPainter(
                    progress:
                        progress,
                    activeColor:
                        activeColor,
                    inactiveColor:
                        inactiveColor,
                  ),
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 2,
              ),

              child:
                  Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                children: [

                  Text(
                    currentTime,

                    style:
                        TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                            alpha: 0.55,
                          ),
                    ),
                  ),

                  Text(
                    totalTime,

                    style:
                        TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                            alpha: 0.55,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// PAINTER: WAVEFORM
// ==================================================================

class _WaveformPainter
    extends CustomPainter {

  final double progress;

  final Color activeColor;
  final Color inactiveColor;

  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double width =
        size.width;

    final double centerY =
        size.height / 2;

    const double amplitude =
        6.5;

    const double frequency =
        0.055;

    final double activeWidth =
        width *
            progress.clamp(
              0.0,
              1.0,
            );

    Path createWave(
      double endX,
    ) {
      final Path path =
          Path();

      final int maxX =
          endX.ceil();

      for (
        int x = 0;
        x <= maxX;
        x++
      ) {
        final double dx =
            x.toDouble();

        final double wave =
            centerY +
                amplitude *
                    math.sin(
                      dx * frequency,
                    );

        if (x == 0) {
          path.moveTo(
            dx,
            wave,
          );
        } else {
          path.lineTo(
            dx,
            wave,
          );
        }
      }

      return path;
    }

    // ============================================================
    // INACTIVE WAVE
    // ============================================================

    final Paint inactivePaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round
          ..color =
              inactiveColor;

    canvas.drawPath(
      createWave(width),
      inactivePaint,
    );

    // ============================================================
    // ACTIVE WAVE
    // ============================================================

    if (activeWidth > 0) {
      final Paint activePaint =
          Paint()
            ..style =
                PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap =
                StrokeCap.round
            ..color =
                activeColor;

      canvas.drawPath(
        createWave(
          activeWidth,
        ),
        activePaint,
      );
    }

    // ============================================================
    // THUMB
    // ============================================================

    final double thumbX =
        activeWidth;

    final double thumbY =
        centerY +
            amplitude *
                math.sin(
                  thumbX *
                      frequency,
                );

    // ============================================================
    // THUMB GLOW
    // ============================================================

    final Paint glowPaint =
        Paint()
          ..color =
              activeColor.withValues(
            alpha: 0.20,
          )
          ..maskFilter =
              const MaskFilter.blur(
            BlurStyle.normal,
            5,
          );

    canvas.drawCircle(
      Offset(
        thumbX,
        thumbY,
      ),
      13,
      glowPaint,
    );

    // ============================================================
    // THUMB
    // ============================================================

    final Paint thumbPaint =
        Paint()
          ..color =
              activeColor;

    canvas.drawCircle(
      Offset(
        thumbX,
        thumbY,
      ),
      10,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _WaveformPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.activeColor !=
            activeColor ||
        oldDelegate.inactiveColor !=
            inactiveColor;
  }
}

// ==================================================================
// WIDGET: PLAYER CONTROL
// ==================================================================

class _PlayerControl
    extends StatelessWidget {

  final IconData icon;

  final bool active;

  final Color color;

  final VoidCallback onTap;

  final String? tooltip;

  final double iconSize;

  const _PlayerControl({
    required this.icon,
    this.active = false,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.iconSize = 24,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    final Widget control =
        GestureDetector(
      onTap:
          onTap,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),

        curve:
            Curves.easeOutCubic,

        width: 46,
        height: 46,

        decoration:
            BoxDecoration(
          // Theme-aware active background.
          //
          // Dark mode:
          // onSurface is light.
          //
          // Light mode:
          // onSurface is dark.
          color:
              active
                  ? colors.onSurface
                  : Colors.transparent,

          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),

        child:
            Center(
          child:
              AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 160,
            ),

            transitionBuilder:
                (
              child,
              animation,
            ) {
              return FadeTransition(
                opacity:
                    animation,

                child:
                    ScaleTransition(
                  scale:
                      animation,

                  child:
                      child,
                ),
              );
            },

            child:
                Icon(
              icon,

              key:
                  ValueKey<IconData>(
                icon,
              ),

              size:
                  iconSize,

              color:
                  active
                      ? colors.surface
                      : color.withValues(
                          alpha: 0.65,
                        ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null ||
        tooltip!.isEmpty) {
      return control;
    }

    return Tooltip(
      message:
          tooltip!,

      child:
          control,
    );
  }
}

// ==================================================================
// WIDGET: GLOSSY NEXT SONG CARD
// ==================================================================

class _NextSongGlassCard
    extends StatelessWidget {

  final Song song;

  final Future<Uint8List?>?
      artworkFuture;

  final Uint8List? cachedArtwork;

  final Color primary;

  final Color textColor;

  final VoidCallback onTap;

  const _NextSongGlassCard({
    required this.song,
    required this.artworkFuture,
    required this.cachedArtwork,
    required this.primary,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        22,
      ),

      child:
          BackdropFilter(
        filter:
            ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),

        child:
            Material(
          color:
              Colors.transparent,

          child:
              InkWell(
            onTap:
                onTap,

            borderRadius:
                BorderRadius.circular(
              22,
            ),

            child:
                Container(
              height: 82,

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(
                  alpha: 0.55,
                ),

                borderRadius:
                    BorderRadius.circular(
                  22,
                ),

                border:
                    Border.all(
                  color:
                      textColor.withValues(
                    alpha: 0.10,
                  ),
                  width: 0.8,
                ),

                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(
                      alpha: 0.12,
                    ),

                    blurRadius:
                        18,

                    offset:
                        const Offset(
                      0,
                      7,
                    ),
                  ),
                ],
              ),

              child:
                  Row(
                children: [

                  // =================================================
                  // NEXT ARTWORK
                  // =================================================

                  FutureBuilder<Uint8List?>(
                    future:
                        artworkFuture,
                    initialData:
                        cachedArtwork,

                    builder: (
                      context,
                      snapshot,
                    ) {
                      final Uint8List?
                          artwork =
                          snapshot.data;

                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),

                        child:
                            SizedBox(
                          width: 62,
                          height: 62,

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
                                            primary.withValues(
                                              alpha: 0.45,
                                            ),
                                          ],
                                        ),
                                      ),

                                      child:
                                          Center(
                                        child:
                                            const Icon(
                                            Icons.music_note_rounded,
                                            size: 25,
                                            color: Colors.white,
                                          ),
                                      ),
                                    ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  // =================================================
                  // SONG DETAILS
                  // =================================================

                  Expanded(
                    child:
                        Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          song.title,

                          maxLines: 1,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                textColor,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          song.artist,

                          maxLines: 1,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w500,
                            color:
                                textColor.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // PLAY BUTTON
                  // =================================================

                  Container(
                    width: 46,
                    height: 46,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color:
                          primary.withValues(
                        alpha: 0.13,
                      ),

                      border:
                          Border.all(
                        color:
                            primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),

                    child:
                        Icon(
                      Icons.play_arrow_rounded,

                      size: 27,

                      color:
                          primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

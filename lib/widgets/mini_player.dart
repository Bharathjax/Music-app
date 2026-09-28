import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_service.dart';

class MiniPlayer extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final ValueListenable<double> progressListenable;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.progressListenable,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  State<MiniPlayer> createState() =>
      _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with TickerProviderStateMixin {

  // ============================================================
  // MUSIC SERVICE
  // ============================================================

  final MusicService _musicService =
      MusicService();

  // ============================================================
  // ARTWORK
  // ============================================================

  Future<Uint8List?>? _artworkFuture;

  // ============================================================
  // EQUALIZER
  // ============================================================

  late final AnimationController _animationController;
  late final AnimationController _fadeController;

  // ============================================================
  // FUNCTION: INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadArtwork();

    _animationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 700),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.isPlaying ? 1.0 : 0.0,
    );

    _updateAnimation();
  }

  // ============================================================
  // FUNCTION: LOAD ARTWORK
  // ============================================================

  void _loadArtwork() {
    final String? uri = widget.song.uri;

    if (uri == null || uri.isEmpty) {
      _artworkFuture = Future<Uint8List?>.value(null);
      return;
    }

    // Reuse artwork that the song list has already fetched.
    // This is synchronous and avoids starting another artwork request.
    final Uint8List? cached =
        _musicService.getCachedArtwork(widget.song);

    if (cached != null && cached.isNotEmpty) {
      _artworkFuture = Future<Uint8List?>.value(cached);
      return;
    }

    // Cache miss: use the shared MusicService future. The service
    // deduplicates requests by song URI, so this does not cause a second
    // Android artwork extraction if SongTile is already loading it.
    _artworkFuture = _musicService.getArtwork(widget.song);
  }

  // ============================================================
  // FUNCTION: UPDATE EQUALIZER
  // ============================================================

  void _updateAnimation() {
    if (widget.isPlaying) {
      if (!_animationController.isAnimating) {
        _animationController.repeat();
      }
      _fadeController.forward();
    } else {
      // Stop the equalizer motion and smoothly reveal the artwork.
      _animationController.stop();
      _fadeController.reverse();
    }
  }

  // ============================================================
  // FUNCTION: UPDATE WIDGET
  // ============================================================

  @override
  void didUpdateWidget(
    covariant MiniPlayer oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    // Song changed.
    if (oldWidget.song.uri !=
        widget.song.uri) {
      _loadArtwork();
    }

    // Playback state changed.
    if (oldWidget.isPlaying !=
        widget.isPlaying) {
      _updateAnimation();
    }
  }

  Widget _buildSurface(ColorScheme colors) {
    return Container(
            height: 72,

            decoration: BoxDecoration(
              color: colors.surface
                  .withValues(alpha: 0.58),

              borderRadius:
                  BorderRadius.circular(28),

              border: Border.all(
                color: colors.onSurface
                    .withValues(alpha: 0.18),
                width: 0.8,
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),

            child: Stack(
              children: [

                // ==================================================
                // MAIN CONTENT
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.only(
                    left: 10,
                    right: 8,
                    top: 7,
                    bottom: 7,
                  ),

                  child: Row(
                    children: [

                      // ============================================
                      // ARTWORK
                      // ============================================

                      SizedBox(
                        width: 56,
                        height: 56,

                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(18),

                          child: FutureBuilder<
                              Uint8List?>(
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

                              final bool
                                  hasArtwork =
                                  artwork != null &&
                                  artwork.isNotEmpty;

                              return Stack(
                                fit: StackFit.expand,
                                children: [

                                  // ==================================
                                  // REAL ARTWORK
                                  // ==================================

                                  if (hasArtwork)
                                    Image.memory(
                                      artwork,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  else
                                    Container(
                                      color: colors.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: colors.onSurfaceVariant,
                                        size: 26,
                                      ),
                                    ),

                                  // ==================================
                                  // PLAYING OVERLAY / EQUALIZER
                                  // ==================================

                                  AnimatedBuilder(
                                    animation: _fadeController,
                                    builder: (context, child) {
                                      final opacity = _fadeController.value;
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (hasArtwork)
                                            Container(
                                              color: Colors.black.withValues(
                                                alpha: 0.30 * opacity,
                                              ),
                                            ),
                                          if (opacity > 0.001)
                                            Center(
                                              child: Opacity(
                                                opacity: opacity,
                                                child: RepaintBoundary(
                                                  child: CustomPaint(
                                                    size: const Size(28, 28),
                                                    painter: _MiniEqualizerPainter(
                                                      animation: _animationController,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ============================================
                      // SONG DETAILS
                      // ============================================

                      Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,

                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Text(
                              widget.song.title,

                              maxLines: 1,

                              overflow:
                                  TextOverflow.ellipsis,

                              style: TextStyle(
                                color:
                                    colors.onSurface,

                                fontSize: 14,

                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                          ],
                        ),
                      ),

                      // ============================================
                      // PLAY / PAUSE
                      // ============================================

                      IconButton(
                        onPressed:
                            widget.onPlayPause,

                        tooltip:
                            widget.isPlaying
                                ? 'Pause'
                                : 'Play',

                        padding:
                            EdgeInsets.zero,

                        constraints:
                            const BoxConstraints(
                          minWidth: 42,
                          minHeight: 42,
                        ),

                        icon: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,

                          color:
                              colors.onSurface,

                          size: 27,
                        ),
                      ),

                      // ============================================
                      // NEXT
                      // ============================================

                      IconButton(
                        onPressed:
                            widget.onNext,

                        tooltip:
                            'Next',

                        padding:
                            EdgeInsets.zero,

                        constraints:
                            const BoxConstraints(
                          minWidth: 42,
                          minHeight: 42,
                        ),

                        icon: Icon(
                          Icons.skip_next_rounded,

                          color:
                              colors.onSurface,

                          size: 27,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // MINI PLAYER PROGRESS
                // ==================================================
                // Full-width progress line. Keep this outside the
                // artwork so it remains clearly visible.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: SizedBox(
                      height: 3,
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.progressListenable,
                        builder: (context, progress, _) {
                          return LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: colors.onSurface.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              ],
            ),
          );
  }

  // ============================================================
  // FUNCTION: DISPOSE
  // ============================================================

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ============================================================
  // FUNCTION: BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    return GestureDetector(
      onTap: widget.onTap,

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(28),

        child: _buildSurface(colors),
      ),
    );
  }
}

// ============================================================
// WIDGET: MINI EQUALIZER
// ============================================================

class _MiniEqualizerPainter extends CustomPainter {
  final Animation<double> animation;

  _MiniEqualizerPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final value = animation.value;
    const widths = 4.0;
    const gap = 3.0;
    const barCount = 4;
    const totalWidth = widths * barCount + gap * (barCount - 1);
    final left = (size.width - totalWidth) / 2;

    final heights = <double>[
      0.35 + 0.45 * _wave(value, 0.0),
      0.30 + 0.55 * _wave(value, 1.2),
      0.40 + 0.50 * _wave(value, 2.4),
      0.25 + 0.65 * _wave(value, 3.6),
    ];

    for (var i = 0; i < heights.length; i++) {
      final h = 22 * heights[i];
      final x = left + i * (widths + gap);
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, widths, h),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  double _wave(double value, double offset) {
    final result = (value + offset / 6.0) % 1.0;
    return result < 0.5 ? result * 2 : (1.0 - result) * 2;
  }

  @override
  bool shouldRepaint(covariant _MiniEqualizerPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

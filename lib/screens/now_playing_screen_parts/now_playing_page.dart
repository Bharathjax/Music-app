part of '../now_playing_screen.dart';

class NowPlayingPage extends StatefulWidget {
  final Song song;
  final Song? nextSong;
  final String? playlistName;
  final List<Song> queueSongs;
  final List<int> queueSongIndexes;
  final void Function(int oldIndex, int newIndex)? onReorderQueue;
  final Future<void> Function(int songIndex)? onQueueSongTap;

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
  final ValueChanged<double> onProgressChanged;

  const NowPlayingPage({
    super.key,
    required this.song,
    required this.nextSong,
    this.playlistName,
    this.queueSongs = const [],
    this.queueSongIndexes = const [],
    this.onReorderQueue,
    this.onQueueSongTap,
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
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final MusicService _musicService = MusicService();
  Future<Uint8List?>? _artworkFuture;
  final DraggableScrollableController _queueSheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant NowPlayingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.uri != widget.song.uri) {
      _loadArtwork();
    }
  }

  @override
  void dispose() {
    _queueSheetController.dispose();
    super.dispose();
  }

  double _queueMinSize(int queueLength) => queueLength >= 2 ? 0.24 : 0.13;

  Future<void> _animateQueueSheet(double target) async {
    if (!_queueSheetController.isAttached) return;
    await _queueSheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleQueueSheet(int queueLength) {
    if (!_queueSheetController.isAttached) return;
    final minSize = _queueMinSize(queueLength);
    final midpoint = (minSize + 0.60) / 2;
    final target = _queueSheetController.size < midpoint ? 0.60 : minSize;
    _animateQueueSheet(target);
  }

  void _settleQueueSheet(int queueLength) {
    if (!_queueSheetController.isAttached) return;
    final minSize = _queueMinSize(queueLength);
    final midpoint = (minSize + 0.60) / 2;
    final target = _queueSheetController.size < midpoint ? minSize : 0.60;
    _animateQueueSheet(target);
  }

  void _loadArtwork() {
    if (widget.song.uri == null || widget.song.uri!.isEmpty) {
      _artworkFuture = Future<Uint8List?>.value(null);
      return;
    }

    final cached = _musicService.getCachedArtwork(widget.song);
    if (cached != null && cached.isNotEmpty) {
      _artworkFuture = Future<Uint8List?>.value(cached);
      return;
    }

    _artworkFuture = _musicService.getArtwork(widget.song);
  }

  String formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String getCurrentPosition() {
    if (widget.durationMilliseconds <= 0) return '0:00';
    return formatDuration(
      (widget.durationMilliseconds * widget.progress).round(),
    );
  }

  IconData get repeatIcon =>
      widget.repeatMode == player.PlayerRepeatMode.one
          ? Icons.repeat_one_rounded
          : Icons.repeat_rounded;

  String get repeatLabel {
    switch (widget.repeatMode) {
      case player.PlayerRepeatMode.off:
        return 'Repeat Off';
      case player.PlayerRepeatMode.all:
        return 'Repeat All';
      case player.PlayerRepeatMode.one:
        return 'Repeat One';
    }
  }

  Widget _buildArtwork(Color primary, ColorScheme colors) {
    return FutureBuilder<Uint8List?>(
      future: _artworkFuture,
      initialData: _musicService.getCachedArtwork(widget.song),
      builder: (context, snapshot) {
        final artwork = snapshot.data;
        return FractionallySizedBox(
          widthFactor: 0.82,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: artwork != null && artwork.isNotEmpty
                  ? Image.memory(artwork, fit: BoxFit.cover, gaplessPlayback: true)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primary, colors.secondary],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.music_note_rounded, size: 110, color: Colors.white),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueDrawer(Color primary, Color textColor, ColorScheme colors) {
    final queue = widget.queueSongs;

    return DraggableScrollableSheet(
      controller: _queueSheetController,
      expand: false,
      initialChildSize: 0.265,
      minChildSize: 0.265,
      maxChildSize: 0.60,
      snap: true,
      snapSizes: const [0.265, 0.60],
      builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxHeight >=
                MediaQuery.sizeOf(context).height * 0.42;

            return Material(
              elevation: 18,
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Column(
                      children: [
                        GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleQueueSheet(queue.length),
                      onVerticalDragStart: (_) {},
                      onVerticalDragUpdate: (details) {
                        if (!_queueSheetController.isAttached) return;
                        final minSize = _queueMinSize(queue.length);
                        final maxSize = 0.60;
                        final screenHeight = MediaQuery.sizeOf(context).height;
                        if (screenHeight <= 0) return;
                        final nextSize = _queueSheetController.size -
                            (details.primaryDelta ?? 0) / screenHeight;
                        _queueSheetController.jumpTo(
                          nextSize.clamp(minSize, maxSize),
                        );
                      },
                      onVerticalDragEnd: (_) => _settleQueueSheet(queue.length),
                      child: SizedBox(
                        width: 96,
                        height: 32,
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                        ),
                        const SizedBox(height: 10),
                        if (expanded) ...[
                          Center(
                            child: Text(
                              'PLAYING FROM',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: textColor.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Center(
                            child: Text(
                              widget.playlistName ?? 'All Songs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                                color: primary.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Center(
                            child: Text(
                              widget.song.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.15,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'NEXT IN QUEUE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: textColor.withValues(alpha: 0.62),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          'No more songs',
                          style: TextStyle(color: textColor.withValues(alpha: 0.48)),
                        ),
                      )
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
                        buildDefaultDragHandles: false,
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) {
                          widget.onReorderQueue?.call(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.transparent,
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          return Padding(
                            key: ValueKey('${song.uri ?? song.id}-$index'),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: colors.surfaceContainerHighest.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: widget.onQueueSongTap == null
                                    ? null
                                    : () => widget.onQueueSongTap!(widget.queueSongIndexes[index]),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            if (song.artist.trim().isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                song.artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: textColor.withValues(alpha: 0.52),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      ReorderableDelayedDragStartListener(
                                        index: index,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: textColor.withValues(alpha: 0.42),
                                        ),
                                      ),
                                    ],
                                  ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primary = colors.primary;
    final textColor = colors.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Fixed Now Playing layer. The queue drawer is an overlay and
            // therefore never causes this content to resize or reflow.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
              child: Column(
                children: [
                  _buildArtwork(primary, colors),
                  const SizedBox(height: 18),
                  Text(
                    widget.playlistName == null ? 'Playing From' : 'Playing From',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.52),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.playlistName ?? 'All Songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.song.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _WaveProgressBar(
                    progress: widget.progress,
                    activeColor: primary,
                    inactiveColor: textColor.withValues(alpha: 0.12),
                    currentTime: getCurrentPosition(),
                    totalTime: formatDuration(widget.durationMilliseconds),
                    onChanged: widget.onProgressChanged,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PlayerControl(
                        icon: Icons.shuffle_rounded,
                        active: widget.isShuffle,
                        color: primary,
                        tooltip: widget.isShuffle ? 'Shuffle On' : 'Shuffle Off',
                        onTap: widget.onShuffle,
                      ),
                      _PlayerControl(
                        icon: Icons.skip_previous_rounded,
                        color: textColor,
                        tooltip: 'Previous',
                        onTap: widget.onPrevious,
                        iconSize: 34,
                      ),
                      GestureDetector(
                        onTap: widget.onPlayPause,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.22),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 38,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                      _PlayerControl(
                        icon: Icons.skip_next_rounded,
                        color: textColor,
                        tooltip: 'Next',
                        onTap: widget.onNext,
                        iconSize: 34,
                      ),
                      _PlayerControl(
                        icon: repeatIcon,
                        active: widget.repeatMode != player.PlayerRepeatMode.off,
                        color: primary,
                        tooltip: repeatLabel,
                        onTap: widget.onRepeat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height,
                child: _buildQueueDrawer(primary, textColor, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_service.dart';

class SongTile extends StatefulWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  final MusicService _musicService = MusicService();
  Future<Uint8List?>? _artworkFuture;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  void _loadArtwork() {
    final uri = widget.song.uri;
    _artworkFuture = (uri == null || uri.isEmpty)
        ? Future<Uint8List?>.value(null)
        : _musicService.getArtwork(widget.song);
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.uri != widget.song.uri) {
      _loadArtwork();
    }
  }

  void _showSongMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Row(
                    children: [
                      _Artwork(
                        future: _artworkFuture,
                        initialData: _musicService.getCachedArtwork(widget.song),
                        size: 48,
                        radius: 12,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                  leading: Icon(Icons.queue_music_rounded, color: colors.onSurface),
                  title: const Text('Add to Queue'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                  leading: Icon(
                    widget.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.isFavorite ? colors.primary : colors.onSurface,
                  ),
                  title: Text(widget.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onFavorite();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = widget.isCurrentSong;

    final titleColor = selected ? colors.onSurface : colors.onSurface;
    final artistColor = colors.onSurfaceVariant;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 17 : 14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: selected
                ? Colors.white.withValues(alpha: 0.08)
                : colors.onSurface.withValues(alpha: 0.05),
            highlightColor: selected
                ? Colors.white.withValues(alpha: 0.05)
                : colors.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(selected ? 17 : 14),
            child: Container(
              height: selected ? 58 : 64,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 8 : 4,
                vertical: selected ? 7 : 6,
              ),
              decoration: selected
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          colors.primary.withValues(alpha: 0.13),
                          colors.primary.withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.12),
                        width: 0.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : null,
              child: Row(
                children: [
                  _Artwork(
                    future: _artworkFuture,
                    initialData: _musicService.getCachedArtwork(widget.song),
                    size: selected ? 44 : 52,
                    radius: selected ? 10 : 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: selected ? 13.5 : 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: selected ? 10.5 : 11.5,
                            fontWeight: FontWeight.w500,
                            color: artistColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'More options',
                    onPressed: _showSongMenu,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 38, height: 42),
                    splashRadius: 18,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 21,
                      color: colors.onSurfaceVariant.withValues(alpha: selected ? 0.78 : 1.0),
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

class _Artwork extends StatelessWidget {
  final Future<Uint8List?>? future;
  final Uint8List? initialData;
  final double size;
  final double radius;

  const _Artwork({
    required this.future,
    this.initialData,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: future,
          initialData: initialData,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data != null && data.isNotEmpty) {
              return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
            }
            return Container(
              color: colors.onSurface.withValues(alpha: 0.07),
              child: Icon(
                Icons.music_note_rounded,
                size: size * 0.42,
                color: colors.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );
  }
}

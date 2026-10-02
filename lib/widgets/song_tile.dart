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

  final VoidCallback? onPlayPause;

  final VoidCallback? onAddToQueue;

  final Future<bool> Function(String newName)? onRenameSong;

  final Future<bool> Function()? onDeleteSong;



  const SongTile({

    super.key,

    required this.song,

    required this.isCurrentSong,

    required this.isPlaying,

    required this.isFavorite,

    required this.onTap,

    required this.onFavorite,

    this.onPlayPause,

    this.onAddToQueue,

    this.onRenameSong,

    this.onDeleteSong,

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



  Future<void> _changeArtwork() async {

    Navigator.pop(context);



    final bytes = await _musicService.pickCustomArtwork(widget.song);



    if (!mounted) return;



    if (bytes != null) {

      setState(() {

        _artworkFuture = Future<Uint8List?>.value(bytes);

      });



      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Artwork embedded into song'),

        ),

      );

    }

  }



  Future<void> _removeArtwork() async {

    Navigator.pop(context);



    await _musicService.removeCustomArtwork(widget.song);



    if (!mounted) return;



    setState(_loadArtwork);



    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(

        content: Text('Embedded artwork removed'),

      ),

    );

  }



  Future<void> _renameSong() async {

    if (widget.onRenameSong == null) return;



    final newName = await showDialog<String>(

      context: context,

      builder: (dialogContext) {

        return _RenameSongDialog(

          initialName: widget.song.title,

        );

      },

    );



    if (newName == null || newName.trim().isEmpty) {

      return;

    }



    if (!mounted) return;
    final ok = await widget.onRenameSong!(newName.trim());



    if (!mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          ok

              ? 'Song renamed successfully'

              : 'Could not rename song',

        ),

      ),

    );

  }



  Future<void> _deleteSong() async {

    if (widget.onDeleteSong == null) return;



    final confirmed = await showDialog<bool>(

          context: context,

          builder: (dialogContext) => AlertDialog(

            title: const Text('Delete Song?'),

            content: Text(

              'This will delete "${widget.song.title}" from your device.',

            ),

            actions: [

              TextButton(

                onPressed: () {

                  Navigator.of(dialogContext).pop(false);

                },

                child: const Text('Cancel'),

              ),

              FilledButton(

                style: FilledButton.styleFrom(

                  backgroundColor:

                      Theme.of(dialogContext).colorScheme.error,

                ),

                onPressed: () {

                  Navigator.of(dialogContext).pop(true);

                },

                child: const Text('Delete'),

              ),

            ],

          ),

        ) ??

        false;



    if (!confirmed || !mounted) return;



    Navigator.of(context).pop();



    final ok = await widget.onDeleteSong!();



    if (!mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          ok ? 'Song deleted' : 'Could not delete song',

        ),

      ),

    );

  }



  Future<void> _showSongMenu() async {
    final action = await showModalBottomSheet<String>(

      context: context,

      backgroundColor: Colors.transparent,

      builder: (sheetContext) {

        final theme = Theme.of(sheetContext);

        final colors = theme.colorScheme;



        return Container(

          decoration: BoxDecoration(

            color: colors.surface,

            borderRadius: const BorderRadius.vertical(

              top: Radius.circular(28),

            ),

          ),

          padding: const EdgeInsets.only(

            top: 12,

            bottom: 24,

          ),

          child: SafeArea(

            top: false,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  width: 40,

                  height: 4,

                  margin: const EdgeInsets.only(

                    bottom: 16,

                  ),

                  decoration: BoxDecoration(

                    color: colors.onSurface.withValues(

                      alpha: 0.18,

                    ),

                    borderRadius: BorderRadius.circular(10),

                  ),

                ),



                // ==================================================

                // SONG HEADER

                // ==================================================



                Padding(

                  padding: const EdgeInsets.symmetric(

                    horizontal: 22,

                    vertical: 8,

                  ),

                  child: Row(

                    children: [

                      _Artwork(

                        future: _artworkFuture,

                        initialData:

                            _musicService.getCachedArtwork(widget.song),

                        size: 48,

                        radius: 12,

                      ),

                      const SizedBox(width: 14),

                      Expanded(

                        child: Column(

                          crossAxisAlignment:

                              CrossAxisAlignment.start,

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



                // ==================================================

                // ADD TO QUEUE

                // ==================================================



                ListTile(

                  contentPadding: const EdgeInsets.symmetric(

                    horizontal: 22,

                  ),

                  leading: Icon(

                    Icons.queue_music_rounded,

                    color: colors.onSurface,

                  ),

                  title: const Text('Add to Queue'),

                  onTap: () {

                    Navigator.pop(sheetContext);

                    widget.onAddToQueue?.call();

                  },

                ),



                // ==================================================

                // RENAME SONG

                // ==================================================



                ListTile(

                  contentPadding: const EdgeInsets.symmetric(

                    horizontal: 22,

                  ),

                  leading: Icon(

                    Icons.drive_file_rename_outline_rounded,

                    color: colors.onSurface,

                  ),

                  title: const Text('Rename Song'),

                                    onTap: widget.onRenameSong == null
                      ? null
                      : () {
                          Navigator.pop(sheetContext, 'rename');
                        },

                ),



                // ==================================================

                // DELETE SONG

                // ==================================================



                ListTile(

                  contentPadding: const EdgeInsets.symmetric(

                    horizontal: 22,

                  ),

                  leading: Icon(

                    Icons.delete_outline_rounded,

                    color: colors.error,

                  ),

                  title: Text(

                    'Delete Song',

                    style: TextStyle(

                      color: colors.error,

                    ),

                  ),

                  onTap: widget.onDeleteSong == null

                      ? null

                      : _deleteSong,

                ),



                // ==================================================

                // FAVORITE

                // ==================================================



                ListTile(

                  contentPadding: const EdgeInsets.symmetric(

                    horizontal: 22,

                  ),

                  leading: Icon(

                    widget.isFavorite

                        ? Icons.favorite_rounded

                        : Icons.favorite_border_rounded,

                    color: widget.isFavorite

                        ? colors.primary

                        : colors.onSurface,

                  ),

                  title: Text(

                    widget.isFavorite

                        ? 'Remove from Favorites'

                        : 'Add to Favorites',

                  ),

                  onTap: () {

                    Navigator.pop(sheetContext);

                    widget.onFavorite();

                  },

                ),



                // ==================================================

                // ARTWORK

                // ==================================================



                FutureBuilder<bool>(

                  future: _musicService.hasCustomArtwork(

                    widget.song,

                  ),

                  builder: (context, snapshot) {

                    final hasCustom =

                        snapshot.data ?? false;



                    return Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        ListTile(

                          contentPadding:

                              const EdgeInsets.symmetric(

                            horizontal: 22,

                          ),

                          leading: Icon(

                            Icons.image_rounded,

                            color: colors.onSurface,

                          ),

                          title: Text(

                            hasCustom

                                ? 'Change Artwork'

                                : 'Add Artwork',

                          ),

                          subtitle: const Text(

                            'Crop, zoom and position the image',

                          ),

                          onTap: _changeArtwork,

                        ),

                        if (hasCustom)

                          ListTile(

                            contentPadding:

                                const EdgeInsets.symmetric(

                              horizontal: 22,

                            ),

                            leading: Icon(

                              Icons.hide_image_rounded,

                              color: colors.onSurface,

                            ),

                            title: const Text(

                              'Remove Artwork',

                            ),

                            onTap: _removeArtwork,

                          ),

                      ],

                    );

                  },

                ),

              ],

            ),

          ),

        );

      },

    );

    // The route Future completes after the sheet's reverse animation.
    // Only then create the dialog, preventing competing transitions.
    if (action == 'rename' && mounted) {
      await _renameSong();
    }
  }

  @override
  Widget build(BuildContext context) {


    final colors = Theme.of(context).colorScheme;

    final selected = widget.isCurrentSong;



    final titleColor = selected

        ? colors.onSurface

        : colors.onSurface;



    final artistColor = colors.onSurfaceVariant;



    return RepaintBoundary(

      child: Padding(

        padding: const EdgeInsets.only(

          bottom: 5,

        ),

        child: Material(

          color: Colors.transparent,

          borderRadius: BorderRadius.circular(

            selected ? 17 : 14,

          ),

          clipBehavior: Clip.antiAlias,

          child: InkWell(

            onTap: widget.onTap,

            splashColor: selected

                ? Colors.white.withValues(

                    alpha: 0.08,

                  )

                : colors.onSurface.withValues(

                    alpha: 0.05,

                  ),

            highlightColor: selected

                ? Colors.white.withValues(

                    alpha: 0.05,

                  )

                : colors.onSurface.withValues(

                    alpha: 0.03,

                  ),

            borderRadius: BorderRadius.circular(

              selected ? 17 : 14,

            ),

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

                          colors.primary.withValues(

                            alpha: 0.13,

                          ),

                          colors.primary.withValues(

                            alpha: 0.07,

                          ),

                          Colors.transparent,

                        ],

                        stops: const [

                          0.0,

                          0.45,

                          1.0,

                        ],

                      ),

                      borderRadius: BorderRadius.circular(

                        15,

                      ),

                      border: Border.all(

                        color: colors.primary.withValues(

                          alpha: 0.12,

                        ),

                        width: 0.7,

                      ),

                      boxShadow: [

                        BoxShadow(

                          color: colors.primary.withValues(

                            alpha: 0.07,

                          ),

                          blurRadius: 10,

                          offset: const Offset(

                            0,

                            3,

                          ),

                        ),

                      ],

                    )

                  : null,

              child: Row(

                children: [

                  _Artwork(

                    future: _artworkFuture,

                    initialData:

                        _musicService.getCachedArtwork(

                      widget.song,

                    ),

                    size: selected ? 44 : 52,

                    radius: selected ? 10 : 11,

                  ),



                  const SizedBox(width: 12),



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

                            fontSize:

                                selected ? 13.5 : 14.5,

                            fontWeight:

                                FontWeight.w600,

                            letterSpacing: -0.2,

                            color: titleColor,

                          ),

                        ),

                        const SizedBox(height: 3),

                        Text(

                          widget.song.artist,

                          maxLines: 1,

                          overflow:

                              TextOverflow.ellipsis,

                          style: TextStyle(

                            fontSize:

                                selected ? 10.5 : 11.5,

                            fontWeight:

                                FontWeight.w500,

                            color: artistColor,

                          ),

                        ),

                      ],

                    ),

                  ),



                  const SizedBox(width: 4),



                  SizedBox(

                    width: 38,

                    height: 42,

                    child: AnimatedSwitcher(

                      duration: const Duration(

                        milliseconds: 180,

                      ),

                      switchInCurve:

                          Curves.easeOut,

                      switchOutCurve:

                          Curves.easeIn,

                      transitionBuilder:

                          (child, animation) {

                        return FadeTransition(

                          opacity: animation,

                          child: child,

                        );

                      },

                      child: selected &&

                              widget.onPlayPause !=

                                  null

                          ? IconButton(

                              key: ValueKey(

                                widget.isPlaying,

                              ),

                              tooltip: widget.isPlaying

                                  ? 'Pause'

                                  : 'Play',

                              onPressed:

                                  widget.onPlayPause,

                              padding: EdgeInsets.zero,

                              constraints:

                                  const BoxConstraints

                                      .tightFor(

                                width: 38,

                                height: 42,

                              ),

                              splashRadius: 18,

                              icon: Icon(

                                widget.isPlaying

                                    ? Icons

                                        .pause_rounded

                                    : Icons

                                        .play_arrow_rounded,

                                size: 21,

                                color:

                                    colors.onSurface,

                              ),

                            )

                          : const SizedBox.shrink(

                              key: ValueKey(

                                'no-play-pause',

                              ),

                            ),

                    ),

                  ),



                  IconButton(

                    tooltip: 'More options',

                    onPressed: _showSongMenu,

                    padding: EdgeInsets.zero,

                    constraints:

                        const BoxConstraints.tightFor(

                      width: 38,

                      height: 42,

                    ),

                    splashRadius: 18,

                    icon: Icon(

                      Icons.more_horiz_rounded,

                      size: 21,

                      color: colors.onSurfaceVariant

                          .withValues(

                        alpha:

                            selected ? 0.78 : 1.0,

                      ),

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



// ================================================================

// RENAME SONG DIALOG

// ================================================================



class _RenameSongDialog extends StatefulWidget {
  final String initialName;

  const _RenameSongDialog({
    required this.initialName,
  });

  @override
  State<_RenameSongDialog> createState() => _RenameSongDialogState();
}

class _RenameSongDialogState extends State<_RenameSongDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialName,
    );

    _focusNode = FocusNode();

    // Let the dialog finish its first layout before opening the keyboard.
    // This avoids competing with the dialog/window transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _focusNode.requestFocus();

      final text = _controller.text;
      final dot = text.lastIndexOf('.');

      if (dot > 0) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: dot,
        );
      } else {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    _focusNode.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Song'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'New file name',
        ),
        onSubmitted: (_) {
          _rename();
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            _focusNode.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _rename,
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

// ================================================================

// ARTWORK

// ================================================================



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

    final colors =

        Theme.of(context).colorScheme;



    return ClipRRect(

      borderRadius:

          BorderRadius.circular(radius),

      child: SizedBox(

        width: size,

        height: size,

        child: FutureBuilder<Uint8List?>(

          future: future,

          initialData: initialData,

          builder: (

            context,

            snapshot,

          ) {

            final data = snapshot.data;



            if (data != null &&

                data.isNotEmpty) {

              return Image.memory(

                data,

                fit: BoxFit.cover,

                gaplessPlayback: true,

              );

            }



            return Container(

              color: colors.onSurface.withValues(

                alpha: 0.07,

              ),

              child: Icon(

                Icons.music_note_rounded,

                size: size * 0.42,

                color:

                    colors.onSurfaceVariant,

              ),

            );

          },

        ),

      ),

    );

  }

}
part of '../now_playing_screen.dart';

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

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../widgets/song_tile.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Song> songs;
  final int currentSongIndex;
  final bool isPlaying;
  final Set<int> favoriteSongs;
  final Function(int) onSongSelected;
  final Function(int) onFavorite;

  const FavoritesScreen({
    super.key,
    required this.songs,
    required this.currentSongIndex,
    required this.isPlaying,
    required this.favoriteSongs,
    required this.onSongSelected,
    required this.onFavorite,
  });

  // ==========================================================
  // FUNCTION: BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    final List<int> favoriteIndexes =
        favoriteSongs.toList();

    // ========================================================
    // EMPTY FAVORITES
    // ========================================================

    if (favoriteIndexes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [

            // ==================================================
            // FAVORITE ICON
            // ==================================================

            Icon(
              Icons.favorite_border_rounded,

              size: 55,

              color:
                  colors.onSurfaceVariant,
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // EMPTY MESSAGE
            // ==================================================

            Text(
              'No favorite songs yet',

              style: TextStyle(
                fontSize: 16,

                color:
                    colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            // ==================================================
            // HELPER TEXT
            // ==================================================

            Text(
              'Tap the heart icon on a song to add it here.',

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                fontSize: 13,

                color:
                    colors.onSurfaceVariant
                        .withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ========================================================
    // FAVORITES LIST
    // ========================================================

    return ListView.builder(
      physics:
          const BouncingScrollPhysics(),

      itemCount:
          favoriteIndexes.length,

      itemBuilder: (
        context,
        position,
      ) {
        final int songIndex =
            favoriteIndexes[position];

        final Song song =
            songs[songIndex];

        return SongTile(
          song: song,

          isCurrentSong:
              songIndex ==
                  currentSongIndex,

          isPlaying:
              isPlaying,

          isFavorite: true,

          onTap: () {
            onSongSelected(
              songIndex,
            );
          },

          onFavorite: () {
            onFavorite(
              songIndex,
            );
          },
        );
      },
    );
  }
}
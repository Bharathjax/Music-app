import 'package:flutter/material.dart';

import '../models/song.dart';

class MusicSearchDelegate extends SearchDelegate<Song?> {
  final List<Song> songs;
  final Function(int) onSongSelected;

  MusicSearchDelegate({
    required this.songs,
    required this.onSongSelected,
  });

  // ==========================================================
  // FUNCTION: BUILD ACTIONS
  // ==========================================================

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(
            Icons.clear_rounded,
          ),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  // ==========================================================
  // FUNCTION: BUILD LEADING
  // ==========================================================

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      icon: const Icon(
        Icons.arrow_back_rounded,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  // ==========================================================
  // FUNCTION: BUILD RESULTS
  // ==========================================================

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return _buildSongList();
  }

  // ==========================================================
  // FUNCTION: BUILD SUGGESTIONS
  // ==========================================================

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _buildSongList();
  }

  // ==========================================================
  // FUNCTION: BUILD SONG LIST
  // ==========================================================

  Widget _buildSongList() {
    final String searchText =
        query.toLowerCase().trim();

    final List<int> matchingIndexes = [];

    for (int i = 0; i < songs.length; i++) {
      final Song song = songs[i];

      final bool matchesTitle =
          song.title
              .toLowerCase()
              .contains(searchText);

      final bool matchesArtist =
          song.artist
              .toLowerCase()
              .contains(searchText);

      if (searchText.isEmpty ||
          matchesTitle ||
          matchesArtist) {
        matchingIndexes.add(i);
      }
    }

    if (matchingIndexes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 50,
            ),
            SizedBox(height: 12),
            Text(
              'No songs found',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: matchingIndexes.length,
      itemBuilder: (
        context,
        position,
      ) {
        final int songIndex =
            matchingIndexes[position];

        final Song song =
            songs[songIndex];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 4,
          ),

          leading: const CircleAvatar(
            child: Icon(
              Icons.music_note_rounded,
            ),
          ),

          title: Text(
            song.title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
          ),

          onTap: () {
            onSongSelected(
              songIndex,
            );

            close(
              context,
              song,
            );
          },
        );
      },
    );
  }
}
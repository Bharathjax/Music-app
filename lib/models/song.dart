class Song {
  // ==========================================================
  // SONG INFORMATION
  // ==========================================================

  final String title;
  final String artist;

  // Android MediaStore ID.
  final int? id;

  // Album name.
  final String? album;

  // Song duration in milliseconds.
  final int? duration;

  // Android MediaStore URI used for playback.
  final String? uri;

  const Song({
    required this.title,
    required this.artist,
    this.id,
    this.album,
    this.duration,
    this.uri,
  });
}
part of '../home_screen.dart';

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: colors.onSurface,
        ),
      ),
    );
  }
}
class _SongRow extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onPlayPause;
  final VoidCallback? onAddToQueue;
  final Future<bool> Function(String)? onRenameSong;
  final Future<bool> Function()? onDeleteSong;

  const _SongRow({
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
  Widget build(BuildContext context) {
    return SongTile(
      song: song,
      isCurrentSong: isCurrentSong,
      isPlaying: isPlaying,
      isFavorite: isFavorite,
      onTap: onTap,
      onFavorite: onFavorite,
      onPlayPause: isCurrentSong ? onPlayPause : null,
      onAddToQueue: onAddToQueue,
      onRenameSong: onRenameSong,
      onDeleteSong: onDeleteSong,
    );
  }
}

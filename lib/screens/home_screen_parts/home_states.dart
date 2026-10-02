part of '../home_screen.dart';

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading your music…',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
class _PermissionState extends StatelessWidget {
  const _PermissionState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.folder_off_rounded, size: 32, color: colors.onSurface.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text('Music permission is required', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
          const SizedBox(height: 5),
          Text('Allow access to your device music to build your library.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.4, color: colors.onSurface.withValues(alpha: 0.52))),
        ],
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const _icon = Icons.music_off_rounded;
  static const _title = 'No music found';
  static const _subtitle = 'Add music to your device to build your library.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Icon(
            _icon,
            size: 32,
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: colors.onSurface.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

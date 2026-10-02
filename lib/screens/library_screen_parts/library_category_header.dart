part of '../library_screen.dart';

class _CategoryHeader extends StatelessWidget {
  final String title;
  final bool showAdd;
  final VoidCallback? onAdd;
  final VoidCallback? onBack;

  const _CategoryHeader({
    required this.title,
    required this.showAdd,
    this.onAdd,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
            ),
          ),
          if (showAdd)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 28),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

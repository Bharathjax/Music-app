import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback onSearch;

  const AppHeader({
    super.key,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, Bharath! 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSearch,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  Icons.search_rounded,
                  size: 25,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}

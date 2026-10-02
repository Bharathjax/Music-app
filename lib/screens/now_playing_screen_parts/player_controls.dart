part of '../now_playing_screen.dart';

class _PlayerControl
    extends StatelessWidget {

  final IconData icon;

  final bool active;

  final Color color;

  final VoidCallback onTap;

  final String? tooltip;

  final double iconSize;

  const _PlayerControl({
    required this.icon,
    this.active = false,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.iconSize = 24,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    final Widget control =
        GestureDetector(
      onTap:
          onTap,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),

        curve:
            Curves.easeOutCubic,

        width: 46,
        height: 46,

        decoration:
            BoxDecoration(
          // Theme-aware active background.
          //
          // Dark mode:
          // onSurface is light.
          //
          // Light mode:
          // onSurface is dark.
          color:
              active
                  ? colors.onSurface
                  : Colors.transparent,

          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),

        child:
            Center(
          child:
              AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 160,
            ),

            transitionBuilder:
                (
              child,
              animation,
            ) {
              return FadeTransition(
                opacity:
                    animation,

                child:
                    ScaleTransition(
                  scale:
                      animation,

                  child:
                      child,
                ),
              );
            },

            child:
                Icon(
              icon,

              key:
                  ValueKey<IconData>(
                icon,
              ),

              size:
                  iconSize,

              color:
                  active
                      ? colors.surface
                      : color.withValues(
                          alpha: 0.65,
                        ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null ||
        tooltip!.isEmpty) {
      return control;
    }

    return Tooltip(
      message:
          tooltip!,

      child:
          control,
    );
  }
}

// ==================================================================
// WIDGET: GLOSSY NEXT SONG CARD
// ==================================================================

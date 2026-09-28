import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // SETTINGS CONTENT
      // ========================================================

      body: ListView(
        physics: const BouncingScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          30,
        ),

        children: [

          // ======================================================
          // GENERAL SECTION
          // ======================================================

          _sectionTitle(
            context,
            'General',
          ),

          _settingCard(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: _appearanceName(),
            onTap: () {
              _showAppearanceMenu(context);
            },
          ),

          const SizedBox(
            height: 24,
          ),

          // ======================================================
          // AUDIO SECTION
          // ======================================================

          _sectionTitle(
            context,
            'Audio',
          ),

          _settingCard(
            context: context,
            icon: Icons.music_note_rounded,
            title: 'Audio',
            subtitle: 'Playback and audio settings',
            onTap: () {
              _showAudioMessage(context);
            },
          ),

          const SizedBox(
            height: 24,
          ),

          // ======================================================
          // ABOUT SECTION
          // ======================================================

          _sectionTitle(
            context,
            'About',
          ),

          _settingCard(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'About Music Player',
            subtitle: 'Version 1.0.0',
            onTap: () {
              _showAbout(context);
            },
          ),

          const SizedBox(
            height: 30,
          ),

          // ======================================================
          // VERSION
          // ======================================================

          Center(
            child: Text(
              'Music Player • Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FUNCTION: APPEARANCE NAME
  // ============================================================

  String _appearanceName() {
    switch (currentThemeMode) {
      case ThemeMode.light:
        return 'Light mode';

      case ThemeMode.system:
        return 'System default';

      case ThemeMode.dark:
        return 'Dark mode';
    }
  }

  // ============================================================
  // FUNCTION: SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 10,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  // ============================================================
  // FUNCTION: SETTING CARD
  // ============================================================

  Widget _settingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    return Material(
      color: colors.surface,

      borderRadius:
          BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(18),

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Row(
            children: [

              // ==================================================
              // ICON
              // ==================================================

              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: 0.10),

                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: Icon(
                  icon,
                  size: 24,
                  color: colors.primary,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // ==================================================
              // TITLE + SUBTITLE
              // ==================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      title,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            colors.onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      subtitle,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              // ==================================================
              // ARROW
              // ==================================================

              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color:
                    colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FUNCTION: SHOW APPEARANCE MENU
  // ============================================================

  void _showAppearanceMenu(
    BuildContext context,
  ) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,

      backgroundColor:
          colors.surface,

      isScrollControlled:
          false,

      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                // ================================================
                // DRAG HANDLE
                // ================================================

                Container(
                  width: 42,
                  height: 4,

                  decoration: BoxDecoration(
                    color: colors.onSurface
                        .withValues(alpha: 0.20),

                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // ================================================
                // TITLE
                // ================================================

                Align(
                  alignment:
                      Alignment.centerLeft,

                  child: Text(
                    'Appearance',

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          colors.onSurface,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Align(
                  alignment:
                      Alignment.centerLeft,

                  child: Text(
                    'Choose how the app looks',

                    style: TextStyle(
                      fontSize: 13,
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // ================================================
                // DARK MODE
                // ================================================

                _themeOption(
                  context,
                  icon:
                      Icons.dark_mode_outlined,
                  title:
                      'Dark mode',
                  subtitle:
                      'Use a dark interface',
                  mode:
                      ThemeMode.dark,
                ),

                const SizedBox(
                  height: 10,
                ),

                // ================================================
                // LIGHT MODE
                // ================================================

                _themeOption(
                  context,
                  icon:
                      Icons.light_mode_outlined,
                  title:
                      'Light mode',
                  subtitle:
                      'Use a light interface',
                  mode:
                      ThemeMode.light,
                ),

                const SizedBox(
                  height: 10,
                ),

                // ================================================
                // SYSTEM DEFAULT
                // ================================================

                _themeOption(
                  context,
                  icon:
                      Icons.brightness_auto_outlined,
                  title:
                      'System default',
                  subtitle:
                      'Follow your device appearance',
                  mode:
                      ThemeMode.system,
                ),

                const SizedBox(
                  height: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FUNCTION: THEME OPTION
  // ============================================================

  Widget _themeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeMode mode,
  }) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    final bool selected =
        currentThemeMode == mode;

    return Material(
      color: selected
          ? colors.primary.withValues(
              alpha: 0.10,
            )
          : colors.onSurface.withValues(
              alpha: 0.04,
            ),

      borderRadius:
          BorderRadius.circular(17),

      child: InkWell(
        onTap: () {
          onThemeChanged(mode);

          Navigator.pop(context);
        },

        borderRadius:
            BorderRadius.circular(17),

        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),

          child: Row(
            children: [

              // ================================================
              // ICON
              // ================================================

              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary
                          .withValues(
                          alpha: 0.12,
                        )
                      : colors.onSurface
                          .withValues(
                          alpha: 0.06,
                        ),

                  borderRadius:
                      BorderRadius.circular(12),
                ),

                child: Icon(
                  icon,

                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              // ================================================
              // TEXT
              // ================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      title,

                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color:
                            colors.onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,

                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // ================================================
              // CHECK ICON
              // ================================================

              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color:
                      colors.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FUNCTION: SHOW AUDIO MESSAGE
  // ============================================================

  void _showAudioMessage(
    BuildContext context,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Audio settings will be added later.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // FUNCTION: SHOW ABOUT
  // ============================================================

  void _showAbout(
    BuildContext context,
  ) {
    showAboutDialog(
      context: context,

      applicationName:
          'Music Player',

      applicationVersion:
          '1.0.0',

      applicationLegalese:
          'A Flutter music player application.',
    );
  }
}
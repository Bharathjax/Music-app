import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/music_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved appearance from Android.
  const MethodChannel channel =
      MethodChannel('music_player/device_music');

  ThemeMode initialThemeMode =
      ThemeMode.dark;

  try {
    final String savedAppearance =
        await channel.invokeMethod<String>(
              'getAppearance',
            ) ??
            'dark';

    switch (savedAppearance) {
      case 'light':
        initialThemeMode =
            ThemeMode.light;
        break;

      case 'system':
        initialThemeMode =
            ThemeMode.system;
        break;

      case 'dark':
      default:
        initialThemeMode =
            ThemeMode.dark;
        break;
    }
  } catch (e) {
    debugPrint(
      'Could not load appearance: $e',
    );
  }

  runApp(
    MusicPlayerApp(
      initialThemeMode:
          initialThemeMode,
    ),
  );
}

class MusicPlayerApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MusicPlayerApp({
    super.key,
    required this.initialThemeMode,
  });

  @override
  State<MusicPlayerApp> createState() =>
      _MusicPlayerAppState();
}

class _MusicPlayerAppState
    extends State<MusicPlayerApp> {

  late ThemeMode themeMode;

  static const MethodChannel channel =
      MethodChannel('music_player/device_music');

  @override
  void initState() {
    super.initState();

    themeMode =
        widget.initialThemeMode;
  }

  // FUNCTION: Change and save appearance.
  Future<void> changeTheme(
    ThemeMode mode,
  ) async {

    setState(() {
      themeMode = mode;
    });

    String appearance;

    switch (mode) {

      case ThemeMode.light:
        appearance = 'light';
        break;

      case ThemeMode.system:
        appearance = 'system';
        break;

      case ThemeMode.dark:
        appearance = 'dark';
        break;
    }

    try {

      await channel.invokeMethod(
        'saveAppearance',
        {
          'appearance': appearance,
        },
      );

    } catch (e) {

      debugPrint(
        'Could not save appearance: $e',
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Music Player',

      // ===========================================================
      // DARK THEME — Midnight Indigo
      // ===========================================================

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Inter',

        scaffoldBackgroundColor:
            const Color(0xFF111214),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9B8CFF),
          onPrimary: Color(0xFF17151F),
          primaryContainer: Color(0xFF302B42),
          onPrimaryContainer: Color(0xFFF0ECFF),
          secondary: Color(0xFFFF7187),
          onSecondary: Color(0xFF2A0F15),
          secondaryContainer: Color(0xFF40232B),
          onSecondaryContainer: Color(0xFFFFDDE3),
          surface: Color(0xFF18191C),
          surfaceContainerHighest: Color(0xFF202126),
          onSurface: Color(0xFFF2F2F3),
          onSurfaceVariant: Color(0xFFA6A7AD),
          outline: Color(0xFF2A2B30),
          outlineVariant: Color(0xFF292A30),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        cardTheme: CardThemeData(
          color: const Color(0xFF18191C),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF202126),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF8B7CFF),
              width: 1.2,
            ),
          ),
        ),

        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF141518),
          indicatorColor: Color(0xFF302B42),
          surfaceTintColor: Colors.transparent,
        ),

        dividerTheme: const DividerThemeData(
          color: Color(0xFF202126),
          thickness: 1,
          space: 1,
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF202126),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // ===========================================================
      // LIGHT THEME — Soft Cloud
      // ===========================================================

      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Inter',

        scaffoldBackgroundColor:
            const Color(0xFFF5F7FB),

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5750D9),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE9E7FF),
          onPrimaryContainer: Color(0xFF17134A),
          secondary: Color(0xFF078F86),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFD5F5F1),
          onSecondaryContainer: Color(0xFF00201D),
          surface: Colors.white,
          surfaceContainerHighest: Color(0xFFE9EDF4),
          onSurface: Color(0xFF17191F),
          onSurfaceVariant: Color(0xFF626A78),
          outline: Color(0xFFB9C0CC),
          outlineVariant: Color(0xFFD9DEE7),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEDF0F5),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF5750D9),
              width: 1.2,
            ),
          ),
        ),

        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFE9E7FF),
          surfaceTintColor: Colors.transparent,
        ),

        dividerTheme: const DividerThemeData(
          color: Color(0xFFDDE2EA),
          thickness: 1,
          space: 1,
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // ===========================================================
      // CURRENT THEME
      // ===========================================================

      themeMode: themeMode,

      home: MusicHomePage(
        onThemeChanged:
            changeTheme,
        currentThemeMode:
            themeMode,
      ),
    );
  }
}
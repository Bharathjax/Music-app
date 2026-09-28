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
      // DARK THEME
      // ===========================================================

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Inter',

        scaffoldBackgroundColor:
            const Color(0xFF09090F),

        colorScheme:
            const ColorScheme.dark(
          primary:
              Color(0xFF7C4DFF),
          secondary:
              Color(0xFF536DFE),
          surface:
              Color(0xFF12121A),
          surfaceContainerHighest:
              Color(0xFF20202B),
        ),

        appBarTheme:
            const AppBarTheme(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),

        navigationBarTheme:
            const NavigationBarThemeData(
          backgroundColor:
              Color(0xFF11111A),
          indicatorColor:
              Color(0xFF30205C),
        ),
      ),

      // ===========================================================
      // LIGHT THEME
      // ===========================================================

      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Inter',

        scaffoldBackgroundColor:
            const Color(0xFFF7F7FA),

        colorScheme:
            const ColorScheme.light(
          primary:
              Color(0xFF5E35B1),
          secondary:
              Color(0xFF3949AB),
          surface:
              Colors.white,
          surfaceContainerHighest:
              Color(0xFFEDEDF3),
        ),

        appBarTheme:
            const AppBarTheme(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),

        navigationBarTheme:
            const NavigationBarThemeData(
          backgroundColor:
              Colors.white,
          indicatorColor:
              Color(0xFFE6DDFB),
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
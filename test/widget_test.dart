import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/main.dart';
import 'package:flutter/material.dart';

void main() {
  // ==========================================================
  // FUNCTION: TEST MUSIC PLAYER APP
  // ==========================================================

  testWidgets(
    'Music Player app loads',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MusicPlayerApp(initialThemeMode: ThemeMode.system,),
      );

      // Verify that the application starts.
      expect(
        find.text('Home'),
        findsOneWidget,
      );
    },
  );
}
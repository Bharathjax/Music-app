import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart';
import '../controllers/playlist_controller.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/mini_player.dart';
import '../delegates/music_search_delegate.dart';
import 'main_content_layer.dart';
import '../models/song.dart';

class MusicHomePage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentThemeMode;

  const MusicHomePage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  late final MusicPlayerController playerController;
  late final PlaylistController playlistController;
  late final ValueNotifier<int> selectedTabNotifier;
  late final ValueNotifier<bool> transitionActiveNotifier;
  final GlobalKey<MainContentLayerState> _mainContentKey =
      GlobalKey<MainContentLayerState>();

  @override
  void initState() {
    super.initState();
    playerController = MusicPlayerController();
    playlistController = PlaylistController();
    selectedTabNotifier = ValueNotifier<int>(0);
    transitionActiveNotifier = ValueNotifier<bool>(false);
    playerController.loadDeviceSongs();
    playlistController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTabNotifier,
      builder: (context, currentTab, _) {
        return PopScope(
          // Only allow Android system Back to pop the app route when Home is
          // actually visible. Library/Settings must first return to Home.
          canPop: currentTab == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _mainContentKey.currentState?.handleSystemBack();
          },
          child: Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: MainContentLayer(
                key: _mainContentKey,
                playerController: playerController,
                playlistController: playlistController,
                selectedTabNotifier: selectedTabNotifier,
                transitionActiveNotifier: transitionActiveNotifier,
                currentThemeMode: widget.currentThemeMode,
                onThemeChanged: widget.onThemeChanged,
              ),
            ),
            // This layer is deliberately a separate subtree from Home/Library.
            // Tab transitions cannot rebuild or animate the Mini Player tree.
            _PersistentMiniPlayerLayer(
              playerController: playerController,
              playlistController: playlistController,
            ),
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: selectedTabNotifier,
                builder: (context, currentIndex, _) {
                  return MusicBottomNavigation(
                    currentIndex: currentIndex,
                    onTap: (index) {
                      if (index == 2) {
                        showSearch<Song?>(
                          context: context,
                          delegate: MusicSearchDelegate(
                            songs: playerController.songs,
                            onSongSelected: playerController.selectSong,
                          ),
                        );
                        return;
                      }
                      selectedTabNotifier.value = index;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
      },
    );
  }

  @override
  void dispose() {
    selectedTabNotifier.dispose();
    transitionActiveNotifier.dispose();
    playerController.dispose();
    super.dispose();
  }
}

/// Persistent player UI. This widget is a sibling of the page content rather
/// than a child of the Home/Library transition subtree.
class _PersistentMiniPlayerLayer extends StatelessWidget {
  final MusicPlayerController playerController;
  final PlaylistController playlistController;
  const _PersistentMiniPlayerLayer({
    required this.playerController,
    required this.playlistController,
  });

  void _openNowPlaying(BuildContext context) {
    if (playerController.currentSong == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _NowPlayingPlayerBridge(
            playerController: playerController,
            playlistController: playlistController,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
          // Keep the Now Playing transition fully opaque. The previous
          // FadeTransition blended the page underneath with the incoming
          // screen, which produced visible ghosting during the slide-up.
          return SlideTransition(
            position: slide,
            child: RepaintBoundary(child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: playerController.uiStateNotifier,
      builder: (context, _, _) {
        final song = playerController.currentSong;
        if (song == null) return const SizedBox.shrink();

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: MiniPlayer(
              song: song,
              isPlaying: playerController.isPlaying,
              progressListenable: playerController.progressNotifier,
              onTap: () => _openNowPlaying(context),
              onPlayPause: playerController.togglePlay,
              onNext: playerController.nextSong,
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingPlayerBridge extends StatelessWidget {
  final MusicPlayerController playerController;
  final PlaylistController playlistController;

  const _NowPlayingPlayerBridge({
    required this.playerController,
    required this.playlistController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: playerController.uiStateNotifier,
      builder: (context, _, _) {
        final current = playerController.currentSong;
        if (current == null) return const SizedBox.shrink();

        return ValueListenableBuilder<double>(
          valueListenable: playerController.progressNotifier,
          builder: (context, liveProgress, _) {
            return NowPlayingPageBridge(
              playerController: playerController,
              playlistController: playlistController,
              progress: liveProgress,
              song: current,
            );
          },
        );
      },
    );
  }
}

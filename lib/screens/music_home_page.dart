import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart';
import '../controllers/playlist_controller.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/mini_player.dart';
import 'main_content_layer.dart';

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
    playlistController.dispose();
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
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _NowPlayingPlayerBridge(
            playerController: playerController,
            playlistController: playlistController,
            initialProgress: playerController.progressNotifier.value,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1.0),
            end: Offset.zero,
          ).chain(
            CurveTween(curve: Curves.easeOutCubic),
          ).animate(animation);
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
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingPlayerBridge extends StatefulWidget {
  final MusicPlayerController playerController;
  final PlaylistController playlistController;
  final double initialProgress;

  const _NowPlayingPlayerBridge({
    required this.playerController,
    required this.playlistController,
    required this.initialProgress,
  });

  @override
  State<_NowPlayingPlayerBridge> createState() =>
      _NowPlayingPlayerBridgeState();
}

class _NowPlayingPlayerBridgeState extends State<_NowPlayingPlayerBridge> {
  Timer? _transitionTimer;
  bool _followLiveProgress = false;

  @override
  void initState() {
    super.initState();
    // Keep the page's high-frequency progress rebuilds out of the first
    // part of the route animation. This keeps the slide-up transform stable.
    _transitionTimer = Timer(const Duration(milliseconds: 370), () {
      if (!mounted) return;
      setState(() => _followLiveProgress = true);
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  Widget _buildPage(double progress) {
    final current = widget.playerController.currentSong;
    if (current == null) return const SizedBox.shrink();

    return NowPlayingPageBridge(
      playerController: widget.playerController,
      playlistController: widget.playlistController,
      progress: progress,
      song: current,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.playerController.currentSong;
    if (current == null) return const SizedBox.shrink();

    if (!_followLiveProgress) {
      return _buildPage(widget.initialProgress);
    }

    return ValueListenableBuilder<int>(
      valueListenable: widget.playerController.uiStateNotifier,
      builder: (context, _, _) {
        final song = widget.playerController.currentSong;
        if (song == null) return const SizedBox.shrink();

        return ValueListenableBuilder<double>(
          valueListenable: widget.playerController.progressNotifier,
          builder: (context, liveProgress, _) => _buildPage(liveProgress),
        );
      },
    );
  }
}

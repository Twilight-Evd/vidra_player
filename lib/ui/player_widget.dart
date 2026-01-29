// ui/player_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/player_controller.dart';
import '../core/state/states.dart';
import './controls/video_controls.dart';
import './indicators/error_display.dart';
import 'indicators/netflix_loading.dart';
import 'overlays/episode_list.dart';
import 'overlays/resume_dialog.dart';
import 'overlays/switching_overlay.dart';
import 'widget/slide_panel.dart';

/// The main video player widget for VidraPlayer.
///
/// This widget renders the video player UI including:
/// - Video display area with aspect ratio handling
/// - Playback controls (play/pause, progress bar, volume, etc.)
/// - Loading and buffering indicators
/// - Error display
/// - Episode list panel
/// - Resume/replay dialogs
/// - Keyboard and mouse interaction handling
///
/// The widget is controlled via a [PlayerController] which must be
/// provided in the constructor.
///
/// ## Usage
///
/// ```dart
/// final controller = PlayerController(...);
///
/// VideoPlayerWidget(
///   controller: controller,
///   showDefaultControls: true,
/// )
/// ```
///
/// ## Customization
///
///  You can customize the player appearance by:
/// - Providing custom loading/error widgets
/// - Using custom controls instead of default ones
/// - Configuring theme via [PlayerConfig]
///
/// ## Keyboard Shortcuts
///
/// The widget handles the following keyboard shortcuts:
/// - Space: Play/Pause
/// - F: Toggle fullscreen
/// - M: Toggle mute
/// - Arrow Left/Right: Seek -5s/+5s
/// - J/L: Seek -10s/+10s
/// - Arrow Up/Down: Volume up/down
/// - Escape: Exit fullscreen or close panels
///
/// See also:
/// - [PlayerController] for controlling playback
/// - [PlayerConfig] for configuration options
class VideoPlayerWidget extends StatefulWidget {
  final PlayerController controller;
  final Widget? customLoading;
  final Widget? customError;
  final Widget? customControls;
  final bool showDefaultControls;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.customLoading,
    this.customError,
    this.customControls,
    this.showDefaultControls = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey _videoContainerKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  Offset? _lastMousePosition;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ctrl = widget.controller;
    final theme = ctrl.config.theme;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _handleKeyEvent(event);
        }
        return KeyEventResult.handled;
      },
      child: StreamBuilder<UIVisibilityState>(
        stream: ctrl.uiManager.visibilityStream,
        initialData: ctrl.uiManager.currentVisibility,
        builder: (context, snapshot) {
          final ui = snapshot.data ?? const UIVisibilityState();
          return MouseRegion(
            cursor: ui.showMouseCursor
                ? MouseCursor.defer
                : SystemMouseCursors.none,
            onEnter: (_) => ctrl.uiManager.handleMouseEnterVideo(),
            onExit: (_) => ctrl.uiManager.handleMouseLeaveVideo(),
            onHover: (event) => _handleMouseMove(event.localPosition),
            child: Listener(
              onPointerDown: (event) => ctrl.uiManager.handleMouseEnterVideo(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ================== 1. Video Display Area ==================
                  StreamBuilder<PlaybackLifecycleState>(
                    stream: ctrl.lifecycleStream,
                    initialData: ctrl.playbackManager.lifecycleState,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      if (state == null || !state.isInitialized) {
                        if (ctrl.mediaManager.state.video?.coverUrl == null) {
                          return Center(
                            child: NetflixLoading(color: theme.primaryColor),
                          );
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              ctrl.mediaManager.state.video!.coverUrl,
                              errorBuilder: (ctx, err, stack) =>
                                  const SizedBox.shrink(),
                            ),
                            Container(color: Colors.black54),
                            Center(
                              child: NetflixLoading(color: theme.primaryColor),
                            ),
                          ],
                        );
                      }
                      return Center(
                        child: RepaintBoundary(
                          child: AspectRatio(
                            aspectRatio: state.aspectRatio,
                            child: ctrl.renderPlayer(key: _videoContainerKey),
                          ),
                        ),
                      );
                    },
                  ),

                  // ================== 2. Background Interaction Layer (Tap/Double Tap) ==================
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ctrl.toggleControls();
                    },
                    onDoubleTap: () {},
                    onDoubleTapDown: (details) =>
                        _handleDoubleTap(details.localPosition),
                    child: const SizedBox.expand(),
                  ),

                  // ================== 3. Buffering Indicator ==================
                  StreamBuilder<BufferingState>(
                    stream: ctrl.bufferingStream,
                    initialData: ctrl.buffering,
                    builder: (context, snapshot) {
                      final buffering = snapshot.data?.isBuffering ?? false;
                      if (!buffering) return const SizedBox.shrink();
                      return Center(
                        child: NetflixLoading(color: theme.primaryColor),
                      );
                    },
                  ),

                  // ================== 4. Error Display ==================
                  StreamBuilder<ErrorState>(
                    stream: ctrl.playbackManager.errorStream,
                    initialData: ctrl.error,
                    builder: (context, snapshot) {
                      final error = snapshot.data;
                      if (error == null || !error.hasError) {
                        return const SizedBox.shrink();
                      }
                      return ErrorDisplay(
                        controller: ctrl,
                        error: error.error!,
                      );
                    },
                  ),

                  // ================== 5. UI Controls Layer ==================
                  StreamBuilder<UIVisibilityState>(
                    stream: ctrl.uiManager.visibilityStream,
                    initialData: ctrl.uiManager.currentVisibility,
                    builder: (context, snapshot) {
                      final ui = snapshot.data ?? const UIVisibilityState();
                      return Stack(
                        children: [
                          // Custom Controls
                          if (widget.customControls != null)
                            widget.customControls!,

                          // Default Controls
                          if (widget.showDefaultControls)
                            ..._buildDefaultUI(context, ui),

                          // Dialog Layer
                          if (ui.showResumeDialog && ui.resumeState != null)
                            ResumeDialog(
                              controller: widget.controller,
                              position: Duration(
                                milliseconds: ui.resumeState!.positionMillis,
                              ),
                              duration: Duration(
                                milliseconds: ui.resumeState!.durationMillis,
                              ),
                              autoClose: !ctrl.config.behavior.resumeOnFocus,
                              onResume: () => ctrl.continuePlayback(
                                ui.resumeState!.positionMillis,
                              ),
                              onRestart: () => ctrl.restartPlayback(),
                            ),

                          if (ui.showReplayDialog && ui.replayState != null)
                            ReplayDialog(
                              controller: widget.controller,
                              position: Duration(
                                milliseconds: ui.replayState!.positionMillis,
                              ),
                              duration: Duration(
                                milliseconds: ui.replayState!.durationMillis,
                              ),
                              hasNextEpisode: ctrl.hasNextEpisode,
                              onReplay: () => ctrl.replayEpisode(),
                              onDismiss: () => ctrl.dismissReplayDialog(),
                              onPlayNext: ctrl.hasNextEpisode
                                  ? () => ctrl.playNextEpisodeFromReplay()
                                  : null,
                            ),

                          // Side Panel
                          Positioned.fill(
                            child: SlidePanel(
                              child: ui.showEpisodeList
                                  ? EpisodeList(
                                      key: const ValueKey('EpisodeListPanel'),
                                      controller: widget.controller,
                                      episodes: ctrl.media.episodes,
                                      histories: ctrl.media.episodeHistory,
                                      onClose: () =>
                                          widget.controller.hideEpisodeList(),
                                      currentEpisodeIndex:
                                          ctrl.media.currentEpisodeIndex,
                                      onEpisodeSelected: (int index) {
                                        widget.controller.switchEpisode(index);
                                        widget.controller.hideEpisodeList();
                                      },
                                      episodesSort: ctrl.config.episodesSort,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),

                          // Quality Switch Overlay
                          Positioned.fill(
                            child: StreamBuilder<SwitchingState>(
                              stream: widget.controller.switchingStream,
                              initialData: widget
                                  .controller
                                  .playbackManager
                                  .switchingState,
                              builder: (context, snapshot) {
                                final switchingState =
                                    snapshot.data ?? const SwitchingState();
                                return SwitchingOverlay(
                                  state: switchingState,
                                  coverUrl:
                                      widget.controller.media.video?.coverUrl,
                                  theme: widget.controller.config.theme,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleDoubleTap(Offset localPosition) {
    if (!mounted) return;

    if (context.size == null) return;
    final width = context.size!.width;
    final isLeft = localPosition.dx < width / 2;

    if (isLeft) {
      const amount = Duration(seconds: -10);
      widget.controller.seekRelative(amount);
      widget.controller.uiManager.showSeekFeedback(amount);
    } else {
      const amount = Duration(seconds: 10);
      widget.controller.seekRelative(amount);
      widget.controller.uiManager.showSeekFeedback(amount);
    }
  }

  List<Widget> _buildDefaultUI(
    BuildContext context,
    UIVisibilityState visibility,
  ) {
    final theme = widget.controller.config.theme;
    return [
      // Gradient Overlay - Always included but visibility controlled via opacity
      Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            opacity: visibility.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.backgroundColor.withAlpha(128),
                    Colors.transparent,
                    Colors.transparent,
                    theme.backgroundColor.withAlpha(128),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),

      Positioned.fill(
        child: VideoControls(
          controller: widget.controller,
          visibility: visibility,
        ),
      ),
    ];
  }

  void _handleMouseMove(Offset position) {
    _lastMousePosition = position;
    if (mounted && _lastMousePosition != null) {
      widget.controller.handleMouseMove(_lastMousePosition!);
    }
  }

  void _handleKeyEvent(KeyDownEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      widget.controller.handleKeyboardShortcut('space');
    } else if (key == LogicalKeyboardKey.keyF) {
      widget.controller.handleKeyboardShortcut('f');
    } else if (key == LogicalKeyboardKey.keyM) {
      widget.controller.handleKeyboardShortcut('m');
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      widget.controller.handleKeyboardShortcut('arrow_left');
    } else if (key == LogicalKeyboardKey.arrowRight) {
      widget.controller.handleKeyboardShortcut('arrow_right');
    } else if (key == LogicalKeyboardKey.arrowUp) {
      widget.controller.handleKeyboardShortcut('arrow_up');
    } else if (key == LogicalKeyboardKey.arrowDown) {
      widget.controller.handleKeyboardShortcut('arrow_down');
    } else if (key == LogicalKeyboardKey.keyJ) {
      widget.controller.handleKeyboardShortcut('j');
    } else if (key == LogicalKeyboardKey.keyL) {
      widget.controller.handleKeyboardShortcut('l');
    } else if (key == LogicalKeyboardKey.escape) {
      widget.controller.handleKeyboardShortcut('escape');
    } else if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.greater) {
      widget.controller.handleKeyboardShortcut('>');
    } else if (key == LogicalKeyboardKey.comma ||
        key == LogicalKeyboardKey.less) {
      widget.controller.handleKeyboardShortcut('<');
    }
  }
}

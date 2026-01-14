import 'package:flutter/material.dart';
import 'package:vidra_player/core/state/states.dart';
import '../../controller/player_controller.dart';
import '../../core/model/player_ui_theme.dart';
import '../widget/reveal_aimation.dart';
import 'top_bar.dart';
import 'progress_bar.dart';
import 'time_display.dart';
import '../widget/animation_button.dart';

/// Mobile video control panel
class MobileVideoControls extends StatelessWidget {
  final PlayerController controller;
  final UIVisibilityState visibility;
  final Animation<double> animation;

  const MobileVideoControls({
    super.key,
    required this.controller,
    required this.visibility,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final shouldBlockInteractions =
        visibility.showResumeDialog || visibility.showReplayDialog;
    final theme = controller.config.theme;
    return IgnorePointer(
      ignoring: !visibility.showControls || shouldBlockInteractions,
      child: Stack(
        children: [
          // Center Controls (Play/Pause + Seek)
          _MobileCenterControls(controller: controller, opacity: animation),

          // Top Control Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RevealAnimation(
              animation: animation,
              direction: RevealDirection.fromTop,
              child: Container(
                decoration: BoxDecoration(gradient: theme.topControlsGradient),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TopBar(
                  key: const Key("mobile_top_bar"),
                  controller: controller,
                ),
              ),
            ),
          ),

          // Bottom Control Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RevealAnimation(
              animation: animation,
              direction: RevealDirection.fromBottom,
              child: _MobileBottomControls(
                key: const Key("mobile_bottom_bar"),
                controller: controller,
              ),
            ),
          ),

          // Persistent Progress Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _MobileProgressBar(
              controller: controller,
              thumbVisible: visibility.showControls,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCenterControls extends StatelessWidget {
  final PlayerController controller;
  final Animation<double> opacity;

  const _MobileCenterControls({
    required this.controller,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;

    return Positioned.fill(
      child: StreamBuilder<PlaybackLifecycleState>(
        stream: controller.lifecycleStream,
        initialData: controller.lifecycle,
        builder: (context, stateSnapshot) {
          final state = stateSnapshot.data ?? const PlaybackLifecycleState();
          return Center(
            child: FadeTransition(
              opacity: opacity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Seek Backward 10s
                  _buildCircleButton(
                    theme: theme,
                    icon: Icons.replay_10,
                    onTap: () {
                      controller.seekRelative(const Duration(seconds: -10));
                      controller.uiManager.showSeekFeedback(
                        const Duration(seconds: -10),
                      );
                    },
                    size: 48,
                  ),
                  const SizedBox(width: 48),

                  // Play/Pause
                  _buildCircleButton(
                    theme: theme,
                    icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                    onTap: () => controller.togglePlayPause(),
                    size: 72,
                    iconSize: 40,
                  ),

                  const SizedBox(width: 48),

                  // Seek Forward 10s
                  _buildCircleButton(
                    theme: theme,
                    icon: Icons.forward_10,
                    onTap: () {
                      controller.seekRelative(const Duration(seconds: 10));
                      controller.uiManager.showSeekFeedback(
                        const Duration(seconds: 10),
                      );
                    },
                    size: 48,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircleButton({
    required PlayerUITheme theme,
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    double iconSize = 28,
  }) {
    return AnimationButton(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.backgroundColor.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: theme.iconColor),
      ),
    );
  }
}

class _MobileBottomControls extends StatelessWidget {
  final PlayerController controller;

  const _MobileBottomControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;

    return Container(
      decoration: BoxDecoration(gradient: theme.bottomControlsGradient),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Add 8px to match TopBar's leading IconButton internal padding
          TimeDisplay(controller: controller),
          const Spacer(),

          StreamBuilder<ViewModeState>(
            stream: controller.viewStream,
            initialData: controller.view,
            builder: (context, snapshot) {
              final viewState = snapshot.data ?? controller.view;
              final isFullscreen = viewState.isFullscreen;
              final isPip = viewState.isPip;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.config.features.enablePictureInPicture &&
                      !isFullscreen)
                    AnimationButton(
                      onTap: () => controller.togglePip(),
                      child: IconButton(
                        key: const ValueKey('mobile_pip_button'),
                        onPressed: () {},
                        icon: Icon(
                          isPip
                              ? Icons.picture_in_picture
                              : Icons.picture_in_picture_alt,
                          color: theme.iconColor,
                          size: 24,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  AnimationButton(
                    onTap: () => controller.toggleFullscreen(),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: theme.iconColor,
                        size: 24,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileProgressBar extends StatelessWidget {
  final PlayerController controller;
  final bool thumbVisible;

  const _MobileProgressBar({
    required this.controller,
    required this.thumbVisible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;
    return StreamBuilder<PlaybackPositionState>(
      stream: controller.positionStream,
      initialData: controller.position,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data ?? const PlaybackPositionState();

        final displayPosition = state.isSeeking && state.seekTarget != null
            ? state.seekTarget!
            : state.position;

        return RepaintBoundary(
          child: VideoProgressBar(
            key: const ValueKey("mobile_video_progress_bar"),
            position: displayPosition,
            duration: state.duration,
            buffered: state.buffered,
            onSeek: (pos) => controller.seek(pos, SeekSource.userDrag),
            onSeekStart: controller.seekStart,
            onSeekEnd: controller.seekEnd,
            playedColor: theme.progressBarColor,
            bufferedColor: theme.bufferedColor,
            handleColor: theme.progressBarColor,
            barHeight: thumbVisible ? 3 : 2, // Thinner when hidden
            handleRadius: 4, // Larger handle for touch
            padding: 0,
            thumbVisible: thumbVisible,
          ),
        );
      },
    );
  }
}

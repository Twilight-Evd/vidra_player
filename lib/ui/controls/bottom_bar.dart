import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';
import 'progress_bar.dart';
import 'playback_controls.dart';
import 'time_display.dart';
import 'quality_selector.dart';
import 'speed_selector.dart';
import 'more_menu_parts.dart';
import '../../utils/screen.dart';
import '../widget/animation_button.dart';

class BottomBar extends StatelessWidget {
  final PlayerController controller;

  const BottomBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;
    // final l10n = controller.localization;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PlaybackPositionState>(
          stream: controller.positionStream,
          initialData: controller.position,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data ?? const PlaybackPositionState();

            final displayPosition = state.isSeeking && state.seekTarget != null
                ? state.seekTarget!
                : state.position;

            return RepaintBoundary(
              child: VideoProgressBar(
                key: const ValueKey("video_progress_bar"),
                position: displayPosition, //state.position,
                duration: state.duration,
                buffered: state.buffered,
                onSeek: (pos) => controller.seek(pos, SeekSource.userDrag),
                onSeekStart: controller.seekStart,
                onSeekEnd: controller.seekEnd,
                playedColor: theme.progressBarColor,
                bufferedColor: theme.bufferedColor,
                handleColor: theme.progressBarColor,
              ),
            );
          },
        ),

        // Controls Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = ScreenHelper.isMediumScreen(context);
            final spaceW = isSmall ? 4.0 : 8.0;
            return StreamBuilder<ViewModeState>(
              stream: controller.viewStream,
              initialData: controller.view,
              builder: (context, viewSnapshot) {
                final view = viewSnapshot.data ?? controller.view;
                return Row(
                  children: [
                    PlaybackControls(
                      key: const ValueKey('playback_controls'),
                      controller: controller,
                      isSmall: isSmall,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: spaceW,
                    ),
                    TimeDisplay(controller: controller),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.1, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: !isSmall
                          ? Row(
                              key: const ValueKey('desktop_controls_row'),
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!view.isPip) ...[
                                  SettingsMenu(
                                    key: const ValueKey(
                                      'bottom_bar_settings_menu',
                                    ),
                                    controller: controller,
                                    theme: theme,
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: spaceW,
                                  ),
                                  QualitySelector(
                                    key: const ValueKey('quality_selector'),
                                    controller: controller,
                                    onOpen: () => controller.showMoreMenu(),
                                    onClose: () => controller.hideMoreMenu(),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: spaceW,
                                  ),
                                  SpeedSelector(
                                    key: const ValueKey('speed_selector'),
                                    controller: controller,
                                    onOpen: () => controller.showMoreMenu(),
                                    onClose: () => controller.hideMoreMenu(),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: spaceW,
                                  ),
                                ],
                                if (controller
                                        .config
                                        .features
                                        .enablePictureInPicture &&
                                    !view.isFullscreen)
                                  AnimationButton(
                                    onTap: () => controller.togglePip(),
                                    child: IconButton(
                                      key: const ValueKey(
                                        'bottom_bar_pip_button',
                                      ),
                                      icon: Icon(
                                        view.isPip
                                            ? Icons.picture_in_picture
                                            : Icons.picture_in_picture_alt,
                                        color: theme.iconColor,
                                        size: 20,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                if (!view.isPip) ...[
                                  if (controller
                                          .config
                                          .features
                                          .enablePictureInPicture &&
                                      !view.isFullscreen)
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: spaceW,
                                    ),
                                  AnimationButton(
                                    onTap: () => controller.toggleFullscreen(),
                                    child: IconButton(
                                      key: const ValueKey(
                                        'bottom_bar_fullscreen_button',
                                      ),
                                      icon: Icon(
                                        view.isFullscreen
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        color: theme.iconColor,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : MoreMenu(
                              controller: controller,
                              theme: theme,
                              view: view,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

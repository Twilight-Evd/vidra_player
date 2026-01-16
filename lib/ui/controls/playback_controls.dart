import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';
import '../widget/animated_icon_button.dart';
import 'volume_control.dart';

class PlaybackControls extends StatelessWidget {
  final PlayerController controller;
  final bool isSmall;

  const PlaybackControls({
    super.key,
    required this.controller,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;
    // final l10n = controller.localization;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  child: child,
                ),
              );
            },
            child: !isSmall
                ? Row(
                    key: const ValueKey('play_pause_group'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<PlaybackLifecycleState>(
                        stream: controller.lifecycleStream,
                        initialData: controller.lifecycle,
                        builder: (context, stateSnapshot) {
                          final state =
                              stateSnapshot.data ??
                              const PlaybackLifecycleState();
                          return AnimatedIconButton(
                            icon: Icons.play_arrow,
                            selectedIcon: Icons.pause,
                            isSelected: state.isPlaying,
                            color: theme.iconColor,
                            onPressed: () => controller.togglePlayPause(),
                            debounce: true,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('play_pause_empty')),
          ),
        ),
        AnimatedIconButton(
          key: const ValueKey('bottom_bar_previous_button'),
          icon: Icons.skip_previous,
          color: controller.hasPreviousEpisode
              ? theme.iconColor
              : theme.iconColorDisabled,
          onPressed: controller.hasPreviousEpisode ? () {} : null,
          onCompleted: controller.hasPreviousEpisode
              ? () => controller.playPreviousEpisode()
              : null,
          debounce: true,
        ),
        const SizedBox(width: 8),
        AnimatedIconButton(
          key: const ValueKey('bottom_bar_next_button'),
          icon: Icons.skip_next,
          color: controller.hasNextEpisode
              ? theme.iconColor
              : theme.iconColorDisabled,
          onPressed: controller.hasNextEpisode ? () {} : null,
          onCompleted: controller.hasNextEpisode
              ? () => controller.playNextEpisode()
              : null,
          debounce: true,
        ),
        const SizedBox(width: 8),
        // Volume Control
        VolumeControl(controller: controller),
      ],
    );
  }
}

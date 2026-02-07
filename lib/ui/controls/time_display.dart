import 'package:flutter/material.dart';
import 'package:vidra_player/utils/util.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';

class TimeDisplay extends StatelessWidget {
  final PlayerController controller;

  const TimeDisplay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;
    return ValueListenableBuilder<PlaybackPositionState>(
      valueListenable: controller.playbackManager.positionNotifier,
      builder: (context, state, _) {
        return Text(
          '${Util.formatDuration(state.position)} / ${Util.formatDuration(state.duration)}',
          style: TextStyle(color: theme.textColor),
        );
      },
    );
  }
}

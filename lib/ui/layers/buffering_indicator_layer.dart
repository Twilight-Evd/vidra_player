import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';
import '../indicators/netflix_loading.dart';

/// 缓冲指示器层
class BufferingIndicatorLayer extends StatelessWidget {
  final PlayerController controller;
  final Widget? customLoading;

  const BufferingIndicatorLayer({
    super.key,
    required this.controller,
    this.customLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;

    return StreamBuilder<PlaybackLifecycleState>(
      stream: controller.lifecycleStream,
      initialData: controller.lifecycle,
      builder: (context, lifecycleSnapshot) {
        final lifecycle = lifecycleSnapshot.data ?? controller.lifecycle;

        return StreamBuilder<BufferingState>(
          stream: controller.bufferingStream,
          initialData: controller.buffering,
          builder: (context, bufferingSnapshot) {
            final isBuffering = bufferingSnapshot.data?.isBuffering ?? false;

            // Only show buffering indicator if:
            // 1. We are actually buffering
            // 2. We are playing OR we haven't finished initializing yet (initial load)
            final shouldShow =
                isBuffering &&
                (lifecycle.isPlaying || !lifecycle.isInitialized);

            if (!shouldShow) return const SizedBox.shrink();

            return Center(
              child: customLoading ?? NetflixLoading(color: theme.primaryColor),
            );
          },
        );
      },
    );
  }
}

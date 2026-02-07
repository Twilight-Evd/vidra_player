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

    return StreamBuilder<BufferingState>(
      stream: controller.bufferingStream,
      initialData: controller.buffering,
      builder: (context, snapshot) {
        final isBuffering = snapshot.data?.isBuffering ?? false;

        if (!isBuffering) return const SizedBox.shrink();

        return Center(
          child: customLoading ?? NetflixLoading(color: theme.primaryColor),
        );
      },
    );
  }
}

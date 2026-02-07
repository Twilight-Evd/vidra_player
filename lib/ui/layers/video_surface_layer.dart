import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';
import '../indicators/netflix_loading.dart';

/// 视频渲染层
class VideoSurfaceLayer extends StatelessWidget {
  final PlayerController controller;
  final Widget? customLoading;

  const VideoSurfaceLayer({
    super.key,
    required this.controller,
    this.customLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.config.theme;

    return StreamBuilder<PlaybackLifecycleState>(
      stream: controller.lifecycleStream,
      initialData: controller.playbackManager.lifecycleState,
      builder: (context, snapshot) {
        final state = snapshot.data;

        // 1. 未初始化状态：显示封面图和Loading
        if (state == null || !state.isInitialized) {
          final coverUrl = controller.mediaManager.state.video?.coverUrl;

          if (coverUrl == null) {
            return Center(
              child: customLoading ?? NetflixLoading(color: theme.primaryColor),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                coverUrl,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                fit: BoxFit.cover,
              ),
              Container(color: Colors.black54),
              Center(
                child:
                    customLoading ?? NetflixLoading(color: theme.primaryColor),
              ),
            ],
          );
        }

        // 2. 已初始化：显示视频纹理
        return Center(
          child: RepaintBoundary(
            child: AspectRatio(
              aspectRatio: state.aspectRatio,
              child: controller.renderPlayer(),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';

/// 手势检测层
class GestureDetectorLayer extends StatelessWidget {
  final PlayerController controller;
  final Function(Offset)? onDoubleTap;

  const GestureDetectorLayer({
    super.key,
    required this.controller,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UIVisibilityState>(
      stream: controller.uiManager.visibilityStream,
      initialData: controller.uiManager.currentVisibility,
      builder: (context, snapshot) {
        final ui = snapshot.data ?? const UIVisibilityState();

        // 调整层级: Listener 在最外层，确保能捕获所有指针事件，
        // 即使 MouseRegion 将 cursor 设置为 none。
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerHover: (event) {
            controller.handleMouseMove(event.localPosition);
          },
          onPointerMove: (event) {
            controller.handleMouseMove(event.localPosition);
          },
          onPointerDown: (event) {
            controller.uiManager.handleMouseEnterVideo();
          },
          child: MouseRegion(
            cursor: ui.showMouseCursor
                ? MouseCursor.defer
                : SystemMouseCursors.none,
            onEnter: (_) => controller.uiManager.handleMouseEnterVideo(),
            onExit: (_) => controller.uiManager.handleMouseLeaveVideo(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.toggleControls(),
              onDoubleTapDown: (details) =>
                  onDoubleTap?.call(details.localPosition),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:vidra_player/core/state/states.dart';
import 'package:vidra_player/ui/widget/blur.dart';
import '../../controller/player_controller.dart';
import '../widget/reveal_aimation.dart';
import 'center_play_button.dart';
import 'top_bar.dart';
import 'bottom_bar.dart';

/// Desktop video control panel
class DesktopVideoControls extends StatelessWidget {
  final PlayerController controller;
  final UIVisibilityState visibility;
  final Animation<double> animation;

  const DesktopVideoControls({
    super.key,
    required this.controller,
    required this.visibility,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Block all interactions when resume or replay dialog is visible
    final shouldBlockInteractions =
        visibility.showResumeDialog || visibility.showReplayDialog;
    final theme = controller.config.theme;
    return IgnorePointer(
      ignoring: !visibility.showControls || shouldBlockInteractions,
      child: Stack(
        children: [
          // Center Play Button
          CenterPlayButton(controller: controller, opacity: animation),

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
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: TopBar(
                  key: const Key("top_bar"),
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
            child: Container(
              decoration: BoxDecoration(gradient: theme.bottomControlsGradient),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildSkipPrompt(),
                  _buildSeekFeedback(),
                  RevealAnimation(
                    animation: animation,
                    direction: RevealDirection.fromBottom,
                    clip: false, // Allow overflow for tooltips
                    child: BottomBar(
                      key: const Key("bottom_bar"),
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipPrompt() {
    final theme = controller.config.theme;
    return StreamBuilder<UIVisibilityState>(
      stream: controller.uiManager.visibilityStream,
      initialData: controller.uiManager.currentVisibility,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final type = state?.skipNotification ?? SkipNotificationType.none;

        return AnimatedSwitcher(
          duration: theme.animationDuration,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: type == SkipNotificationType.none
              ? const SizedBox.shrink(key: ValueKey('none'))
              : _buildPromptContent(type),
        );
      },
    );
  }

  Widget _buildSeekFeedback() {
    final theme = controller.config.theme;
    return StreamBuilder<UIVisibilityState>(
      stream: controller.uiManager.visibilityStream,
      initialData: controller.uiManager.currentVisibility,
      builder: (context, snapshot) {
        final state = snapshot.data;
        // Important: Force check for null vs existing duration
        final seekAmount = state?.seekFeedback;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            );
          },
          child: seekAmount == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Padding(
                  key: const ValueKey('seek_feedback_container'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: BlurPanel(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: theme.dialogBackgroundColor.withValues(
                            alpha: 0.4,
                          ), // Adapted to theme
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              seekAmount.isNegative
                                  ? Icons.replay_10
                                  : Icons.forward_10,
                              color: theme.iconColor, // Adapted to theme
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${seekAmount.inSeconds > 0 ? '+' : ''}${seekAmount.inSeconds}s',
                              style: TextStyle(
                                color: theme.textColor, // Adapted to theme
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPromptContent(SkipNotificationType type) {
    final theme = controller.config.theme;
    final isIntro = type == SkipNotificationType.intro;
    final text = isIntro
        ? controller.localization.translate('skipping_intro')
        : controller.localization.translate('skipping_outro');

    return BlurPanel(
      child: Padding(
        key: ValueKey(type),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Align(
          alignment: isIntro ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: theme.backgroundColor.withValues(
                alpha: 0.8,
              ), // Adapted to theme
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.iconColor.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isIntro) ...[
                  Icon(
                    Icons.skip_next,
                    color: theme.iconColor,
                    size: 18,
                  ), // Adapted
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: theme.textColor, // Adapted
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isIntro) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.skip_next,
                    color: theme.iconColor,
                    size: 18,
                  ), // Adapted
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

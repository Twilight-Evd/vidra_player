import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/state/states.dart';
import '../widget/animated_icon_button.dart';

class VolumeControl extends StatefulWidget {
  final PlayerController controller;

  const VolumeControl({super.key, required this.controller});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.config.theme;
    // final l10n = widget.controller.localization;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        // widget.controller.uiManager.handleMouseEnterControls();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        // widget.controller.uiManager.handleMouseLeaveControls();
      },
      child: StreamBuilder<AudioState>(
        stream: widget.controller.audioStream,
        initialData: widget.controller.audio,
        builder: (context, snapshot) {
          final audioState = snapshot.data!;
          final volume = audioState.volume;
          final isMuted = audioState.isMuted;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedIconButton(
                key: const ValueKey('volume_mute_button'),
                icon: volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                selectedIcon: Icons.volume_off,
                isSelected: isMuted || volume == 0,
                color: theme.iconColor,
                iconSize: 20,
                onPressed: () => widget.controller.toggleMute(),
                debounce: true,
              ),
              AnimatedContainer(
                margin: EdgeInsets.only(right: 5),
                duration: const Duration(milliseconds: 200),
                width: _isHovering ? 100 : 0,
                curve: Curves.easeInOut,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: theme.progressBarColor,
                    inactiveTrackColor: theme.bufferedColor,
                    thumbColor: theme.progressBarColor,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: isMuted ? 0 : volume,
                    onChanged: (value) {
                      widget.controller.setVolume(value);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

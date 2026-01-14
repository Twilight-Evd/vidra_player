import 'package:flutter/material.dart';

/// Behavior Configuration
@immutable
class PlayerBehavior {
  final Duration autoHideDelay;
  final Duration mouseHideDelay;
  final Duration hoverShowDelay;
  final Duration progressSaveInterval;
  final Duration bufferSize;
  final bool pauseOnWindowLoseFocus;
  final bool pauseOnMinimize;
  final bool resumeOnFocus;
  final bool showControlsOnHover;
  final bool hideMouseWhenIdle;
  final bool autoPlay;
  final bool loop;
  final bool muteOnStart;
  final double initialVolume;
  final double minBufferDuration;
  final double maxBufferDuration;

  const PlayerBehavior({
    this.autoHideDelay = const Duration(seconds: 3),
    this.mouseHideDelay = const Duration(seconds: 2),
    this.hoverShowDelay = const Duration(milliseconds: 300),
    this.progressSaveInterval = const Duration(seconds: 5),
    this.bufferSize = const Duration(seconds: 10),
    this.pauseOnWindowLoseFocus = true,
    this.pauseOnMinimize = true,
    this.resumeOnFocus = true,
    this.showControlsOnHover = true,
    this.hideMouseWhenIdle = true,
    this.autoPlay = true,
    this.loop = false,
    this.muteOnStart = false,
    this.initialVolume = 1.0,
    this.minBufferDuration = 2.0,
    this.maxBufferDuration = 10.0,
  });
}

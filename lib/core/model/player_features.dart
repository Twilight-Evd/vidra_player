import 'package:flutter/material.dart';

/// Feature Configuration
@immutable
class PlayerFeatures {
  final bool enableHistory;
  final bool enableDownload;
  final bool enableFullscreen;
  final bool enablePictureInPicture;
  final bool enableKeyboardShortcuts;
  final bool enableMouseGestures;
  final bool enableAutoPlayNext;
  final bool enableQualitySelection;
  final bool enablePlaybackSpeed;
  final bool enableSubtitle;
  final bool enableAudioTrack;
  final bool enableCast;
  final bool enableShare;

  const PlayerFeatures({
    this.enableHistory = true,
    this.enableDownload = true,
    this.enableFullscreen = true,
    this.enablePictureInPicture = true,
    this.enableKeyboardShortcuts = true,
    this.enableMouseGestures = true,
    this.enableAutoPlayNext = true,
    this.enableQualitySelection = true,
    this.enablePlaybackSpeed = true,
    this.enableSubtitle = false,
    this.enableAudioTrack = false,
    this.enableCast = false,
    this.enableShare = false,
  });

  const PlayerFeatures.all()
    : enableHistory = true,
      enableDownload = true,
      enableFullscreen = true,
      enablePictureInPicture = true,
      enableKeyboardShortcuts = true,
      enableMouseGestures = true,
      enableAutoPlayNext = true,
      enableQualitySelection = true,
      enablePlaybackSpeed = true,
      enableSubtitle = true,
      enableAudioTrack = true,
      enableCast = true,
      enableShare = true;

  const PlayerFeatures.minimal()
    : enableHistory = false,
      enableDownload = false,
      enableFullscreen = false,
      enablePictureInPicture = false,
      enableKeyboardShortcuts = false,
      enableMouseGestures = false,
      enableAutoPlayNext = false,
      enableQualitySelection = false,
      enablePlaybackSpeed = false,
      enableSubtitle = false,
      enableAudioTrack = false,
      enableCast = false,
      enableShare = false;
}

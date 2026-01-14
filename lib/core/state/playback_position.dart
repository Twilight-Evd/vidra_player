import 'package:flutter/material.dart';

import '../model/model.dart';

enum SeekSource {
  userDrag,
  external, // Init resume / Switch episode / Code call
}

@immutable
class PlaybackPositionState {
  final Duration position;
  final Duration duration;
  final List<BufferRange> buffered;

  /// Whether currently seeking (user or external)
  final bool isSeeking;

  /// Seek target (milliseconds)
  final Duration? seekTarget;

  /// Source of this seek (for debugging & behavior distinction)
  final SeekSource? seekSource;

  const PlaybackPositionState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = const [],
    this.isSeeking = false,
    this.seekTarget,
    this.seekSource,
  });

  double get progress => duration.inMilliseconds == 0
      ? 0
      : position.inMilliseconds / duration.inMilliseconds;

  PlaybackPositionState copyWith({
    Duration? position,
    Duration? duration,
    List<BufferRange>? buffered,
    bool? isSeeking,
    Duration? seekTarget,
    SeekSource? seekSource,
  }) {
    return PlaybackPositionState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isSeeking: isSeeking ?? this.isSeeking,
      seekTarget: seekTarget ?? this.seekTarget,
      seekSource: seekSource ?? this.seekSource,
    );
  }

  bool get hasDuration => duration > Duration.zero;

  @override
  String toString() {
    return 'PlaybackPositionState(position: $position, duration: $duration, buffered: $buffered)';
  }
}

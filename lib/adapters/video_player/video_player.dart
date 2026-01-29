import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/lifecycle/lifecycle_token.dart';
import '../../core/lifecycle/safe_stream.dart';
import '../../core/interfaces/video_player.dart';
import '../../core/model/model.dart';

class VideoPlayerAdapter with LifecycleTokenProvider implements IVideoPlayer {
  VideoPlayerController? _controller;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<PlayerError?>.broadcast();
  final _bufferedCtrl = StreamController<List<BufferRange>>.broadcast();
  final _videoSizeCtrl = StreamController<VideoSize?>.broadcast();

  // PERFORMANCE FIX: Cache buffered ranges to avoid allocation on every frame
  List<BufferRange> _cachedBufferedRanges = [];

  @override
  Future<void> initialize(VideoSource source) async {
    // Prevent leak: Dispose existing controller if initialize is called without reset
    if (_controller != null) {
      await reset();
    }

    switch (source.type) {
      case VideoSourceType.network:
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(source.path),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
        break;
      case VideoSourceType.file:
        _controller = VideoPlayerController.file(
          File(source.path),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
        break;
      case VideoSourceType.asset:
        _controller = VideoPlayerController.asset(
          source.path,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
        break;
    }

    await _controller!.initialize();

    final size = _controller!.value.size;
    _videoSizeCtrl.add(VideoSize(size.width.toInt(), size.height.toInt()));

    _controller!.addListener(_onTick);
  }

  void _onTick() {
    final token = lifecycleToken;
    if (!token.isAlive) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    final value = _controller!.value;

    safeEmit(_positionCtrl, value.position, token);
    safeEmit(_playingCtrl, value.isPlaying, token);
    safeEmit(_bufferingCtrl, value.isBuffering, token);

    // PERFORMANCE FIX: Only update buffered ranges if they changed
    final newBuffered = value.buffered;
    if (_bufferedRangesChanged(newBuffered)) {
      _cachedBufferedRanges = newBuffered
          .map((e) => BufferRange(start: e.start, end: e.end))
          .toList();
      safeEmit(_bufferedCtrl, _cachedBufferedRanges, token);
    }

    if (value.hasError) {
      safeEmit(
        _errorCtrl,
        PlayerError(
          code: "",
          message: value.errorDescription ?? 'Unknown error',
        ),
        token,
      );
    }
  }

  // PERFORMANCE FIX: Helper to check if buffered ranges changed
  bool _bufferedRangesChanged(List<DurationRange> newRanges) {
    if (_cachedBufferedRanges.length != newRanges.length) return true;

    for (int i = 0; i < newRanges.length; i++) {
      final cached = _cachedBufferedRanges[i];
      final current = newRanges[i];
      if (cached.start != current.start || cached.end != current.end) {
        return true;
      }
    }
    return false;
  }

  @override
  VideoSize? get videoSize {
    if (!_controller!.value.isInitialized) return null;
    final size = _controller!.value.size;
    return VideoSize(size.width.toInt(), size.height.toInt());
  }

  @override
  Widget render({
    Key? key,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox();
    }

    return VideoPlayer(_controller!, key: key);
  }

  // ---- playback ----

  @override
  Future<void> play() => _controller!.play();

  @override
  Future<void> pause() => _controller!.pause();

  @override
  Future<void> seek(Duration position) => _controller!.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller!.setVolume(volume);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _controller!.setPlaybackSpeed(speed);

  // ---- state ----

  @override
  Duration get duration => _controller!.value.duration;

  @override
  Duration get position => _controller!.value.position;

  @override
  bool get isPlaying => _controller!.value.isPlaying;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;

  @override
  Stream<bool> get isPlayingStream => _playingCtrl.stream;

  @override
  Stream<PlayerError?> get errorStream => _errorCtrl.stream;

  @override
  Stream<List<BufferRange>> get bufferedStream => _bufferedCtrl.stream;

  @override
  Stream<VideoSize?> get videoSizeStream => _videoSizeCtrl.stream;

  @override
  Future<void> reset() async {
    if (_controller == null) return;
    final controller = _controller!;
    _controller = null;

    // PERFORMANCE FIX: Clear cached state
    _cachedBufferedRanges = [];

    try {
      controller.removeListener(_onTick);
      await controller.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }
  }

  @override
  Future<void> dispose() async {
    invalidateLifecycle();
    await reset();
    await _positionCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _errorCtrl.close();
    await _bufferedCtrl.close();
    await _videoSizeCtrl.close();
  }
}

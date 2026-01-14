import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/interfaces/video_player.dart';
import '../../core/model/model.dart';

class VideoPlayerAdapter implements IVideoPlayer {
  VideoPlayerController? _controller;
  bool _isDisposed = false;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<PlayerError?>.broadcast();
  final _bufferedCtrl = StreamController<List<BufferRange>>.broadcast();
  final _videoSizeCtrl = StreamController<VideoSize?>.broadcast();

  @override
  Future<void> initialize(VideoSource source) async {
    switch (source.type) {
      case VideoSourceType.network:
        _controller = VideoPlayerController.networkUrl(Uri.parse(source.path));
        break;
      case VideoSourceType.file:
        _controller = VideoPlayerController.file(File(source.path));
        break;
      case VideoSourceType.asset:
        _controller = VideoPlayerController.asset(source.path);
        break;
    }

    await _controller!.initialize();

    final size = _controller!.value.size;
    _videoSizeCtrl.add(VideoSize(size.width.toInt(), size.height.toInt()));

    _controller!.addListener(_onTick);
  }

  void _onTick() {
    if (_isDisposed) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    final value = _controller!.value;

    _positionCtrl.add(value.position);
    _playingCtrl.add(value.isPlaying);
    _bufferingCtrl.add(value.isBuffering);
    _bufferedCtrl.add(
      value.buffered
          .map((e) => BufferRange(start: e.start, end: e.end))
          .toList(),
    );
    if (value.hasError) {
      _errorCtrl.add(
        PlayerError(
          code: "",
          message: value.errorDescription ?? 'Unknown error',
        ),
      );
    }
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

    try {
      controller.removeListener(_onTick);
      await controller.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await reset();
    await _positionCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _errorCtrl.close();
    await _bufferedCtrl.close();
    await _videoSizeCtrl.close();
  }
}

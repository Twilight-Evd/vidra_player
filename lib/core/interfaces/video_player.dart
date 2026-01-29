import 'dart:async';

import 'package:flutter/material.dart';

import '../model/model.dart';

abstract class IVideoPlayer {
  // ---------- lifecycle ----------
  Future<void> initialize(VideoSource source);
  Future<void> dispose();
  Future<void> reset();

  // ---------- playback ----------
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setPlaybackSpeed(double speed);

  // ---------- state ----------
  Duration get duration;
  Duration get position;
  bool get isPlaying;

  //----------------------------
  VideoSize? get videoSize;

  Stream<Duration> get positionStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get isPlayingStream;
  Stream<PlayerError?> get errorStream;
  Stream<List<BufferRange>> get bufferedStream;

  //--------------- videosize---------
  Stream<VideoSize?> get videoSizeStream;

  // ---------- rendering ----------
  Widget render({Key? key, BoxFit fit, Alignment alignment});
}

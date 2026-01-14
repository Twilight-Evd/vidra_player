import 'dart:async';

import '../core/interfaces/video_player.dart';
import '../core/state/audio.dart';

class AudioManager {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final IVideoPlayer _player;

  final _audioCtrl = StreamController<AudioState>.broadcast();
  AudioState _state = const AudioState();

  // ===============================================================
  // Construction
  // ===============================================================

  AudioManager({required IVideoPlayer player}) : _player = player;

  // ===============================================================
  // Stream & State Accessors
  // ===============================================================

  Stream<AudioState> get audioStream => _audioCtrl.stream;
  AudioState get state => _state;

  // ===============================================================
  // Actions
  // ===============================================================

  Future<void> setVolume(double volume) async {
    _state = _state.copyWith(volume: volume, isMuted: volume == 0);
    _audioCtrl.add(_state);
    await _player.setVolume(volume);
  }

  Future<void> setMute() async {
    _state = _state.copyWith(isMuted: true);
    _audioCtrl.add(_state);
    await _player.setVolume(0);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _state = _state.copyWith(playbackSpeed: speed);
    _audioCtrl.add(_state);
    await _player.setPlaybackSpeed(speed);
  }

  Future<void> restoreState() async {
    if (_state.isMuted) {
      await _player.setVolume(0);
    } else {
      await _player.setVolume(_state.volume);
    }
    await _player.setPlaybackSpeed(_state.playbackSpeed);
  }

  Future<void> toggleMute() async {
    double newVolume = _state.isMuted
        ? (_state.volume == 0 ? 1.0 : _state.volume)
        : 0.0;
    if (newVolume == 0) {
      await setMute();
    } else {
      await setVolume(newVolume);
    }
  }

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    _audioCtrl.close();
  }
}

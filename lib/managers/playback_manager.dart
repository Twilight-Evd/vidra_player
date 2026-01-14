import 'dart:async';
import 'package:flutter/widgets.dart';

import '../core/interfaces/video_player.dart';
import '../core/model/model.dart';
import '../core/state/states.dart';
import '../utils/log.dart';

/// Manages playback state and coordinates with the underlying video player.
///
/// This is an internal implementation class. SDK users should interact
/// with [PlayerController] instead.
class PlaybackManager {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final PlayerConfig _config;
  final IVideoPlayer _player;

  Timer? _positionTimer;

  // Internal State Cache
  PlaybackLifecycleState _lifecycleState = const PlaybackLifecycleState();
  PlaybackPositionState _positionState = const PlaybackPositionState();
  ErrorState _errorState = const ErrorState();
  SwitchingState _switching = const SwitchingState();

  // Stream Controllers
  final _lifecycleCtrl = StreamController<PlaybackLifecycleState>.broadcast();
  final _positionCtrl = StreamController<PlaybackPositionState>.broadcast();
  final _errorCtrl = StreamController<ErrorState>.broadcast();
  final _switchingCtrl = StreamController<SwitchingState>.broadcast();

  // ===============================================================
  // Construction
  // ===============================================================

  PlaybackManager({required PlayerConfig config, required IVideoPlayer player})
    : _config = config,
      _player = player {
    _bindPlayerStreams();
  }

  // ===============================================================
  // Stream & State Accessors
  // ===============================================================

  Stream<PlaybackLifecycleState> get lifecycleStream => _lifecycleCtrl.stream;
  Stream<PlaybackPositionState> get positionStream => _positionCtrl.stream;
  Stream<ErrorState> get errorStream => _errorCtrl.stream;
  Stream<SwitchingState> get switchingStream => _switchingCtrl.stream;

  PlaybackLifecycleState get lifecycleState => _lifecycleState;
  PlaybackPositionState get positionState => _positionState;
  SwitchingState get switchingState => _switching;

  // ===============================================================
  // Initialization & Playback Control
  // ===============================================================

  Future<void> initialize({
    VideoMetadata? video,
    required List<VideoEpisode> episodes,
    int? episodeIndex,
    int? qualityIndex,
  }) async {
    if (episodes.isEmpty ||
        episodes.elementAtOrNull(episodeIndex ?? 0) == null) {
      _errorState = ErrorState(
        error: PlayerError(code: 'INIT_ERROR', message: "episode index error"),
      );
      _errorCtrl.add(_errorState);
      return;
    }
    try {
      VideoEpisode ve = episodes.elementAt(episodeIndex ?? 0);

      await _player.initialize(ve.qualities[qualityIndex ?? 0].source);
      _lifecycleState = _lifecycleState.copyWith(isInitialized: true);

      _lifecycleCtrl.add(_lifecycleState);
    } catch (e) {
      _errorState = ErrorState(
        error: PlayerError(code: 'INIT_ERROR', message: e.toString()),
      );
      logger.e(_errorState.error);
      _errorCtrl.add(_errorState);
    }
  }

  Future<void> play() {
    _lifecycleState = _lifecycleState.copyWith(
      isPlaying: true,
      status: PlaybackStatus.playing,
    );
    _lifecycleCtrl.add(_lifecycleState);

    return _player.play();
  }

  Future<void> pause() {
    _lifecycleState = _lifecycleState.copyWith(
      isPlaying: false,
      status: PlaybackStatus.paused,
    );
    _lifecycleCtrl.add(_lifecycleState);
    return _player.pause();
  }

  Future<void> resetPlayer() async {
    await _player.reset();
  }

  Future<void> seek(Duration pos, SeekSource source) {
    _positionState = _positionState.copyWith(
      isSeeking: true,
      seekTarget: pos,
      seekSource: source,
      position: pos,
    );
    _emitPositionState(_positionState);
    return _player.seek(pos);
  }

  // ===============================================================
  // Features (Switching, Seek Prep)
  // ===============================================================

  void refreshState() {
    _lifecycleCtrl.add(_lifecycleState);
    _positionCtrl.add(_positionState);
    _switchingCtrl.add(_switching);
    _errorCtrl.add(_errorState);
  }

  void startSwitching(String targetQualityLabel) {
    _switching = SwitchingState(
      isSwitching: true,
      targetQualityLabel: targetQualityLabel,
    );
    _switchingCtrl.add(_switching);
  }

  void endSwitching() {
    _switching = const SwitchingState();
    _switchingCtrl.add(_switching);
  }

  void beforeSeek() {
    _lifecycleState = _lifecycleState.copyWith(
      wasPlayingBeforeSeek: _lifecycleState.isPlaying,
    );
    _lifecycleCtrl.add(_lifecycleState);
  }

  // ===============================================================
  // Rendering
  // ===============================================================

  Widget renderPlayer({Key? key}) {
    return _player.render(key: key);
  }

  // ===============================================================
  // Internal Stream Binding
  // ===============================================================

  void _bindPlayerStreams() {
    _player.positionStream.listen((pos) {
      if (_positionState.isSeeking && _positionState.seekTarget != null) {
        final delta = (pos - _positionState.seekTarget!).abs();

        // Seek completion threshold
        if (delta < const Duration(milliseconds: 800)) {
          _emitPositionState(
            _positionState.copyWith(
              isSeeking: false,
              seekTarget: null,
              seekSource: null,
              position: pos,
              duration: _player.duration,
            ),
          );
        } else {
          return;
        }
      } else {
        _emitPositionState(
          _positionState.copyWith(position: pos, duration: _player.duration),
        );
      }
      // Loop check
      if (_config.behavior.loop &&
          _player.duration > Duration.zero &&
          pos >= _player.duration) {
        seek(Duration.zero, SeekSource.external);
        play();
      }
    });

    _player.bufferedStream.listen((buffered) {
      _positionState = _positionState.copyWith(buffered: buffered);
      _positionCtrl.add(_positionState);
    });

    _player.errorStream.listen((err) {
      if (err != null) {
        _errorState = ErrorState(
          error: PlayerError(code: err.code, message: err.message),
        );
        _errorCtrl.add(_errorState);
      }
    });

    _player.videoSizeStream.listen((size) {
      _lifecycleState = _lifecycleState.copyWith(
        videoWidth: size?.width,
        videoHeight: size?.height,
      );
      _lifecycleCtrl.add(_lifecycleState);
    });
  }

  void _emitPositionState(PlaybackPositionState next) {
    _positionState = next;
    _positionCtrl.add(next);
  }

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    _positionTimer?.cancel();
    _lifecycleCtrl.close();
    _positionCtrl.close();
    _errorCtrl.close();
    _switchingCtrl.close();
  }
}

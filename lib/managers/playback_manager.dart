import 'dart:async';
import 'package:flutter/widgets.dart';

import '../core/interfaces/video_player.dart';
import '../core/lifecycle/lifecycle_token.dart';
import '../core/lifecycle/safe_stream.dart';
import '../core/model/model.dart';
import '../core/state/states.dart';
import '../utils/log.dart';

/// Manages playback state and coordinates with the underlying video player.
///
/// This is an internal implementation class. SDK users should interact
/// with [PlayerController] instead.
class PlaybackManager with LifecycleTokenProvider {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final PlayerConfig _config;
  final IVideoPlayer _player;

  Timer? _positionTimer;
  final List<StreamSubscription> _subscriptions = [];

  // Lifecycle flag
  bool _isDisposed = false;

  // Internal State Cache
  PlaybackLifecycleState _lifecycleState = const PlaybackLifecycleState();
  PlaybackPositionState _positionState = const PlaybackPositionState();
  ErrorState _errorState = const ErrorState();
  SwitchingState _switching = const SwitchingState();

  // State Notifiers (for high-performance UI updates)
  late final ValueNotifier<PlaybackPositionState> positionNotifier;

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
    positionNotifier = ValueNotifier<PlaybackPositionState>(_positionState);
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
  ErrorState get errorState => _errorState;

  // ===============================================================
  // Initialization & Playback Control
  // ===============================================================

  Future<void> initialize({
    VideoMetadata? video,
    required List<VideoEpisode> episodes,
    int? episodeIndex,
    int? qualityIndex,
  }) async {
    final token = lifecycleToken;
    if (!token.isAlive) return;

    if (episodes.isEmpty ||
        episodes.elementAtOrNull(episodeIndex ?? 0) == null) {
      _errorState = ErrorState(
        error: PlayerError(code: 'INIT_ERROR', message: "episode index error"),
      );
      safeEmit(_errorCtrl, _errorState, token);
      return;
    }
    try {
      VideoEpisode ve = episodes.elementAt(episodeIndex ?? 0);

      await _player.initialize(ve.qualities[qualityIndex ?? 0].source);

      if (!token.isAlive) return;

      _lifecycleState = _lifecycleState.copyWith(isInitialized: true);
      safeEmit(_lifecycleCtrl, _lifecycleState, token);
    } catch (e) {
      _errorState = ErrorState(
        error: PlayerError(code: 'INIT_ERROR', message: e.toString()),
      );
      logger.e(_errorState.error);
      safeEmit(_errorCtrl, _errorState, token);
    }
  }

  Future<void> play() {
    if (_isDisposed) return Future.value();

    _lifecycleState = _lifecycleState.copyWith(
      isPlaying: true,
      status: PlaybackStatus.playing,
    );
    if (!_lifecycleCtrl.isClosed) {
      _lifecycleCtrl.add(_lifecycleState);
    }

    return _player.play();
  }

  Future<void> pause() {
    if (_isDisposed) return Future.value();

    _lifecycleState = _lifecycleState.copyWith(
      isPlaying: false,
      status: PlaybackStatus.paused,
    );
    if (!_lifecycleCtrl.isClosed) {
      _lifecycleCtrl.add(_lifecycleState);
    }
    return _player.pause();
  }

  Future<void> resetPlayer() async {
    await _player.reset();
  }

  Future<void> seek(Duration pos, SeekSource source) {
    final token = lifecycleToken;
    if (!token.isAlive) return Future.value();

    _positionState = _positionState.copyWith(
      isSeeking: true,
      seekTarget: pos,
      seekSource: source,
      position: pos,
    );
    _emitPositionState(_positionState, token);
    return _player.seek(pos);
  }

  // ===============================================================
  // Features (Switching, Seek Prep)
  // ===============================================================

  void refreshState() {
    if (_isDisposed) return;

    if (!_lifecycleCtrl.isClosed) _lifecycleCtrl.add(_lifecycleState);
    if (!_positionCtrl.isClosed) _positionCtrl.add(_positionState);
    if (!_switchingCtrl.isClosed) _switchingCtrl.add(_switching);
    if (!_errorCtrl.isClosed) _errorCtrl.add(_errorState);
  }

  void startSwitching(String targetQualityLabel) {
    if (_isDisposed) return;

    _switching = SwitchingState(
      isSwitching: true,
      targetQualityLabel: targetQualityLabel,
    );
    if (!_switchingCtrl.isClosed) {
      _switchingCtrl.add(_switching);
    }
  }

  void endSwitching() {
    if (_isDisposed) return;

    _switching = const SwitchingState();
    if (!_switchingCtrl.isClosed) {
      _switchingCtrl.add(_switching);
    }
  }

  void beforeSeek() {
    if (_isDisposed) return;
    _lifecycleState = _lifecycleState.copyWith(
      wasPlayingBeforeSeek: _lifecycleState.isPlaying,
    );
    if (!_lifecycleCtrl.isClosed) {
      _lifecycleCtrl.add(_lifecycleState);
    }
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
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        final token = lifecycleToken;
        if (!token.isAlive) return;

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
              token,
            );
          } else {
            return;
          }
        } else {
          _emitPositionState(
            _positionState.copyWith(position: pos, duration: _player.duration),
            token,
          );
        }
        // Loop check
        if (_config.behavior.loop &&
            _player.duration > Duration.zero &&
            pos >= _player.duration) {
          seek(Duration.zero, SeekSource.external);
          play();
        }
      }),
    );

    _subscriptions.add(
      _player.bufferedStream.listen((buffered) {
        final token = lifecycleToken;
        if (!token.isAlive) return;

        _positionState = _positionState.copyWith(buffered: buffered);
        positionNotifier.value = _positionState;
        safeEmit(_positionCtrl, _positionState, token);
      }),
    );

    _subscriptions.add(
      _player.errorStream.listen((err) {
        final token = lifecycleToken;
        if (!token.isAlive) return;

        if (err != null) {
          _errorState = ErrorState(
            error: PlayerError(code: err.code, message: err.message),
          );
          safeEmit(_errorCtrl, _errorState, token);
        }
      }),
    );

    _subscriptions.add(
      _player.videoSizeStream.listen((size) {
        final token = lifecycleToken;
        if (!token.isAlive) return;

        _lifecycleState = _lifecycleState.copyWith(
          videoWidth: size?.width,
          videoHeight: size?.height,
        );
        safeEmit(_lifecycleCtrl, _lifecycleState, token);
      }),
    );
  }

  void _emitPositionState(PlaybackPositionState next, LifecycleToken token) {
    if (!token.isAlive) return;

    _positionState = next;
    positionNotifier.value = next;
    safeEmit(_positionCtrl, next, token);
  }

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    invalidateLifecycle();
    _isDisposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _positionTimer?.cancel();
    positionNotifier.dispose();
    _lifecycleCtrl.close();
    _positionCtrl.close();
    _errorCtrl.close();
    _switchingCtrl.close();
  }
}

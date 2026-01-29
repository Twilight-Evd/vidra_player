import 'dart:async';

import '../core/interfaces/video_player.dart';
import '../core/lifecycle/lifecycle_token.dart';

import '../core/state/buffering.dart';

class BufferingManager with LifecycleTokenProvider {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final IVideoPlayer _player;

  final _bufferingCtrl = StreamController<BufferingState>.broadcast();
  BufferingState _state = const BufferingState();

  // Lifecycle flag and subscription
  bool _isDisposed = false;
  StreamSubscription? _bufferingSub;

  // ===============================================================
  // Construction
  // ===============================================================

  BufferingManager({required IVideoPlayer player}) : _player = player {
    _bindPlayerStreams();
  }

  void _bindPlayerStreams() {
    _bufferingSub = _player.bufferingStream.listen((isBuffering) {
      if (_isDisposed) return; // Guard listener callback

      _state = BufferingState(isBuffering: isBuffering);
      if (!_bufferingCtrl.isClosed) {
        _bufferingCtrl.add(_state);
      }
    });
  }

  // ===============================================================
  // Stream & State Accessors
  // ===============================================================

  Stream<BufferingState> get bufferingStream => _bufferingCtrl.stream;
  BufferingState get state => _state;

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    invalidateLifecycle();
    _isDisposed = true;
    _bufferingSub?.cancel();
    _bufferingCtrl.close();
  }
}

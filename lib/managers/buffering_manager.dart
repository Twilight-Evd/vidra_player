import 'dart:async';

import '../core/interfaces/video_player.dart';
import '../core/state/buffering.dart';

class BufferingManager {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final IVideoPlayer _player;

  final _bufferingCtrl = StreamController<BufferingState>.broadcast();
  BufferingState _state = const BufferingState();

  // ===============================================================
  // Construction
  // ===============================================================

  BufferingManager({required IVideoPlayer player}) : _player = player {
    _bindPlayerStreams();
  }

  void _bindPlayerStreams() {
    _player.bufferingStream.listen((isBuffering) {
      _state = BufferingState(isBuffering: isBuffering);
      _bufferingCtrl.add(_state);
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
    _bufferingCtrl.close();
  }
}

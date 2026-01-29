import '../../core/interfaces/window_delegate.dart';

/// A default no-op delegate if none is provided.
class NoneWindowDelegate implements WindowDelegate {
  const NoneWindowDelegate();

  @override
  Future<void> enterFullscreen() async {}

  @override
  Future<void> exitFullscreen() async {}

  @override
  Future<void> toggleFullscreen() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> maximize() async {}

  @override
  Future<void> restore() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> setTitle(String title) async {}

  @override
  Future<void> enterPip() async {}

  @override
  Future<void> exitPip() async {}
}

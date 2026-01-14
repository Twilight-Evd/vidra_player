import 'dart:async';
import 'package:flutter/material.dart';

/// Window events
@immutable
class WindowEvent {
  final WindowEventType type;
  final DateTime timestamp;
  final dynamic data;

  WindowEvent({required this.type, DateTime? timestamp, this.data})
    : timestamp = timestamp ?? DateTime.now();
}

enum WindowEventType {
  focusGained,
  focusLost,
  minimized,
  restored,
  maximized,
  fullscreenEntered,
  fullscreenExited,
  pictureInPictureEntered,
  pictureInPictureExited,
  moved,
  resized,
  closed,
  visibilityChanged,
}

/// Window event manager
/// Refactored to only observe lifecycle events.
/// Actual window operations are now delegated via WindowDelegate in PlayerController.
class WindowEventManager {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final StreamController<WindowEvent> _eventController =
      StreamController<WindowEvent>.broadcast();

  bool _isDisposed = false;

  // ===============================================================
  // Construction
  // ===============================================================

  WindowEventManager() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
  }

  // ===============================================================
  // Stream Accessors
  // ===============================================================

  Stream<WindowEvent> get eventStream => _eventController.stream;

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    _isDisposed = true;
    _eventController.close();
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final WindowEventManager _manager;

  _AppLifecycleObserver(this._manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_manager._isDisposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.focusGained),
        );
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.restored),
        );
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.visibilityChanged, data: true),
        );
        break;
      case AppLifecycleState.inactive:
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.focusLost),
        );
        break;
      case AppLifecycleState.paused:
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.minimized),
        );
        break;
      case AppLifecycleState.hidden:
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.visibilityChanged, data: false),
        );
        break;
      case AppLifecycleState.detached:
        _manager._eventController.add(
          WindowEvent(type: WindowEventType.closed),
        );
        break;
    }
  }
}

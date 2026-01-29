// platform/key_event_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/player_controller.dart';

/// Keyboard event handler
class KeyEventHandler {
  final PlayerController _controller;
  final StreamController<KeyEvent> _keyEventController =
      StreamController<KeyEvent>.broadcast();

  final Map<String, bool> _pressedKeys = {};
  Timer? _keyRepeatTimer;
  String? _lastRepeatedKey;
  DateTime? _lastKeyPressTime;

  // Key repeat configuration
  static const Duration _keyRepeatDelay = Duration(milliseconds: 500);
  static const Duration _keyRepeatInterval = Duration(milliseconds: 100);

  KeyEventHandler(this._controller);

  Stream<KeyEvent> get keyEventStream => _keyEventController.stream;

  /// Handle raw keyboard event
  KeyEventResult handleKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      return _handleKeyDown(event, keysPressed);
    } else if (event is KeyUpEvent) {
      return _handleKeyUp(event, keysPressed);
    } else if (event is KeyRepeatEvent) {
      return _handleKeyRepeat(event, keysPressed);
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyDown(
    KeyDownEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = _getKeyString(event.logicalKey);

    // Record key press time
    _lastKeyPressTime = DateTime.now();

    // Update key state
    _pressedKeys[key] = true;

    // Send event
    _keyEventController.add(event);

    // Handle shortcut
    final result = _handleShortcut(key, keysPressed);

    // Start key repeat (for specific keys)
    if (_shouldRepeatKey(key)) {
      _startKeyRepeat(key);
    }

    return result;
  }

  KeyEventResult _handleKeyUp(
    KeyUpEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = _getKeyString(event.logicalKey);

    // Update key state
    _pressedKeys.remove(key);

    // Send event
    _keyEventController.add(event);

    // Stop key repeat
    if (key == _lastRepeatedKey) {
      _stopKeyRepeat();
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _handleKeyRepeat(
    KeyRepeatEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = _getKeyString(event.logicalKey);

    // Send event
    _keyEventController.add(event);

    // Handle shortcut for repeated keys
    return _handleShortcut(key, keysPressed);
  }

  KeyEventResult _handleShortcut(
    String key,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Check modifier keys
    final hasCtrl =
        keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        keysPressed.contains(LogicalKeyboardKey.controlRight);
    final hasShift =
        keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight);
    final hasAlt =
        keysPressed.contains(LogicalKeyboardKey.altLeft) ||
        keysPressed.contains(LogicalKeyboardKey.altRight);
    final hasMeta =
        keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
        keysPressed.contains(LogicalKeyboardKey.metaRight);

    // Build shortcut string
    final shortcut = _buildShortcutString(
      key,
      hasCtrl,
      hasShift,
      hasAlt,
      hasMeta,
    );

    // Handle shortcut
    _controller.handleKeyboardShortcut(shortcut);

    return KeyEventResult.handled;
  }

  String _buildShortcutString(
    String key,
    bool hasCtrl,
    bool hasShift,
    bool hasAlt,
    bool hasMeta,
  ) {
    final parts = <String>[];

    if (hasCtrl) parts.add('ctrl');
    if (hasShift) parts.add('shift');
    if (hasAlt) parts.add('alt');
    if (hasMeta) parts.add('meta');
    parts.add(key);

    return parts.join('+');
  }

  String _getKeyString(LogicalKeyboardKey key) {
    // Convert LogicalKeyboardKey to string
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    if (key == LogicalKeyboardKey.escape) return 'escape';
    if (key == LogicalKeyboardKey.tab) return 'tab';
    if (key == LogicalKeyboardKey.backspace) return 'backspace';
    if (key == LogicalKeyboardKey.delete) return 'delete';
    if (key == LogicalKeyboardKey.home) return 'home';
    if (key == LogicalKeyboardKey.end) return 'end';
    if (key == LogicalKeyboardKey.pageUp) return 'page_up';
    if (key == LogicalKeyboardKey.pageDown) return 'page_down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'arrow_left';
    if (key == LogicalKeyboardKey.arrowRight) return 'arrow_right';
    if (key == LogicalKeyboardKey.arrowUp) return 'arrow_up';
    if (key == LogicalKeyboardKey.arrowDown) return 'arrow_down';
    if (key == LogicalKeyboardKey.f1) return 'f1';
    if (key == LogicalKeyboardKey.f2) return 'f2';
    if (key == LogicalKeyboardKey.f3) return 'f3';
    if (key == LogicalKeyboardKey.f4) return 'f4';
    if (key == LogicalKeyboardKey.f5) return 'f5';
    if (key == LogicalKeyboardKey.f6) return 'f6';
    if (key == LogicalKeyboardKey.f7) return 'f7';
    if (key == LogicalKeyboardKey.f8) return 'f8';
    if (key == LogicalKeyboardKey.f9) return 'f9';
    if (key == LogicalKeyboardKey.f10) return 'f10';
    if (key == LogicalKeyboardKey.f11) return 'f11';
    if (key == LogicalKeyboardKey.f12) return 'f12';

    // Letter keys
    if (key.keyLabel.length == 1 &&
        key.keyLabel.codeUnitAt(0) >= 65 &&
        key.keyLabel.codeUnitAt(0) <= 90) {
      return key.keyLabel.toLowerCase();
    }

    // Number keys
    if (key.keyLabel.length == 1 &&
        key.keyLabel.codeUnitAt(0) >= 48 &&
        key.keyLabel.codeUnitAt(0) <= 57) {
      return key.keyLabel;
    }

    // Symbol keys
    if (key == LogicalKeyboardKey.comma) return 'comma';
    if (key == LogicalKeyboardKey.period) return 'period';
    if (key == LogicalKeyboardKey.slash) return 'slash';
    if (key == LogicalKeyboardKey.semicolon) return 'semicolon';
    if (key == LogicalKeyboardKey.bracketLeft) return 'bracket_left';
    if (key == LogicalKeyboardKey.bracketRight) return 'bracket_right';
    if (key == LogicalKeyboardKey.backquote) return 'backquote';
    if (key == LogicalKeyboardKey.backslash) return 'backslash';
    if (key == LogicalKeyboardKey.minus) return 'minus';
    if (key == LogicalKeyboardKey.equal) return 'equal';
    if (key == LogicalKeyboardKey.quote) return 'quote';

    return key.keyLabel;
  }

  bool _shouldRepeatKey(String key) {
    // Which keys should support repeat
    return [
      'arrow_left',
      'arrow_right',
      'arrow_up',
      'arrow_down',
      'j',
      'l',
      'k',
      'i',
    ].contains(key);
  }

  void _startKeyRepeat(String key) {
    _stopKeyRepeat();
    _lastRepeatedKey = key;

    _keyRepeatTimer = Timer(_keyRepeatDelay, () {
      _keyRepeatTimer = Timer.periodic(_keyRepeatInterval, (timer) {
        _controller.handleKeyboardShortcut(key);
      });
    });
  }

  void _stopKeyRepeat() {
    _keyRepeatTimer?.cancel();
    _keyRepeatTimer = null;
    _lastRepeatedKey = null;
  }

  /// Check key combination
  bool isKeyCombinationPressed(List<String> keys) {
    for (final key in keys) {
      if (!_pressedKeys.containsKey(key) || !_pressedKeys[key]!) {
        return false;
      }
    }
    return true;
  }

  /// Get time since last key press
  Duration? get timeSinceLastKeyPress {
    if (_lastKeyPressTime == null) return null;
    return DateTime.now().difference(_lastKeyPressTime!);
  }

  /// Clean up resources
  void dispose() {
    _stopKeyRepeat();
    _keyEventController.close();
  }
}

/// Global keyboard event handler
class GlobalKeyEventHandler {
  static final GlobalKeyEventHandler _instance =
      GlobalKeyEventHandler._internal();

  final Map<String, KeyEventHandler> _handlers = {};
  final StreamController<GlobalKeyEvent> _globalKeyEventController =
      StreamController<GlobalKeyEvent>.broadcast();

  factory GlobalKeyEventHandler() {
    return _instance;
  }

  GlobalKeyEventHandler._internal();

  /// Register player controller
  void registerController(String id, PlayerController controller) {
    final handler = KeyEventHandler(controller);
    _handlers[id] = handler;

    // Listen to key events
    handler.keyEventStream.listen((event) {
      _globalKeyEventController.add(GlobalKeyEvent(playerId: id, event: event));
    });
  }

  /// Unregister player controller
  void unregisterController(String id) {
    final handler = _handlers.remove(id);
    handler?.dispose();
  }

  /// Get global key event stream
  Stream<GlobalKeyEvent> get globalKeyEventStream =>
      _globalKeyEventController.stream;

  /// Handle global keyboard event
  KeyEventResult handleGlobalKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Forward event to all registered handlers
    for (final handler in _handlers.values) {
      final result = handler.handleKeyEvent(event, keysPressed);
      if (result == KeyEventResult.handled) {
        return result;
      }
    }

    return KeyEventResult.ignored;
  }

  void dispose() {
    for (final handler in _handlers.values) {
      handler.dispose();
    }
    _handlers.clear();
    _globalKeyEventController.close();
  }
}

class GlobalKeyEvent {
  final String playerId;
  final KeyEvent event;

  const GlobalKeyEvent({required this.playerId, required this.event});
}

/// Keyboard shortcut configuration
/// Note: Shortcut description localization is handled via VidraLocalization in controller layer
class KeyboardShortcuts {
  // Shortcut mapping reserved for internal logic, description text moved to localization
  static const Map<String, String> defaultShortcuts = {
    'space': 'play_pause',
    'f': 'fullscreen',
    'm': 'mute',
    'arrow_left': 'seek_backward_5s',
    'arrow_right': 'seek_forward_5s',
    'arrow_up': 'volume_up',
    'arrow_down': 'volume_down',
    'j': 'seek_backward_10s',
    'l': 'seek_forward_10s',
    'k': 'play_pause',
    'i': 'picture_in_picture',
    'escape': 'exit_fullscreen_or_menu',
    '>': 'next_episode',
    '<': 'previous_episode',
    'ctrl+arrow_left': 'seek_backward_30s',
    'ctrl+arrow_right': 'seek_forward_30s',
    'shift+arrow_left': 'seek_backward_60s',
    'shift+arrow_right': 'seek_forward_60s',
    'ctrl+f': 'search',
    'ctrl+s': 'screenshot',
    'ctrl+d': 'download',
  };

  static String getShortcutKey(String shortcut) {
    return defaultShortcuts[shortcut] ?? 'unknown_shortcut';
  }
}

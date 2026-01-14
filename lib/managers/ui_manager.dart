import 'dart:async';
import 'package:flutter/material.dart';

import '../core/interfaces/window_delegate.dart';
import '../core/model/player_behavior.dart';
import '../core/state/states.dart';

/// Manages UI visibility, interaction tracking, and auto-hide behavior.
///
/// This is an internal implementation class. SDK users should interact
/// with [PlayerController] instead.
class UIStateManager {
  // ===============================================================
  // Dependencies & Configuration
  // ===============================================================

  final WindowDelegate? _windowDelegate;
  final PlayerBehavior _behavior;

  // ===============================================================
  // State Streams & Controllers
  // ===============================================================

  final StreamController<UIVisibilityState> _visibilityCtrl =
      StreamController<UIVisibilityState>.broadcast();
  final StreamController<InteractionState> _interactionController =
      StreamController<InteractionState>.broadcast();
  final StreamController<ViewModeState> _viewModeCtrl =
      StreamController<ViewModeState>.broadcast();

  // Current State
  UIVisibilityState _visibility = const UIVisibilityState();
  InteractionState _interaction = const InteractionState();
  ViewModeState _viewMode = const ViewModeState();

  // Internal Flags - Window
  bool _windowHasFocus = true;
  bool _windowIsMinimized = false;

  // Internal Flags - Playback
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // ===============================================================
  // Timers
  // ===============================================================

  Timer? _autoHideTimer;
  Timer? _mouseHideTimer;
  Timer? _hoverTimer;
  Timer? _hoverProgressTimer;
  Timer? _interactionDebounceTimer;
  Timer? _skipNotificationTimer;
  Timer? _seekFeedbackTimer;

  // ===============================================================
  // Construction & Initialization
  // ===============================================================

  UIStateManager({
    required PlayerBehavior behavior,
    WindowDelegate? windowDelegate,
  }) : _behavior = behavior,
       _windowDelegate = windowDelegate;

  // ===============================================================
  // State Accessors
  // ===============================================================

  Stream<UIVisibilityState> get visibilityStream => _visibilityCtrl.stream;
  Stream<InteractionState> get interactionStream =>
      _interactionController.stream;
  Stream<ViewModeState> get viewModeStream => _viewModeCtrl.stream;

  UIVisibilityState get currentVisibility => _visibility;
  InteractionState get currentInteraction => _interaction;
  ViewModeState get currentViewMode => _viewMode;

  // ===============================================================
  // Public Control API (Visibility)
  // ===============================================================

  /// Force show controls (e.g., user interaction)
  void showControlsForced({Duration duration = const Duration(seconds: 5)}) {
    if (_isDisposed) return;

    // Cancel previous timer
    _cancelAutoHideTimer();

    // Show controls and mouse cursor
    _updateVisibility(
      _visibility.copyWith(showControls: true, showMouseCursor: true),
    );

    // If duration is specified, set timer to auto hide
    if (duration > Duration.zero) {
      _autoHideTimer = Timer(duration, () {
        if (_isDisposed ||
            _visibility.showEpisodeList ||
            _visibility.showResumeDialog ||
            _visibility.showReplayDialog ||
            _visibility.showErrorDialog) {
          return;
        }

        // Only auto hide when playing and window has focus
        if (_isPlaying && _windowHasFocus && _shouldAutoHide()) {
          _hideControlsAndMouse();
        }
      });
    }
  }

  /// Show controls persistently (no auto hide)
  void showControlsPersistently() {
    if (_isDisposed) return;
    _showControlsPersistently(); // internal impl
  }

  /// Show controls temporarily (default 3 seconds auto hide)
  void showControlsTemporarily() {
    // print("[UI DEBUG] [UIManager ${identityHashCode(this)}] showControlsTemporarily"); // Verbose
    if (_isDisposed) return;
    _showControlsTemporarily(); // internal impl
  }

  /// Hide controls and mouse immediately
  void hideControlsImmediately() {
    if (_isDisposed) return;
    _hideControlsAndMouse();
  }

  /// Toggle control visibility
  void toggleControls() {
    if (_isDisposed) return;

    if (_visibility.showControls) {
      hideControlsImmediately();
    } else {
      showControlsForced();
    }
  }

  /// Set control visibility directly
  void setControlsVisible(bool visible, {bool keepMouse = true}) {
    if (_isDisposed) return;

    _updateVisibility(
      _visibility.copyWith(
        showControls: visible,
        showMouseCursor: keepMouse ? true : _visibility.showMouseCursor,
      ),
    );

    if (visible) {
      _cancelAutoHideTimer();
      if (_isPlaying && _windowHasFocus) {
        _resetAutoHideTimer();
      }
    }
  }

  /// Refresh UI state (trigger rebuild)
  void refresh() {
    if (_isDisposed) return;
    _updateVisibility(_visibility);
  }

  // ===============================================================
  // Public Mouse API
  // ===============================================================

  /// Show mouse cursor
  void showMouse() {
    if (_isDisposed || !_behavior.hideMouseWhenIdle) return;

    _mouseHideTimer?.cancel();

    if (!_visibility.showMouseCursor) {
      _updateVisibility(_visibility.copyWith(showMouseCursor: true));
    }
  }

  /// Hide mouse cursor
  void hideMouse() {
    if (_isDisposed) return;
    _hideMouse(); // internal impl
  }

  /// Show mouse cursor temporarily (auto hide)
  void showMouseTemporarily() {
    if (_isDisposed) return;
    _showMouseTemporarily(); // internal impl
  }

  // ===============================================================
  // Event Handlers (Mouse, Touch, Keyboard)
  // ===============================================================

  /// Handle mouse move
  void handleMouseMove(Offset position) {
    if (_isDisposed) return;

    final now = DateTime.now();

    _interaction = _interaction.copyWith(
      lastMouseMove: now,
      isMouseActive: true,
      lastMousePosition: position,
    );

    _emitInteraction();

    // Reset auto-hide timer
    _resetAutoHideTimer();

    // Show mouse cursor
    _showMouseTemporarily();

    // If playing and window has focus, show controls
    if (_shouldShowControlsOnMouseMove()) {
      _showControlsTemporarily();
    }

    // Start hover timer (if mouse is over control area)
    _startHoverTimerIfNeeded();
  }

  /// Handle mouse enter controls
  void handleMouseEnterControls() {
    if (_isDisposed) return;

    _interaction = _interaction.copyWith(isHoveringControls: true);

    _emitInteraction();

    // Immediately show controls (if should show)
    if (_shouldShowControlsOnHover()) {
      _showControlsTemporarily();
    }
  }

  /// Handle mouse leave controls
  void handleMouseLeaveControls() {
    if (_isDisposed) return;

    _interaction = _interaction.copyWith(isHoveringControls: false);

    _emitInteraction();

    _cancelHoverTimer();
  }

  /// Handle mouse enter video
  void handleMouseEnterVideo() {
    if (_isDisposed) return;
    _interaction = _interaction.copyWith(isHoveringVideo: true);
    _emitInteraction();
  }

  /// Handle mouse leave video
  void handleMouseLeaveVideo() {
    if (_isDisposed) return;

    _interaction = _interaction.copyWith(isHoveringVideo: false);
    _emitInteraction();

    // If mouse completely leaves player area, hide mouse cursor
    if (!_interaction.isHoveringControls) {
      _hideMouse();
    }
  }

  /// Handle keyboard interaction
  void handleKeyboardInteraction() {
    if (_isDisposed) return;

    final now = DateTime.now();

    _interaction = _interaction.copyWith(lastKeyboardInteraction: now);

    _emitInteraction();

    // Show controls
    _showControlsTemporarily();
    _resetAutoHideTimer();
  }

  /// Handle touch start
  void handleTouchStart(int pointerId) {
    if (_isDisposed) return;

    final now = DateTime.now();
    final activePointers = Set<int>.from(_interaction.activePointers);
    activePointers.add(pointerId);

    _interaction = _interaction.copyWith(
      lastTouchInteraction: now,
      activePointers: activePointers,
    );

    _emitInteraction();

    // Show controls
    _showControlsTemporarily();
    _resetAutoHideTimer();
  }

  /// Handle touch end
  void handleTouchEnd(int pointerId) {
    if (_isDisposed) return;

    final activePointers = Set<int>.from(_interaction.activePointers);
    activePointers.remove(pointerId);

    _interaction = _interaction.copyWith(activePointers: activePointers);

    _emitInteraction();
  }

  /// Handle keyboard shortcuts
  void handleShortcutPressed(String shortcut) {
    if (_isDisposed) return;

    final now = DateTime.now();
    _interaction = _interaction.copyWith(lastKeyboardInteraction: now);
    _emitInteraction();

    // Handle different UI responses based on shortcuts
    switch (shortcut) {
      case 'space':
        // Space: Show controls
        showControlsForced(duration: const Duration(seconds: 3));
        break;
      case 'f':
        // F: Toggle fullscreen, show controls
        showControlsForced(duration: const Duration(seconds: 3));
        break;
      case 'escape':
        // Escape: Hide controls (if playing)
        if (_isPlaying && _windowHasFocus) {
          hideControlsImmediately();
        }
        // Escape can also close various panels
        if (_visibility.showEpisodeList) {
          hideEpisodeList();
        }
        break;
      default:
        // Other shortcuts: Show controls
        showControlsForced(duration: const Duration(seconds: 3));
        break;
    }
  }

  // ===============================================================
  // Window & Lifecycle Logic
  // ===============================================================

  void updateWindowState({bool? hasFocus, bool? isMinimized}) {
    if (_isDisposed) return;

    bool changed = false;
    if (hasFocus != null && hasFocus != _windowHasFocus) {
      _windowHasFocus = hasFocus;
      changed = true;
    }
    if (isMinimized != null && isMinimized != _windowIsMinimized) {
      _windowIsMinimized = isMinimized;
      changed = true;
    }

    if (changed) {
      _evaluateVisibility();
    }
  }

  void updatePlaybackState({
    bool? isPlaying,
    bool? isBuffering,
    bool? isInitialized,
  }) {
    if (_isDisposed) return;

    bool changed = false;
    if (isPlaying != null && isPlaying != _isPlaying) {
      _isPlaying = isPlaying;
      changed = true;
    }
    if (isBuffering != null && isBuffering != _isBuffering) {
      _isBuffering = isBuffering;
      changed = true;
    }
    if (isInitialized != null && isInitialized != _isInitialized) {
      _isInitialized = isInitialized;
      changed = true;
    }

    if (changed) {
      _evaluateVisibility();
    }
  }

  void handleWindowResize(Size newSize) {
    if (_isDisposed) return;
    _evaluateVisibility();
  }

  void handleQualitySwitchStart() {
    if (_isDisposed) return;

    _updateVisibility(
      _visibility.copyWith(showControls: true, showMouseCursor: true),
    );
    _cancelAutoHideTimer();
  }

  void handleQualitySwitchComplete() {
    if (_isDisposed) return;
    if (_isPlaying && _windowHasFocus) {
      _resetAutoHideTimer();
    }
  }

  void handleFullscreenToggle() {
    if (_isDisposed || _windowDelegate == null) return;

    _evaluateVisibility();

    if (_viewMode.isFullscreen) {
      _windowDelegate.exitFullscreen();
    } else {
      _windowDelegate.enterFullscreen();
    }
    _viewMode = _viewMode.copyWith(isFullscreen: !_viewMode.isFullscreen);
    _viewModeCtrl.add(_viewMode);
  }

  void handlePictureInPicture() {
    if (_isDisposed || _windowDelegate == null) return;

    if (!_viewMode.isPip) {
      _hideAllUI();
    } else {
      _evaluateVisibility();
    }
    if (_viewMode.isPip) {
      _windowDelegate.exitPip();
    } else {
      _windowDelegate.enterPip();
    }
    _viewMode = _viewMode.copyWith(isPip: !_viewMode.isPip);
    _viewModeCtrl.add(_viewMode);
  }

  /// Reset all states (for restarting playback)
  void resetAllStates() {
    if (_isDisposed) return;

    clearAllTimers();
    _interaction = const InteractionState();

    _updateVisibility(
      _visibility.copyWith(
        showControls: false,
        showMouseCursor: true,
        showEpisodeList: false,
      ),
    );

    _evaluateVisibility();
  }

  /// Clear hover states
  void clearHoverStates() {
    if (_isDisposed) return;

    _interaction = _interaction.copyWith(
      isHoveringControls: false,
      isHoveringVideo: false,
    );

    _cancelHoverTimer();
    _emitInteraction();
  }

  // ===============================================================
  // Panel & Dialog Management
  // ===============================================================

  void showResumeDialog(ResumeState state) {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(
        showResumeDialog: true,
        showControls: false,
        showMouseCursor: false,
        resumeState: state,
      ),
    );
  }

  void hideResumeDialog() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(showResumeDialog: false, resumeState: null),
    );
  }

  void showReplayDialog(ResumeState state) {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(
        showReplayDialog: true,
        showControls: false,
        showMouseCursor: true,
        replayState: state,
      ),
    );
  }

  void hideReplayDialog() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(showReplayDialog: false, replayState: null),
    );
  }

  void showSkipIntroNotification() {
    if (_isDisposed) return;

    _skipNotificationTimer?.cancel();
    _updateVisibility(
      _visibility.copyWith(skipNotification: SkipNotificationType.intro),
    );

    _skipNotificationTimer = Timer(const Duration(seconds: 3), () {
      hideSkipNotification();
    });
  }

  void showSkipOutroNotification() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(skipNotification: SkipNotificationType.outro),
    );
  }

  void hideSkipNotification() {
    if (_isDisposed) return;

    _skipNotificationTimer?.cancel();
    if (_visibility.skipNotification != SkipNotificationType.none) {
      _updateVisibility(
        _visibility.copyWith(skipNotification: SkipNotificationType.none),
      );
    }
  }

  void showEpisodeList() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(
        showEpisodeList: true,
        showControls: true,
        showMouseCursor: true,
      ),
    );
    _cancelAutoHideTimer();
  }

  void hideEpisodeList() {
    if (_isDisposed) return;
    _updateVisibility(_visibility.copyWith(showEpisodeList: false));
    if (_isPlaying && _windowHasFocus) {
      _resetAutoHideTimer();
    }
  }

  void showErrorDialog() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(
        showErrorDialog: true,
        showControls: true,
        showMouseCursor: true,
      ),
    );
    _cancelAutoHideTimer();
  }

  void hideErrorDialog() {
    if (_isDisposed) return;
    _updateVisibility(_visibility.copyWith(showErrorDialog: false));
  }

  void showMoreMenu() {
    if (_isDisposed) return;
    _cancelAutoHideTimer();
  }

  void hideMoreMenu() {
    if (_isDisposed) return;
    _resetAutoHideTimer();
  }

  void showLoadingIndicator() {
    if (_isDisposed) return;
    _updateVisibility(
      _visibility.copyWith(showLoadingIndicator: true, showControls: true),
    );
  }

  void hideLoadingIndicator() {
    if (_isDisposed) return;
    _updateVisibility(_visibility.copyWith(showLoadingIndicator: false));
  }

  void showSeekFeedback(Duration amount) {
    if (_isDisposed) return;

    _seekFeedbackTimer?.cancel();

    // Accumulate if there's an existing feedback that hasn't expired
    final current = _visibility.seekFeedback ?? Duration.zero;
    final total = current + amount;

    // If total cancels out to zero, clear feedback
    if (total.inSeconds == 0) {
      _updateVisibility(_visibility.copyWith(forceClearSeekFeedback: true));
      return;
    }

    _updateVisibility(_visibility.copyWith(seekFeedback: total));

    // Reset timer (slightly longer to allow reading accumulated value)
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_isDisposed) return;
      _updateVisibility(_visibility.copyWith(forceClearSeekFeedback: true));
    });
  }

  // ===============================================================
  // Private Helper Methods
  // ===============================================================

  void _showMouseTemporarily() {
    if (_isDisposed || !_behavior.hideMouseWhenIdle) return;

    _mouseHideTimer?.cancel();

    // 显示鼠标指针
    if (!_visibility.showMouseCursor) {
      _updateVisibility(_visibility.copyWith(showMouseCursor: true));
    }

    // 设置隐藏计时
    _mouseHideTimer = Timer(_behavior.mouseHideDelay, () {
      if (_isDisposed) return;

      // 只有在播放中、没有交互、且控制面板隐藏时才隐藏鼠标
      if (_isPlaying &&
          !_interaction.isMouseActive &&
          !_visibility.showControls) {
        _updateVisibility(_visibility.copyWith(showMouseCursor: false));
      }
    });
  }

  void _hideMouse() {
    if (_isDisposed) return;

    _mouseHideTimer?.cancel();

    if (_visibility.showMouseCursor && _behavior.hideMouseWhenIdle) {
      _updateVisibility(_visibility.copyWith(showMouseCursor: false));
    }
  }

  void _showControlsTemporarily() {
    if (_isDisposed) return;

    // 取消之前的debounce计时器
    _interactionDebounceTimer?.cancel();

    // 使用防抖防止频繁更新
    _interactionDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (_isDisposed) return;

      _updateVisibility(
        _visibility.copyWith(showControls: true, showMouseCursor: true),
      );

      _resetAutoHideTimer();
    });
  }

  void _showControlsPersistently() {
    if (_isDisposed) return;

    _updateVisibility(
      _visibility.copyWith(showControls: true, showMouseCursor: true),
    );
    _cancelAutoHideTimer();
  }

  void _hideControlsAndMouse() {
    if (_isDisposed) return;

    _updateVisibility(
      _visibility.copyWith(showControls: false, showMouseCursor: false),
    );
    _cancelAutoHideTimer();
  }

  void _hideAllUI() {
    if (_isDisposed) return;

    _updateVisibility(const UIVisibilityState());

    _cancelAutoHideTimer();
    _mouseHideTimer?.cancel();
    _hoverTimer?.cancel();
    _hoverProgressTimer?.cancel();
  }

  void _startHoverTimerIfNeeded() {
    if (_isDisposed || !_behavior.showControlsOnHover) return;

    _hoverTimer?.cancel();

    if (_interaction.isHoveringVideo || _interaction.isHoveringControls) {
      _hoverTimer = Timer(_behavior.hoverShowDelay, () {
        if (_isDisposed) return;

        // 检查是否仍然在hover状态
        if ((_interaction.isHoveringVideo || _interaction.isHoveringControls) &&
            _isPlaying) {
          _showControlsTemporarily();
        }
      });

      // 更新hover持续时间
      _hoverProgressTimer?.cancel();
      _hoverProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }

        _interaction = _interaction.copyWith(
          hoverDuration:
              _interaction.hoverDuration + const Duration(milliseconds: 100),
        );

        _emitInteraction();

        // 如果hover超过5秒，重置计时
        if (_interaction.hoverDuration.inSeconds >= 5) {
          _interaction = _interaction.copyWith(hoverDuration: Duration.zero);
          _emitInteraction();
        }
      });
    }
  }

  void _cancelHoverTimer() {
    _hoverTimer?.cancel();
    _hoverProgressTimer?.cancel();

    _interaction = _interaction.copyWith(hoverDuration: Duration.zero);
    _emitInteraction();
  }

  bool _shouldShowControlsOnMouseMove() {
    return _behavior.showControlsOnHover && _isPlaying && !_viewMode.isPip;
  }

  bool _shouldShowControlsOnHover() {
    return _behavior.showControlsOnHover &&
        _isPlaying &&
        !_viewMode.isPip &&
        !_visibility.showControls;
  }

  bool _shouldAutoHide() {
    // 检查是否应该自动隐藏
    final interactionTime = _getLastInteractionTime();
    if (interactionTime != null) {
      final timeSinceInteraction = DateTime.now().difference(interactionTime);
      return timeSinceInteraction > _behavior.autoHideDelay;
    }

    // 根据状态判断 (不再强制要求 _windowHasFocus)
    return _isPlaying &&
        !_visibility.showEpisodeList &&
        !_visibility.showResumeDialog &&
        !_visibility.showErrorDialog;
  }

  DateTime? _getLastInteractionTime() {
    final times = [
      _interaction.lastMouseMove,
      _interaction.lastKeyboardInteraction,
      _interaction.lastTouchInteraction,
    ].whereType<DateTime>();

    // Find the latest DateTime
    return times.isNotEmpty
        ? times.reduce((a, b) => a.isAfter(b) ? a : b)
        : null;
  }

  void _evaluateVisibility() {
    final bool isMin = _windowIsMinimized;
    final bool isPip = _viewMode.isPip;

    if (_isDisposed) return;

    // 1. Critical visibility blockers (PiP or Minimized)
    // In PiP mode, we only hide everything if the controls aren't currently being shown.
    // This allows temporary/forced control visibility (like after a click) to persist.
    if (isMin || (isPip && !_visibility.showControls)) {
      _hideAllUI();
      return;
    }

    // 2. Not initialized
    if (!_isInitialized) {
      _hideControlsAndMouse();
      return;
    }

    // 3. Status-based persistence (Buffering or Paused)
    if (_isBuffering || !_isPlaying) {
      _showControlsPersistently();
      return;
    }

    // 4. Playback state (Playing)
    if (_isPlaying) {
      // Ensure auto-hide is running if controls are visible.
      // In PiP mode, we don't strictly require window focus to start the timer
      // because the user might be clicking the small window which quickly loses focus.
      if (_windowHasFocus || isPip) {
        if (_autoHideTimer == null || !_autoHideTimer!.isActive) {
          _resetAutoHideTimer();
        }
      } else {
        // Playing but background - usually allow it to hide if it was already hiding,
        // but don't force it to hide immediately unless it's a specific behavior
        // If we want it to hide in background, we'd call _hideControlsAndMouse() here.
        // But usually we just let the previous timer finish.
      }
    }
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();

    if (_isDisposed || !_isPlaying) {
      return;
    }

    if (_visibility.showEpisodeList ||
        _visibility.showResumeDialog ||
        _visibility.showReplayDialog ||
        _visibility.showErrorDialog) {
      return;
    }

    final delay = _viewMode.isFullscreen
        ? Duration(seconds: _behavior.autoHideDelay.inSeconds ~/ 2)
        : _behavior.autoHideDelay;

    _autoHideTimer = Timer(delay, () {
      if (_isDisposed || !_isPlaying) {
        return;
      }

      // 检查是否有最近的交互
      final lastInteraction = _getLastInteractionTime();
      if (lastInteraction != null) {
        final timeSinceInteraction = DateTime.now().difference(lastInteraction);
        if (timeSinceInteraction < delay) {
          // 还有交互，重新计时
          _resetAutoHideTimer();
          return;
        }
      }

      // 隐藏控制面板和鼠标
      _hideControlsAndMouse();
    });
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
  }

  void _updateVisibility(UIVisibilityState newVisibility) {
    if (_isDisposed || _visibility == newVisibility) return;

    _visibility = newVisibility;
    _emitVisibility();
  }

  void _emitVisibility() {
    if (_isDisposed) return;
    _visibilityCtrl.add(_visibility);
  }

  void _emitInteraction() {
    if (_isDisposed) return;
    _interactionController.add(_interaction);
  }

  void clearAllTimers() {
    _autoHideTimer?.cancel();
    _mouseHideTimer?.cancel();
    _hoverTimer?.cancel();
    _hoverProgressTimer?.cancel();
    _interactionDebounceTimer?.cancel();
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'isDisposed': _isDisposed,
      'windowHasFocus': _windowHasFocus,
      'windowIsFullscreen': _viewMode.isFullscreen,
      'windowIsMinimized': _windowIsMinimized,
      'windowIsPictureInPicture': _viewMode.isPip,
      'isPlaying': _isPlaying,
      'isBuffering': _isBuffering,
      'isInitialized': _isInitialized,
      'visibility': {
        'showControls': _visibility.showControls,
        'showMouseCursor': _visibility.showMouseCursor,
        'showEpisodeList': _visibility.showEpisodeList,
        'showResumeDialog': _visibility.showResumeDialog,
        'showErrorDialog': _visibility.showErrorDialog,
        'showLoadingIndicator': _visibility.showLoadingIndicator,
      },
      'interaction': {
        'lastMouseMove': _interaction.lastMouseMove?.toIso8601String(),
        'lastKeyboardInteraction': _interaction.lastKeyboardInteraction
            ?.toIso8601String(),
        'lastTouchInteraction': _interaction.lastTouchInteraction
            ?.toIso8601String(),
        'isHoveringControls': _interaction.isHoveringControls,
        'isHoveringVideo': _interaction.isHoveringVideo,
        'isMouseActive': _interaction.isMouseActive,
        'hoverDuration': _interaction.hoverDuration.inMilliseconds,
        'activePointers': _interaction.activePointers.length,
      },
      'timers': {
        'autoHideTimer': _autoHideTimer?.isActive ?? false,
        'mouseHideTimer': _mouseHideTimer?.isActive ?? false,
        'hoverTimer': _hoverTimer?.isActive ?? false,
        'hoverProgressTimer': _hoverProgressTimer?.isActive ?? false,
        'interactionDebounceTimer':
            _interactionDebounceTimer?.isActive ?? false,
      },
      'behavior': {
        'autoHideDelay': _behavior.autoHideDelay.inSeconds,
        'mouseHideDelay': _behavior.mouseHideDelay.inSeconds,
        'hoverShowDelay': _behavior.hoverShowDelay.inMilliseconds,
      },
    };
  }

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    _isDisposed = true;

    clearAllTimers();
    _skipNotificationTimer?.cancel();

    _visibilityCtrl.close();
    _interactionController.close();

    _viewModeCtrl.close();
  }
}

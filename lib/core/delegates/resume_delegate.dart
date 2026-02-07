// core/delegates/resume_delegate.dart

import 'dart:async';
import '../../managers/media_manager.dart';
import '../../managers/ui_manager.dart';
import '../state/states.dart';
import '../model/player_setting.dart';
import '../../utils/log.dart';

/// Internal delegate for handling playback resume logic from history.
///
/// This class extracts the complex resume-from-history decision making
/// from PlayerController to improve maintainability.
class ResumeDelegate {
  final MediaManager _mediaManager;
  final UIStateManager _uiManager;

  ResumeDelegate({
    required MediaManager mediaManager,
    required UIStateManager uiManager,
  }) : _mediaManager = mediaManager,
       _uiManager = uiManager;

  /// Check if playback should resume from history and handle appropriately.
  ///
  /// This method implements the smart resume logic:
  /// - If progress > 95%: Show replay dialog
  /// - If progress > 30s and < 95%: Show resume dialog
  /// - If progress < 30s: Auto-skip intro if enabled, or start from beginning
  Future<void> checkAndPromptResume({
    required int episodeIndex,
    required bool isInitialized,
    required bool isDisposed,
    required Future<void> Function(Duration, SeekSource) seek,
    required Future<void> Function() pause,
    required Future<void> Function() play,
    required PlayerSetting Function() getPlayerSetting,
    required bool autoPlay,
  }) async {
    if (isDisposed || !isInitialized) {
      return;
    }

    // Wait for player to stabilize (reduced from 500ms for better UX)
    await Future.delayed(const Duration(milliseconds: 100));

    // Re-check state after async
    if (isDisposed || _mediaManager.state.currentEpisodeIndex != episodeIndex) {
      return;
    }

    try {
      final currentEpisode = _mediaManager.state.currentEpisode;
      if (currentEpisode == null || _mediaManager.state.video == null) {
        // if (autoPlay) play();
        return;
      }

      final history = await _mediaManager.getEpisodeHistory(episodeIndex);

      // Re-check after async
      if (_mediaManager.state.currentEpisodeIndex != episodeIndex) {
        return;
      }

      if (history != null) {
        final resumeState = ResumeState(
          positionMillis: history.positionMillis,
          durationMillis: history.durationMillis,
        );

        final progress = resumeState.progress;
        const int minRestoreMillis = 30000; // 30 seconds

        if (progress > 0.95) {
          // Progress > 95%: Show replay dialog
          logger.d("[ResumeDelegate] Progress > 95%, showing replay dialog");
          _uiManager.hideControlsImmediately();
          _uiManager.showReplayDialog(resumeState);
          // Stay paused
          pause();
        } else if (history.positionMillis > minRestoreMillis) {
          // Valid mid-progress: Show resume dialog
          logger.d("[ResumeDelegate] Valid progress, showing resume dialog");
          _uiManager.hideControlsImmediately();
          _uiManager.showResumeDialog(resumeState);
          // Stay paused
          pause();
        } else {
          // Progress too short: Auto-skip intro or start from beginning
          logger.d(
            "[ResumeDelegate] Progress too short (<30s), handling intro skip",
          );
          _handleIntroSkip(
            seek: seek,
            play: play,
            getPlayerSetting: getPlayerSetting,
            autoPlay: autoPlay,
          );
        }
      } else {
        // No history: Check for intro skip
        _handleIntroSkip(
          seek: seek,
          play: play,
          getPlayerSetting: getPlayerSetting,
          autoPlay: autoPlay,
        );
      }
    } catch (e) {
      logger.e('[ResumeDelegate] Failed to check resume playback: $e');
      // If error occurs, fallback to autoPlay
      if (autoPlay) play();
    }
  }

  void _handleIntroSkip({
    required Future<void> Function(Duration, SeekSource) seek,
    required Future<void> Function() play,
    required PlayerSetting Function() getPlayerSetting,
    required bool autoPlay,
  }) {
    final setting = getPlayerSetting();
    if (setting.autoSkip && setting.skipIntro > 0) {
      logger.d(
        "[ResumeDelegate] No history/short progress, applying intro skip",
      );
      seek(Duration(seconds: setting.skipIntro), SeekSource.external);
      _uiManager.showSkipIntroNotification();
    }
    if (autoPlay) play();
  }
}

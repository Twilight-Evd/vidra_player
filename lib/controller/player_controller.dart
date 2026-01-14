import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/interfaces/window_delegate.dart';
import '../adapters/repository/memory_media_repository.dart';
import '../core/interfaces/media_repository.dart';
import '../core/localization/localization.dart';
import '../core/model/player_locale.dart';
import '../managers/playback_manager.dart';
import '../managers/buffering_manager.dart';
import '../managers/audio_manager.dart';
import '../managers/media_manager.dart';
import '../managers/ui_manager.dart';
import '../managers/window_event_manager.dart';
import '../core/interfaces/video_player.dart';
import '../core/model/model.dart';
import '../core/state/states.dart';
import '../utils/event_control.dart';
import '../utils/log.dart';
import '../core/delegates/resume_delegate.dart';
import '../core/delegates/skip_delegate.dart';
import '../core/events/player_lifecycle_event.dart';

/// The main controller for VidraPlayer that manages video playback lifecycle.
///
/// `PlayerController` is the central orchestrator for all video player functionality including:
/// - Playback control (play, pause, seek)
/// - Episode and quality switching
/// - Audio control (volume, mute, playback speed)
/// - History tracking and resume functionality
/// - UI state management and keyboard shortcuts
/// - Multi-episode support with auto-play and auto-skip features
///
/// ## Lifecycle
///
/// 1. Create the controller with configuration and video metadata
/// 2. Use `renderPlayer()` to get the player widget
/// 3. Control playback using methods like `play()`, `pause()`, `seek()`
/// 4. Listen to state changes via exposed streams
/// 5. Call `dispose()` when done to clean up resources
///
/// ## Basic Usage
///
/// ```dart
/// // Create controller
/// final controller = PlayerController(
///   config: PlayerConfig(
///     theme: PlayerUITheme.dark(),
///     features: PlayerFeatures.all(),
///     locale: VidraLocale.en,
///   ),
///   player: videoPlayerAdapter,
///   video: videoMetadata,
///   episodes: episodeList,
/// );
///
/// // Render in widget tree
/// @override
/// Widget build(BuildContext context) {
///   return controller.renderPlayer();
/// }
///
/// // Control playback
/// await controller.play();
/// await controller.pause();
/// await controller.seek(Duration(seconds: 30), SeekSource.external);
///
/// // Switch episodes
/// await controller.switchEpisode(1);
///
/// // Clean up
/// @override
/// void dispose() {
///   controller.dispose();
///   super.dispose();
/// }
/// ```
///
/// ## State Streams
///
/// The controller exposes several streams for observing state changes:
/// - `lifecycleStream`: Playback status (playing, paused, initialized, etc.)
/// - `positionStream`: Current playback position and duration
/// - `mediaStream`: Current episode, quality, and metadata
/// - `audioStream`: Volume, mute status, playback speed
/// - `bufferingStream`: Buffering state
/// - `errorStream`: Playback errors
/// - `lifecycleEvents`: Structured lifecycle events (created, media, playback, completion)
///
/// See also:
/// - [PlayerConfig] for configuration options
/// - [VideoPlayerWidget] for the widget implementation
/// - [PlayerUITheme] for theme customization
class PlayerController {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  PlayerConfig config;

  // Managers
  final PlaybackManager playbackManager;
  final BufferingManager bufferingManager;
  final AudioManager audioManager;
  final MediaManager mediaManager;
  final UIStateManager uiManager;
  final WindowEventManager _windowManager;

  // Delegates for focused responsibilities
  late final ResumeDelegate _resumeDelegate;
  late final SkipDelegate _skipDelegate;
  late final IVideoPlayer _player;

  // State
  PlaybackLifecycleState _lifecycle = const PlaybackLifecycleState();
  PlaybackPositionState _position = const PlaybackPositionState();
  MediaContextState _media = const MediaContextState();
  AudioState _audio = const AudioState();
  ViewModeState _view = const ViewModeState();
  BufferingState _buffering = const BufferingState();
  ErrorState _error = const ErrorState();

  // Internal flags
  bool _isDisposed = false;
  bool _pendingResumeCheck = false;
  bool _isSwitchingEpisode = false;
  bool _isSkippingOutro = false;

  // Subscriptions
  StreamSubscription? _lifecycleSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _mediaSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _viewSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _windowSub;

  // Event System
  final _eventCtrl = StreamController<PlayerLifecycleEvent>.broadcast();
  bool _hasEmittedPlaylistEnded = false;
  bool _wasSeeking = false;

  // Utilities
  final LeadingDebounce _mouseMoveDebounce = LeadingDebounce(
    const Duration(milliseconds: 100),
  );
  final Debounce _seekDebounce = Debounce(const Duration(milliseconds: 200));

  // Localization
  late VidraLocalization localization;

  // ===============================================================
  // Construction & Initialization
  // ===============================================================

  PlayerController({
    required this.config,
    required IVideoPlayer player,
    required VideoMetadata video,
    required List<VideoEpisode> episodes,
    WindowDelegate? windowDelegate,
    MediaRepository? mediaRepository,
  }) : playbackManager = PlaybackManager(config: config, player: player),
       bufferingManager = BufferingManager(player: player),
       audioManager = AudioManager(player: player),
       mediaManager = MediaManager(
         repository: mediaRepository ?? MemoryMediaRepository(),
       ),
       _windowManager = WindowEventManager(),
       uiManager = UIStateManager(
         behavior: config.behavior,
         windowDelegate: windowDelegate,
       ),
       localization = VidraLocalization(config.locale ?? VidraLocale.en) {
    // Initialize delegates
    _resumeDelegate = ResumeDelegate(
      mediaManager: mediaManager,
      uiManager: uiManager,
    );
    _skipDelegate = SkipDelegate(uiManager: uiManager);

    _bindStreams();

    _initialize(
      video: video,
      episodes: episodes,
      initEpisodeIndex: config.initialEpisodeIndex,
    );
    _bindWindowEvents();

    _player = player;

    // Emit created event
    _safeEmit(const PlayerCreated());
  }

  void _safeEmit(PlayerLifecycleEvent event) {
    if (!_eventCtrl.isClosed) {
      _eventCtrl.add(event);
    }
  }

  void _initialize({
    required VideoMetadata video,
    required List<VideoEpisode> episodes,
    int? initEpisodeIndex,
  }) async {
    if (_isDisposed) return;

    _beforePlayerInit(
      video: video,
      episodes: episodes,
      initEpisodeIndex: initEpisodeIndex,
    );
    // Initial load
    await _loadEpisode(initEpisodeIndex ?? 0);

    _afterPlayerInit();
  }

  void _beforePlayerInit({
    required VideoMetadata video,
    required List<VideoEpisode> episodes,
    int? initEpisodeIndex,
  }) async {
    mediaManager.initialize(
      video: video,
      episodes: episodes,
      episodeIndex: initEpisodeIndex,
    );
  }

  void _afterPlayerInit() async {
    // Set initial volume
    if (config.behavior.initialVolume != 1.0) {
      await audioManager.setVolume(config.behavior.initialVolume);
    }
    // Apply initial config
    if (config.behavior.muteOnStart) {
      await audioManager.setMute();
    }
  }

  // ===============================================================
  // Stream Accessors
  // ===============================================================

  Stream<PlaybackLifecycleState> get lifecycleStream =>
      playbackManager.lifecycleStream;
  Stream<PlaybackPositionState> get positionStream =>
      playbackManager.positionStream;
  Stream<MediaContextState> get mediaStream => mediaManager.mediaStream;
  Stream<AudioState> get audioStream => audioManager.audioStream;
  Stream<ViewModeState> get viewStream => uiManager.viewModeStream;
  Stream<BufferingState> get bufferingStream =>
      bufferingManager.bufferingStream;
  Stream<ErrorState> get errorStream => playbackManager.errorStream;
  Stream<SwitchingState> get switchingStream => playbackManager.switchingStream;

  /// Stream of structured lifecycle events.
  Stream<PlayerLifecycleEvent> get lifecycleEvents => _eventCtrl.stream;

  // State Getters
  PlaybackLifecycleState get lifecycle => _lifecycle;
  PlaybackPositionState get position => _position;
  MediaContextState get media => _media;
  AudioState get audio => _audio;
  ViewModeState get view => _view;
  BufferingState get buffering => _buffering;
  ErrorState get error => _error;

  // ===============================================================
  // Core Playback Operations
  // ===============================================================

  Future<void> play() async {
    if (_isDisposed) return;
    await playbackManager.play();
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    await playbackManager.pause();
  }

  Future<void> togglePlayPause() async {
    if (_isDisposed) return;

    if (_lifecycle.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position, SeekSource source) async {
    if (_isDisposed) return;
    _seekDebounce.call(() async {
      await playbackManager.seek(position, source);
    });
  }

  Future<void> seekRelative(Duration offset) async {
    if (_isDisposed) return;

    _seekDebounce.call(() async {
      final newPosition = _position.position + offset;
      final clampedPosition = Duration(
        milliseconds: newPosition.inMilliseconds.clamp(
          0,
          _position.duration.inMilliseconds,
        ),
      );
      await playbackManager.seek(clampedPosition, SeekSource.external);
    });
  }

  Future<void> seekStart() async {
    if (_isDisposed) return;
    playbackManager.beforeSeek();
    if (lifecycle.isPlaying) {
      await pause();
    }
  }

  Future<void> seekEnd() async {
    if (_isDisposed) return;
    if (lifecycle.wasPlayingBeforeSeek) {
      await play();
    }
  }

  Future<void> continuePlayback(int positionMillis) async {
    if (_isDisposed) return;

    // Seek first while dialog is effectively "blocking" logic (via showResumeDialog check)
    await seek(Duration(milliseconds: positionMillis), SeekSource.external);
    uiManager.hideResumeDialog();
    await play();
  }

  Future<void> restartPlayback() async {
    if (_isDisposed) return;

    if (playerSetting.autoSkip && playerSetting.skipIntro > 0) {
      await seek(
        Duration(seconds: playerSetting.skipIntro),
        SeekSource.external,
      );
      uiManager.showSkipIntroNotification();
    } else {
      await seek(Duration.zero, SeekSource.external);
    }
    uiManager.hideResumeDialog();
    await play();
  }

  // ===============================================================
  // Audio Operations
  // ===============================================================

  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    await audioManager.setVolume(volume);
  }

  Future<void> toggleMute() async {
    if (_isDisposed) return;
    await audioManager.toggleMute();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (_isDisposed) return;
    await audioManager.setPlaybackSpeed(speed);
  }

  // ===============================================================
  // Media & Episode Management
  // ===============================================================

  Future<void> switchEpisode(int index) async {
    if (_isDisposed || mediaManager.state.currentEpisodeIndex == index) return;

    // Cancel pending seeks immediately to prevent them from firing on new episode
    _seekDebounce.cancel();

    // Get target episode for display
    final targetEpisode =
        mediaManager.state.episodes.isNotEmpty &&
            index < mediaManager.state.episodes.length
        ? mediaManager.state.episodes[index]
        : null;

    try {
      // Set switching flag to prevent saving wrong episode history
      _isSwitchingEpisode = true;
      _hasEmittedPlaylistEnded = false; // Reset for new episode

      // Emit Change Event
      if (mediaManager.state.currentEpisode != null && targetEpisode != null) {
        _safeEmit(
          EpisodeChanged(
            from: mediaManager.state.currentEpisode,
            to: targetEpisode,
          ),
        );
      }

      // Start switching state with episode title
      playbackManager.startSwitching(
        targetEpisode?.title ?? localization.translate('unknown_episode'),
      );

      // Save history for current episode before switch
      if (mediaManager.state.video != null &&
          mediaManager.state.currentEpisode != null &&
          _position.position > Duration.zero) {
        await mediaManager.saveProgressImmediate(
          episodeIndex: mediaManager.state.currentEpisodeIndex,
          positionMillis: _position.position.inMilliseconds,
          durationMillis: _position.duration.inMilliseconds,
        );
      }

      mediaManager.switchEpisode(index);

      await _loadEpisode(index, switchEpisode: true);
      await play();

      // End switching state
      playbackManager.endSwitching();

      // Clear switching flag after a small delay to ensure new video is stable
      await Future.delayed(const Duration(milliseconds: 500));
      _isSwitchingEpisode = false;
    } catch (e) {
      // Ensure state is cleared on error
      _isSwitchingEpisode = false;
      playbackManager.endSwitching();
      rethrow;
    }
  }

  Future<void> switchQuality(int index) async {
    if (_isDisposed) return;

    // Get target quality label for display
    final targetQuality =
        _media.availableQualities.isNotEmpty &&
            index < _media.availableQualities.length
        ? _media.availableQualities[index]
        : null;

    if (targetQuality == null) return;

    try {
      // Start switching state
      playbackManager.startSwitching(targetQuality.label);

      final currentPosition = _position.position;
      final wasPlaying = _lifecycle.status == PlaybackStatus.playing;

      await playbackManager.resetPlayer();

      await playbackManager.initialize(
        video: _media.video,
        episodes: _media.episodes,
        episodeIndex: _media.currentEpisodeIndex,
        qualityIndex: index,
      );

      _hasEmittedPlaylistEnded = false;

      // Restore audio/speed state after player reset
      await audioManager.restoreState();

      mediaManager.switchQuality(index);

      if (currentPosition > Duration.zero) {
        await seek(currentPosition, SeekSource.external);
      }
      if (wasPlaying) {
        await play();
      }
      // End switching state
      playbackManager.endSwitching();
    } catch (e) {
      // Ensure state is cleared on error
      playbackManager.endSwitching();
      rethrow;
    }
  }

  Future<void> _loadEpisode(int index, {bool switchEpisode = false}) async {
    if (index < 0 || index >= mediaManager.state.episodes.length) return;

    // Cancel any pending seeks from previous state
    _seekDebounce.cancel();

    if (switchEpisode) {
      await playbackManager.resetPlayer();
    }
    await playbackManager.initialize(
      video: mediaManager.state.video,
      episodes: mediaManager.state.episodes,
      episodeIndex: index,
    );
    // Restore audio/speed state after player reset
    await audioManager.restoreState();
    showControls();

    // Emit EpisodeStarted
    final currentEp = mediaManager.state.currentEpisode;
    if (currentEp != null) {
      _safeEmit(EpisodeStarted(index: index, episode: currentEp));
    }

    if (config.behavior.autoPlay) {
      // Optimisation: If history is enabled, we delay auto-play until
      // ResumeDelegate decides whether to seek (intro skip) or prompt (resume).
      // This prevents playing immediately then jumping, or playing then pausing.
      if (!config.features.enableHistory) {
        await play();
      }
    }
    // Check restore for new episode
    _pendingResumeCheck = true;
    _checkResumePlayback(index);
  }

  Future<void> playNextEpisode() async {
    if (_isDisposed) return;

    if (hasNextEpisode) {
      final nextIndex = _media.currentEpisodeIndex + 1;
      await switchEpisode(nextIndex);
    }
  }

  Future<void> playPreviousEpisode() async {
    if (_isDisposed) return;

    if (hasPreviousEpisode) {
      final previousIndex = _media.currentEpisodeIndex - 1;
      await switchEpisode(previousIndex);
    }
  }

  void updateEpisodes(List<VideoEpisode> episodes) {
    if (_isDisposed) return;
    mediaManager.updateEpisodes(episodes);
  }

  Future<void> playNextEpisodeFromReplay() async {
    if (_isDisposed) return;

    uiManager.hideReplayDialog();
    await playNextEpisode();
  }

  bool get hasNextEpisode {
    if (_isDisposed) return false;
    return _media.hasNextEpisode;
  }

  bool get hasPreviousEpisode {
    if (_isDisposed) return false;
    return _media.hasPreviousEpisode;
  }

  Future<EpisodeHistory?> getEpisodeHistory(int index) async {
    if (_isDisposed) return null;
    return await mediaManager.getEpisodeHistory(index);
  }

  Future<void> refreshHistory() async {
    if (_isDisposed) return;
    await mediaManager.getAllHistories();
  }

  // ===============================================================
  // Feature Logic (Resume/Properties)
  // ===============================================================

  void _checkResumePlayback(int episodeIndex) async {
    if (_isDisposed) {
      _pendingResumeCheck = false;
      return;
    }

    if (!config.features.enableHistory) {
      _pendingResumeCheck = false;
      // If history is disabled but auto-play is on, we play immediately here
      // because _loadEpisode deferred it.
      if (config.behavior.autoPlay) {
        await play();
      }
      return;
    }

    try {
      await _resumeDelegate.checkAndPromptResume(
        episodeIndex: episodeIndex,
        isInitialized: _lifecycle.isInitialized,
        isDisposed: _isDisposed,
        seek: seek,
        pause: pause,
        play: play,
        getPlayerSetting: () => playerSetting,
        autoPlay: config.behavior.autoPlay,
      );
    } catch (e) {
      logger.e('[PlayerController] Resume check failed: $e');
      // If check fails, fallback to auto-play
      if (config.behavior.autoPlay) {
        await play();
      }
    } finally {
      // Clear checking flag so we can start saving new progress
      _pendingResumeCheck = false;
    }
  }

  Future<void> replayEpisode() async {
    if (_isDisposed) return;

    await seek(Duration.zero, SeekSource.external);
    uiManager.hideReplayDialog();
    await play();
  }

  Future<void> dismissReplayDialog() async {
    if (_isDisposed) return;

    uiManager.hideReplayDialog();
    await play();
  }

  PlayerSetting get playerSetting =>
      media.playerSetting ?? PlayerSetting(videoId: media.video!.id);

  late final bool _autoPlayNext = config.features.enableAutoPlayNext;
  bool get autoPlayNext => _autoPlayNext;

  void updateAutoSkip(bool value) {
    if (_isDisposed) return;
    mediaManager.updateAutoSkip(value);
  }

  void updateSkipIntro(int duration) {
    if (_isDisposed) return;
    mediaManager.updateSkipIntro(duration);
  }

  void updateSkipOutro(int duration) {
    if (_isDisposed) return;
    mediaManager.updateSkipOutro(duration);
  }

  // ===============================================================
  // UI & Window Control
  // ===============================================================

  Widget renderPlayer({Key? key}) {
    return playbackManager.renderPlayer(key: key);
  }

  double get aspectRatio => _lifecycle.aspectRatio;

  void showControls() => uiManager.showControlsTemporarily();
  void hideControls() => uiManager.hideControlsImmediately();
  void toggleControls() => uiManager.toggleControls();

  void handleMouseMove(Offset position) {
    if (_isDisposed) return;
    _mouseMoveDebounce.call(
      leading: () {
        uiManager.handleMouseMove(position);
      },
      trailing: () {
        uiManager.handleMouseMove(position);
      },
    );
  }

  void showMoreMenu() => uiManager.showMoreMenu();
  void hideMoreMenu() => uiManager.hideMoreMenu();

  void showEpisodeList() {
    if (_isDisposed) return;
    refreshHistory();
    uiManager.showEpisodeList();
  }

  void hideEpisodeList() => uiManager.hideEpisodeList();

  void toggleEpisodeList() {
    if (_isDisposed) return;
    if (uiManager.currentVisibility.showEpisodeList) {
      hideEpisodeList();
    } else {
      showEpisodeList();
    }
  }

  void toggleFullscreen() {
    if (_isDisposed) return;
    uiManager.handleFullscreenToggle();
  }

  void togglePip() {
    if (_isDisposed) return;
    uiManager.handlePictureInPicture();
  }

  // ===============================================================
  // Input Handling
  // ===============================================================

  void handleKeyboardShortcut(String shortcut) {
    if (_isDisposed) return;
    uiManager.handleKeyboardInteraction();
    switch (shortcut) {
      case 'space':
        togglePlayPause();
        break;
      case 'f':
        toggleFullscreen();
        break;
      case 'm':
        toggleMute();
        break;
      case 'arrow_left':
        const amount = Duration(seconds: -5);
        seekRelative(amount);
        uiManager.showSeekFeedback(amount);
        break;
      case 'arrow_right':
        const amount = Duration(seconds: 5);
        seekRelative(amount);
        uiManager.showSeekFeedback(amount);
        break;
      case 'arrow_up':
        setVolume((_audio.volume + 0.1).clamp(0.0, 1.0));
        break;
      case 'arrow_down':
        setVolume((_audio.volume - 0.1).clamp(0.0, 1.0));
        break;
      case 'j':
        const amountJ = Duration(seconds: -10);
        seekRelative(amountJ);
        uiManager.showSeekFeedback(amountJ);
        break;
      case 'l':
        const amountL = Duration(seconds: 10);
        seekRelative(amountL);
        uiManager.showSeekFeedback(amountL);
        break;
      case 'escape':
        if (uiManager.currentVisibility.showEpisodeList) {
          hideEpisodeList();
        } else if (uiManager.currentViewMode.isFullscreen) {
          uiManager.handleFullscreenToggle();
        }
        break;
    }
  }

  // ===============================================================
  // Internal bindings & Disposal
  // ===============================================================

  void _bindStreams() {
    _lifecycleSub = lifecycleStream.listen((state) {
      if (_isDisposed) return;
      _lifecycle = state;

      uiManager.updatePlaybackState(
        isPlaying: state.isPlaying,
        isInitialized: state.isInitialized,
      );

      // Emit Events
      if (state.isInitialized && !_lifecycle.isInitialized) {
        _safeEmit(
          MediaInitialized(
            duration: _position.duration,
            aspectRatio: state.aspectRatio,
          ),
        );
      }

      if (state.status != _lifecycle.status) {
        if (state.isPlaying) {
          _safeEmit(const PlaybackStarted());
        } else {
          _safeEmit(const PlaybackPaused());
        }
      }

      // Save history on pause
      if (state.status == PlaybackStatus.paused &&
          _media.video != null &&
          _media.currentEpisode != null &&
          _position.position > Duration.zero) {
        mediaManager.saveProgressImmediate(
          episodeIndex: _media.currentEpisodeIndex,
          positionMillis: _position.position.inMilliseconds,
          durationMillis: _position.duration.inMilliseconds,
        );
      }
    });

    _positionSub = positionStream.listen((state) async {
      if (_isDisposed) return;

      // --- Seek Events ---
      if (state.isSeeking && !_wasSeeking) {
        _wasSeeking = true;
        _safeEmit(PlaybackSeekStarted(from: _position.position));
        _hasEmittedPlaylistEnded = false; // Reset on seek
      } else if (!state.isSeeking && _wasSeeking) {
        _wasSeeking = false;
        _safeEmit(PlaybackSeekCompleted(to: state.position));
      }

      _position = state;

      // --- Auto Skip Outro Logic (delegated) ---
      if (!_isSkippingOutro) {
        final skipped = await _skipDelegate.checkAndSkipOutro(
          position: state,
          setting: playerSetting,
          isSwitchingEpisode: _isSwitchingEpisode,
          pendingResumeCheck: _pendingResumeCheck,
          hasNextEpisode: hasNextEpisode,
          playNextEpisode: playNextEpisode,
          pause: pause,
        );
        if (skipped) {
          // Identify if it was a next-episode skip or a playlist-end skip
          final currentEp = mediaManager.state.currentEpisode;
          if (currentEp != null && !_hasEmittedPlaylistEnded) {
            _safeEmit(
              EpisodeEnded(
                index: mediaManager.state.currentEpisodeIndex,
                episode: currentEp,
              ),
            );

            if (!hasNextEpisode) {
              _safeEmit(
                PlaylistEnded(
                  video: mediaManager.state.video,
                  episodes: mediaManager.state.episodes,
                ),
              );
              _hasEmittedPlaylistEnded = true;
            }
          }

          _isSkippingOutro = true;
          // Reset flag after delay
          Future.delayed(const Duration(milliseconds: 500), () {
            _isSkippingOutro = false;
          });
        }
      }

      // --- Natural End Detection (No Auto-Skip) ---
      // If auto-skip didn't trigger, check if we reached the end naturally
      if (!_isSkippingOutro &&
          !_hasEmittedPlaylistEnded &&
          !state.isSeeking &&
          state.duration > Duration.zero &&
          state.position >=
              state.duration - const Duration(milliseconds: 200)) {
        final currentEp = mediaManager.state.currentEpisode;
        if (currentEp != null) {
          // Reached end safely
          _safeEmit(
            EpisodeEnded(
              index: mediaManager.state.currentEpisodeIndex,
              episode: currentEp,
            ),
          );

          if (!hasNextEpisode) {
            _safeEmit(
              PlaylistEnded(
                video: mediaManager.state.video,
                episodes: mediaManager.state.episodes,
              ),
            );
            _hasEmittedPlaylistEnded = true;
          } else {
            // Mark as emitted to prevent spamming, but reset on next episode load
            _hasEmittedPlaylistEnded = true;
          }
        }
      }

      // Save history periodically
      // Fix: Don't save if checking resume or dialog is open, to avoid overwriting history with 0
      final isResumeDialogShowing =
          uiManager.currentVisibility.showResumeDialog;
      final isReplayDialogShowing =
          uiManager.currentVisibility.showReplayDialog;

      if (!_pendingResumeCheck &&
          !_isSwitchingEpisode &&
          !isResumeDialogShowing &&
          !isReplayDialogShowing &&
          mediaManager.state.video != null &&
          mediaManager.state.currentEpisode != null) {
        mediaManager.saveProgress(
          // video: mediaManager.state.video!,
          episodeIndex: mediaManager.state.currentEpisodeIndex,
          positionMillis: state.position.inMilliseconds,
          durationMillis: state.duration.inMilliseconds,
        );
      }
    });

    _mediaSub = mediaStream.listen((state) {
      if (_isDisposed) return;
      _media = state;
    });

    _audioSub = audioStream.listen((state) {
      if (_isDisposed) return;
      _audio = state;
    });

    _viewSub = viewStream.listen((state) {
      if (_isDisposed) return;
      _view = state;
    });

    _bufferingSub = bufferingStream.listen((state) {
      if (_isDisposed) return;
      _buffering = state;
      uiManager.updatePlaybackState(isBuffering: state.isBuffering);
    });

    _errorSub = errorStream.listen((state) {
      if (_isDisposed) return;
      _error = state;
      if (state.error != null) {
        _safeEmit(MediaLoadFailed(state.error!));
      }
    });
  }

  void _bindWindowEvents() {
    _windowSub = _windowManager.eventStream.listen((event) {
      if (_isDisposed) return;

      switch (event.type) {
        case WindowEventType.focusGained:
          uiManager.updateWindowState(hasFocus: true);

          playbackManager.refreshState();
          break;
        case WindowEventType.focusLost:
          uiManager.updateWindowState(hasFocus: false);

          break;
        case WindowEventType.minimized:
          uiManager.updateWindowState(isMinimized: true);

          break;
        case WindowEventType.restored:
          uiManager.updateWindowState(isMinimized: false);

          break;
        case WindowEventType.visibilityChanged:
          final isVisible = event.data as bool;

          uiManager.updateWindowState(isMinimized: !isVisible);
          if (isVisible) {
            playbackManager.refreshState();
          }
          break;
        default:
          break;
      }
    });
  }

  void setLocale(VidraLocale locale) {
    if (_isDisposed) return;
    config = config.copyWith(locale: locale);
    localization = VidraLocalization(locale);
    // Trigger a visibility update to force UI rebuilds of components watching the controller
    uiManager.refresh();
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Disposal cleanup
    _lifecycleSub?.cancel();
    _positionSub?.cancel();
    _mediaSub?.cancel();
    _audioSub?.cancel();
    _viewSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _windowSub?.cancel();

    // Internal
    _mouseMoveDebounce.dispose();
    _seekDebounce.dispose();

    // Managers
    uiManager.dispose();
    mediaManager.dispose();
    bufferingManager.dispose();
    playbackManager.dispose();
    _windowManager.dispose();

    _safeEmit(const PlayerDisposed());
    _eventCtrl.close();

    await _player.dispose();
  }
}

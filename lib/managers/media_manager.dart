import 'dart:async';

import '../core/interfaces/media_repository.dart';
import '../core/state/media_context.dart';
import '../core/model/model.dart';
import '../utils/event_control.dart';
import '../utils/log.dart';

/// Manages media context including video, episodes, quality selections,
/// history tracking, and player settings.
class MediaManager {
  // ===============================================================
  // Dependencies & State
  // ===============================================================

  final MediaRepository _repository;

  final _mediaCtrl = StreamController<MediaContextState>.broadcast();
  MediaContextState _state = const MediaContextState();

  // Utils
  final Latest _saveSettingLatest = Latest();
  final Throttle _saveProgressThrottle = Throttle(const Duration(seconds: 10));

  // ===============================================================
  // Construction
  // ===============================================================

  MediaManager({required MediaRepository repository})
    : _repository = repository;

  // ===============================================================
  // Stream & State Accessors
  // ===============================================================

  Stream<MediaContextState> get mediaStream => _mediaCtrl.stream;
  MediaContextState get state => _state;

  // ===============================================================
  // Initialization & Basic Updates
  // ===============================================================

  void initialize({
    VideoMetadata? video,
    required List<VideoEpisode> episodes,
    int? episodeIndex,
    int? qualityIndex,
  }) {
    _state = _state.copyWith(
      video: video,
      episodes: episodes,
      currentEpisodeIndex: episodeIndex ?? 0,
      currentQualityIndex: qualityIndex ?? 0,
    );

    _mediaCtrl.add(_state);

    if (episodes.length > 1) {
      getAllHistories();
      getPlayerSettings();
    }
  }

  void updateEpisodes(List<VideoEpisode> episodes) {
    _state = _state.copyWith(episodes: episodes);
    _mediaCtrl.add(_state);
  }

  void updateHistory(List<EpisodeHistory> histories) {
    _state = _state.copyWith(episodeHistory: histories);
    _mediaCtrl.add(_state);
  }

  void switchEpisode(int index) {
    if (index < 0 || index >= _state.episodes.length) return;
    _state = _state.copyWith(currentEpisodeIndex: index);
    _mediaCtrl.add(_state);
  }

  void switchQuality(int qualityIndex) {
    if (_state.currentQualityIndex != qualityIndex) {
      _state = _state.copyWith(currentQualityIndex: qualityIndex);
      _mediaCtrl.add(_state);
    }
  }

  void updatePlayerSetting(PlayerSetting setting) {
    _state = _state.copyWith(playerSetting: setting);
    _mediaCtrl.add(_state);
  }

  // ===============================================================
  // History Management
  // ===============================================================

  Future<void> saveProgress({
    required int episodeIndex,
    required int positionMillis,
    required int durationMillis,
  }) async {
    // Only save if duration is valid and position is reasonable
    if (durationMillis <= 0) return;

    _saveProgressThrottle.call(() async {
      final history = EpisodeHistory(
        index: episodeIndex,
        positionMillis: positionMillis,
        durationMillis: durationMillis,
      );
      logger.d(
        "[HistoryManager] Throttled save: ${_state.episodes[episodeIndex].title} @ $positionMillis ms",
      );
      await _repository.saveEpisodeHistory(_state.video!.id, history);

      _state = _state.copyWith(
        episodeHistory: _state.episodeHistory
            .map((h) => h.index == episodeIndex ? history : h)
            .toList(),
      );
      _mediaCtrl.add(_state);
    });
  }

  // Force save immediately (e.g. on pause or dispose)
  Future<void> saveProgressImmediate({
    required int episodeIndex,
    required int positionMillis,
    required int durationMillis,
  }) async {
    if (durationMillis <= 0) return;

    final history = EpisodeHistory(
      index: episodeIndex,
      positionMillis: positionMillis,
      durationMillis: durationMillis,
    );

    logger.d(
      "[HistoryManager] Immediate save: ${_state.episodes[episodeIndex].title} @ $positionMillis ms",
    );
    await _repository.saveEpisodeHistory(_state.video!.id, history);
  }

  Future<List<EpisodeHistory>> getAllHistories() async {
    if (_state.video == null) return [];
    final histories = await _repository.getEpisodeHistories(
      videoId: _state.video!.id,
    );

    updateHistory(histories);
    return histories;
  }

  Future<EpisodeHistory?> getEpisodeHistory(int episodeIndex) async {
    if (_state.episodeHistory.isNotEmpty) {
      try {
        return _state.episodeHistory.firstWhere((h) => h.index == episodeIndex);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// @deprecated Use getEpisodeHistory and handle logic in delegate
  Future<EpisodeHistory?> shouldRestore(int episodeIndex) async {
    logger.d(
      "[HistoryManager] Checking restore for: ${_state.episodes[episodeIndex].title}",
    );
    final history = await getEpisodeHistory(episodeIndex);

    if (history == null) return null;

    final canRestore =
        history.positionMillis > 30000 &&
        history.positionMillis < (history.durationMillis * 0.95);

    logger.d(
      "[HistoryManager] History found: ${history.positionMillis}ms. Can restore: $canRestore",
    );

    if (canRestore) {
      return history;
    }

    return null;
  }

  // ===============================================================
  // Player Configuration/Settings (Auto-Skip, etc.)
  // ===============================================================

  void updateSetting(PlayerSetting setting) {
    _saveSettingLatest.run(() async {
      _repository.savePlayerSettings(setting);
      _state = _state.copyWith(playerSetting: setting);
      _mediaCtrl.add(_state);
    });
  }

  Future<void> updateAutoSkip(bool autoSkip) async {
    final playerSetting = _state.playerSetting?.copyWith(autoSkip: autoSkip);
    _state = _state.copyWith(playerSetting: playerSetting);
    // ignore: null_check_always_fails
    updateSetting(playerSetting!);
  }

  Future<void> updateSkipIntro(int skipIntro) async {
    final playerSetting = _state.playerSetting?.copyWith(skipIntro: skipIntro);
    _state = _state.copyWith(playerSetting: playerSetting);
    updateSetting(playerSetting!);
  }

  Future<void> updateSkipOutro(int skipOutro) async {
    final playerSetting = _state.playerSetting?.copyWith(skipOutro: skipOutro);
    _state = _state.copyWith(playerSetting: playerSetting);
    updateSetting(playerSetting!);
  }

  Future<PlayerSetting> getPlayerSettings() async {
    if (_state.video == null) return PlayerSetting(videoId: 'unknown');
    final setting = await _repository.getPlayerSettings(
      videoId: _state.video!.id,
    );
    _state = _state.copyWith(playerSetting: setting);
    _mediaCtrl.add(_state);
    return setting;
  }

  // ===============================================================
  // Disposal
  // ===============================================================

  void dispose() {
    _mediaCtrl.close();
    _saveSettingLatest.reset();
    _saveProgressThrottle.dispose();
  }
}

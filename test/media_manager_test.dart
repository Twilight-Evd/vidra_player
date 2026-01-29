import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidra_player/core/interfaces/media_repository.dart';
import 'package:vidra_player/core/model/model.dart';
import 'package:vidra_player/managers/media_manager.dart';

class FakeMediaRepository implements MediaRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  Future<void> get saveFuture => _saveCompleter.future;

  @override
  Future<List<EpisodeHistory>> getEpisodeHistories({
    required String videoId,
  }) async {
    return [];
  }

  @override
  Future<PlayerSetting> getPlayerSettings({required String videoId}) async {
    return PlayerSetting(videoId: videoId);
  }

  @override
  Future<void> saveEpisodeHistory(
    String videoId,
    EpisodeHistory history,
  ) async {
    // Simulate delay
    await Future.delayed(const Duration(milliseconds: 50));
    _saveCompleter.complete();
  }

  @override
  Future<void> savePlayerSettings(PlayerSetting setting) async {
    // no-op
  }
}

void main() {
  test(
    'saveProgress does not throw StateError if disposed during async save',
    () async {
      final repository = FakeMediaRepository();
      final manager = MediaManager(repository: repository);

      // Initialize with some data so we can save progress
      manager.initialize(
        video: const VideoMetadata(
          id: 'v1',
          title: 'Test Video',
          coverUrl: 'http://test.com/cover.jpg',
        ),
        episodes: [const VideoEpisode(index: 0, title: 'Ep 1')],
      );

      // Trigger saveProgress
      // This uses a Throttle internally, so the first call runs immediately.
      manager.saveProgress(
        episodeIndex: 0,
        positionMillis: 1000,
        durationMillis: 10000,
      );

      // Dispose immediately while save is pending (awaiting repository)
      manager.dispose();

      // Wait for the async operation inside Throttle to complete.
      // The repository delay is 50ms. Waiting 100ms should be enough.
      // The unhandled exception should be caught by the test framework.
      await Future.delayed(const Duration(milliseconds: 100));
    },
  );
}

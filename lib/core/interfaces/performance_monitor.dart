/// Abstract interface for monitoring player performance
///
/// This interface allows apps to implement custom performance monitoring
/// without forcing the vidra_player package to depend on specific monitoring
/// tools like Sentry, Firebase, or custom analytics.
///
/// ## Usage
///
/// Implement this interface in your app:
///
/// ```dart
/// class MyPerformanceMonitor implements PlayerPerformanceMonitor {
///   @override
///   Future<T> trackPlay<T>(Future<T> Function() operation) async {
///     final startTime = DateTime.now();
///     try {
///       final result = await operation();
///       final duration = DateTime.now().difference(startTime);
///       // Send metrics to your monitoring service
///       return result;
///     } catch (e) {
///       // Log error
///       rethrow;
///     }
///   }
///   // ... implement other methods
/// }
/// ```
///
/// Then pass it to PlayerController:
///
/// ```dart
/// final controller = PlayerController(
///   config: config,
///   video: video,
///   episodes: episodes,
///   player: player,
///   performanceMonitor: MyPerformanceMonitor(), // Optional
/// );
/// ```
///
/// ## Benefits
///
/// - **Optional**: Monitoring is completely optional
/// - **Flexible**: Works with any monitoring solution
/// - **No Dependencies**: Package remains dependency-free
/// - **Testable**: Easy to mock for testing
abstract class PlayerPerformanceMonitor {
  /// Track a play operation
  ///
  /// [operation] - The play operation to execute
  /// [currentPositionMs] - Current playback position in milliseconds
  ///
  /// Returns the result of the operation.
  Future<T> trackPlay<T>(
    Future<T> Function() operation, {
    int? currentPositionMs,
  });

  /// Track a pause operation
  ///
  /// [operation] - The pause operation to execute
  /// [currentPositionMs] - Current playback position in milliseconds
  Future<T> trackPause<T>(
    Future<T> Function() operation, {
    int? currentPositionMs,
  });

  /// Track a seek operation
  ///
  /// [operation] - The seek operation to execute
  /// [fromMs] - Starting position in milliseconds
  /// [toMs] - Target position in milliseconds
  Future<T> trackSeek<T>(
    Future<T> Function() operation, {
    required int fromMs,
    required int toMs,
  });

  /// Track an episode switch operation
  ///
  /// [operation] - The episode switch operation to execute
  /// [fromEpisode] - Source episode index
  /// [toEpisode] - Target episode index
  Future<T> trackEpisodeSwitch<T>(
    Future<T> Function() operation, {
    required int fromEpisode,
    required int toEpisode,
  });

  /// Track a quality switch operation
  ///
  /// [operation] - The quality switch operation to execute
  /// [fromQuality] - Source quality label (e.g., "720p")
  /// [toQuality] - Target quality label (e.g., "1080p")
  Future<T> trackQualitySwitch<T>(
    Future<T> Function() operation, {
    String? fromQuality,
    String? toQuality,
  });

  /// Track episode loading operation
  ///
  /// [operation] - The episode loading operation to execute
  /// [episodeIndex] - Index of the episode being loaded
  /// [isSwitching] - Whether this is a switch operation or initial load
  Future<T> trackEpisodeLoad<T>(
    Future<T> Function() operation, {
    required int episodeIndex,
    bool isSwitching = false,
  });

  /// Called when buffering starts
  ///
  /// [currentPositionMs] - Current playback position in milliseconds
  void onBufferingStart({int? currentPositionMs});

  /// Called when buffering ends
  ///
  /// [currentPositionMs] - Current playback position in milliseconds
  /// [durationMs] - How long buffering lasted in milliseconds
  void onBufferingEnd({int? currentPositionMs, int? durationMs});

  /// Called when an error occurs
  ///
  /// [error] - The error that occurred
  /// [stackTrace] - Stack trace of the error
  /// [context] - Additional context about where the error occurred
  void onError(dynamic error, StackTrace? stackTrace, {String? context});

  /// Called when playback completes
  ///
  /// [episodeIndex] - Index of the completed episode
  /// [duration] - Total duration of the episode in milliseconds
  void onPlaybackComplete({required int episodeIndex, int? duration});

  /// Set the current video context for monitoring
  ///
  /// This should be called when a new video is loaded to ensure
  /// all subsequent operations are tagged with correct video information.
  ///
  /// [videoId] - Unique identifier for the video
  /// [episodeIndex] - Current episode index
  /// [quality] - Current quality setting
  void setVideoContext({
    required String videoId,
    int? episodeIndex,
    String? quality,
  });

  /// Clear the current video context
  ///
  /// This should be called when the player is disposed or when
  /// switching to a different video.
  void clearContext();

  /// Log a custom event
  ///
  /// Use this for tracking custom events that don't fit into
  /// the predefined categories.
  ///
  /// [event] - Name of the event
  /// [data] - Additional data associated with the event
  void logEvent(String event, Map<String, dynamic>? data);
}

/// VidraPlayer - A powerful Flutter video player SDK
///
/// This library provides a comprehensive video player solution with:
/// - Multi-episode support
/// - Quality switching
/// - History and resume functionality
/// - Customizable themes and behaviors
/// - Keyboard shortcuts
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:vidra_player/vidra_player.dart';
///
/// final controller = PlayerController(
///   config: PlayerConfig(
///     theme: PlayerUITheme.dark(),
///     locale: VidraLocale.en,
///   ),
///   player: videoPlayer,
///   video: videoMetadata,
///   episodes: episodes,
/// );
///
/// // In your widget tree
/// VideoPlayerWidget(controller: controller);
///
/// // Don't forget to dispose
/// controller.dispose();
/// ```
library;

// ============================================
// PUBLIC API - SDK Users Interface
// ============================================

// Core Controller
export 'controller/player_controller.dart' show PlayerController;

// Main Widget
export 'ui/player_widget.dart' show VideoPlayerWidget;

// Configuration Models
export 'core/model/player_config.dart' show PlayerConfig;
export 'core/model/player_ui_theme.dart' show PlayerUITheme;
export 'core/model/player_locale.dart' show VidraLocale;
export 'core/model/player_behavior.dart' show PlayerBehavior;
export 'core/model/player_features.dart' show PlayerFeatures;

// Video Models
export 'core/model/video_metadata.dart' show VideoMetadata;
export 'core/model/video_episode.dart' show VideoEpisode;
export 'core/model/video_quality.dart' show VideoQuality;
export 'core/model/video_source.dart' show VideoSource;

// Localization
export 'core/localization/localization.dart' show VidraLocalization;

export 'adapters/video_player/video_player.dart';

// ============================================
// INTERNAL IMPLEMENTATION
// All other files are internal and should not
// be imported directly by SDK users.
// ============================================

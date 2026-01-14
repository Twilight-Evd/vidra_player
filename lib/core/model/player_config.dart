import 'package:flutter/material.dart';

import 'player_behavior.dart';
import 'player_cache_config.dart';
import 'player_features.dart';
import 'player_locale.dart';
import 'player_network_config.dart';
import 'player_ui_theme.dart';

/// Player Configuration
@immutable
class PlayerConfig {
  final int initialEpisodeIndex;
  final bool? episodesSort; // true: ascending, false: descending
  final PlayerUITheme theme;
  final PlayerFeatures features;
  final PlayerBehavior behavior;
  final PlayerCacheConfig cache;
  final PlayerNetworkConfig network;
  final Widget? leading;
  final VidraLocale? locale;

  const PlayerConfig({
    this.initialEpisodeIndex = 0,
    this.episodesSort = true,
    this.theme = const PlayerUITheme.dark(),
    this.features = const PlayerFeatures.all(),
    this.behavior = const PlayerBehavior(),
    this.cache = const PlayerCacheConfig(),
    this.network = const PlayerNetworkConfig(),
    this.leading,
    this.locale,
  });

  PlayerConfig copyWith({
    String? videoId,
    String? sourceId,
    int? initialEpisodeIndex,
    PlayerUITheme? theme,
    PlayerFeatures? features,
    PlayerBehavior? behavior,
    PlayerCacheConfig? cache,
    PlayerNetworkConfig? network,
    VidraLocale? locale,
  }) {
    return PlayerConfig(
      initialEpisodeIndex: initialEpisodeIndex ?? this.initialEpisodeIndex,
      theme: theme ?? this.theme,
      features: features ?? this.features,
      behavior: behavior ?? this.behavior,
      cache: cache ?? this.cache,
      network: network ?? this.network,
      locale: locale ?? this.locale,
    );
  }
}

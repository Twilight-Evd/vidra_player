import 'package:flutter/material.dart';

/// Cache Configuration
@immutable
class PlayerCacheConfig {
  final bool enableCache;
  final Duration maxCacheDuration;
  final int maxCacheSizeMB;
  final bool preloadNextEpisode;

  const PlayerCacheConfig({
    this.enableCache = true,
    this.maxCacheDuration = const Duration(hours: 24),
    this.maxCacheSizeMB = 500,
    this.preloadNextEpisode = false,
  });
}

import 'package:flutter/material.dart';

/// Network Configuration
@immutable
class PlayerNetworkConfig {
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final bool autoRetry;
  final int maxRetries;
  final Duration retryDelay;
  final double bufferingThreshold;
  final double lowQualityThreshold;

  const PlayerNetworkConfig({
    this.connectionTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.autoRetry = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.bufferingThreshold = 0.2,
    this.lowQualityThreshold = 0.5,
  });
}

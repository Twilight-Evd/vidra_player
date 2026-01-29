import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:collection';
import 'dart:io';
import '../utils/event_control.dart';
import '../utils/log.dart';

/// Manages video thumbnail generation and caching.
class ThumbnailManager {
  static const MethodChannel _channel = MethodChannel('vidra_player');

  final String url;
  final int maxCacheSize;

  // LRU Cache: position (seconds) -> thumbnail data
  final LinkedHashMap<int, Uint8List> _cache = LinkedHashMap<int, Uint8List>();

  // Throttling
  final Throttle _throttle = Throttle(const Duration(milliseconds: 150));

  bool _isDisposed = false;
  String? _preparedUrl;

  ThumbnailManager({required this.url, this.maxCacheSize = 50});

  Future<void> prepare() async {
    if (!Platform.isMacOS) return;
    if (_isDisposed || _preparedUrl == url) return;
    try {
      await _channel.invokeMethod('prepareThumbnailGenerator', {'url': url});
      _preparedUrl = url;
    } catch (e) {
      logger.e("[ThumbnailManager] Error preparing generator: $e");
    }
  }

  Future<Uint8List?> getThumbnail(double seconds) async {
    if (!Platform.isMacOS) return null;
    if (_isDisposed) return null;

    final int key = seconds.round();

    // Check cache
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      final data = _cache.remove(key)!;
      _cache[key] = data;
      return data;
    }

    // Prepare if not already prepared
    if (_preparedUrl != url) {
      await prepare();
    }

    // Fetch from native
    Completer<Uint8List?> completer = Completer<Uint8List?>();

    _throttle.call(() async {
      if (_isDisposed) {
        completer.complete(null);
        return;
      }

      try {
        final Uint8List? data = await _channel.invokeMethod('getThumbnail', {
          'time': seconds,
        });
        if (data != null) {
          _addToCache(key, data);
        }
        completer.complete(data);
      } catch (e) {
        logger.e("[ThumbnailManager] Error getting thumbnail at $seconds: $e");
        completer.complete(null);
      }
    });

    return completer.future;
  }

  void _addToCache(int key, Uint8List data) {
    if (_cache.length >= maxCacheSize) {
      // Remove least recently used (first item in LinkedHashMap)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = data;
  }

  void dispose() {
    _isDisposed = true;
    _cache.clear();
    _throttle.dispose();
    _channel.invokeMethod('disposeThumbnailGenerator');
  }
}

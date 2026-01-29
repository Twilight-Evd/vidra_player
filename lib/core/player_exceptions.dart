// core/player_exceptions.dart

import '../utils/log.dart';

/// Player exception base class
class PlayerException implements Exception {
  final String message;
  final String? code;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  PlayerException(
    this.message, {
    this.code,
    DateTime? timestamp,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    var result = 'PlayerException';
    if (code != null) {
      result += ' [$code]';
    }
    result += ': $message';
    if (stackTrace != null) {
      result += '\n$stackTrace';
    }
    return result;
  }
}

/// Video load exception
class VideoLoadException extends PlayerException {
  final String videoId;
  final String? sourceId;
  final int? episodeIndex;

  VideoLoadException(
    super.message, {
    required this.videoId,
    this.sourceId,
    this.episodeIndex,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'VIDEO_LOAD_FAILED');

  @override
  String toString() {
    var result = 'VideoLoadException [$code]: Failed to load video $videoId';
    if (episodeIndex != null) {
      result += ' episode $episodeIndex';
    }
    result += ' - $message';
    return result;
  }
}

/// Video play exception
class VideoPlayException extends PlayerException {
  final String videoUrl;
  final String? videoId;
  final Duration? position;

  VideoPlayException(
    super.message, {
    required this.videoUrl,
    this.videoId,
    this.position,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'VIDEO_PLAY_FAILED');

  @override
  String toString() {
    var result = 'VideoPlayException [$code]: Failed to play video';
    if (videoId != null) {
      result += ' $videoId';
    }
    result += ' at position $position - $message';
    return result;
  }
}

/// Network exception
class NetworkException extends PlayerException {
  final Uri? url;
  final int? statusCode;
  final String? method;
  final Duration? timeout;

  NetworkException(
    super.message, {
    this.url,
    this.statusCode,
    this.method,
    this.timeout,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'NETWORK_ERROR');

  factory NetworkException.fromHttpError({
    required int statusCode,
    required String method,
    required Uri url,
    String? responseBody,
  }) {
    String message;
    String code;

    switch (statusCode) {
      case 400:
        code = 'BAD_REQUEST';
        message = 'Bad request to $url';
        break;
      case 401:
        code = 'UNAUTHORIZED';
        message = 'Unauthorized access to $url';
        break;
      case 403:
        code = 'FORBIDDEN';
        message = 'Access forbidden to $url';
        break;
      case 404:
        code = 'NOT_FOUND';
        message = 'Resource not found at $url';
        break;
      case 408:
        code = 'TIMEOUT';
        message = 'Request timeout for $url';
        break;
      case 429:
        code = 'RATE_LIMIT';
        message = 'Rate limit exceeded for $url';
        break;
      case 500:
        code = 'SERVER_ERROR';
        message = 'Server error from $url';
        break;
      case 502:
        code = 'BAD_GATEWAY';
        message = 'Bad gateway for $url';
        break;
      case 503:
        code = 'SERVICE_UNAVAILABLE';
        message = 'Service unavailable at $url';
        break;
      case 504:
        code = 'GATEWAY_TIMEOUT';
        message = 'Gateway timeout for $url';
        break;
      default:
        code = 'HTTP_ERROR';
        message = 'HTTP error $statusCode for $url';
    }

    return NetworkException(
      message,
      url: url,
      statusCode: statusCode,
      method: method,
      code: code,
    );
  }

  @override
  String toString() {
    var result = 'NetworkException [$code]: $message';
    if (statusCode != null) {
      result += ' (Status: $statusCode)';
    }
    if (timeout != null) {
      result += ' after ${timeout!.inSeconds}s';
    }
    return result;
  }
}

/// Cache exception
class CacheException extends PlayerException {
  final String? cacheKey;
  final int? cacheSize;
  final String? cachePath;

  CacheException(
    super.message, {
    this.cacheKey,
    this.cacheSize,
    this.cachePath,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'CACHE_ERROR');

  factory CacheException.fullCache({
    required int maxSize,
    required int currentSize,
    String? cachePath,
  }) {
    return CacheException(
      'Cache is full: $currentSize/$maxSize bytes',
      cacheSize: currentSize,
      cachePath: cachePath,
      code: 'CACHE_FULL',
    );
  }

  factory CacheException.cacheWriteFailed({
    required String key,
    required String path,
    required Object error,
  }) {
    return CacheException(
      'Failed to write cache for key $key to $path: $error',
      cacheKey: key,
      cachePath: path,
      code: 'CACHE_WRITE_FAILED',
    );
  }

  @override
  String toString() {
    var result = 'CacheException [$code]: $message';
    if (cacheKey != null) {
      result += '\nCache key: $cacheKey';
    }
    if (cachePath != null) {
      result += '\nCache path: $cachePath';
    }
    if (cacheSize != null) {
      result += '\nCache size: $cacheSize bytes';
    }
    return result;
  }
}

/// Format exception
class FormatException extends PlayerException {
  final String? formatType;
  final String? expectedFormat;
  final String? actualFormat;

  FormatException(
    super.message, {
    this.formatType,
    this.expectedFormat,
    this.actualFormat,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'FORMAT_ERROR');

  factory FormatException.videoFormat({
    required String actualFormat,
    required List<String> supportedFormats,
  }) {
    return FormatException(
      'Unsupported video format: $actualFormat. '
      'Supported formats: ${supportedFormats.join(", ")}',
      formatType: 'video',
      actualFormat: actualFormat,
      expectedFormat: supportedFormats.join(', '),
      code: 'UNSUPPORTED_VIDEO_FORMAT',
    );
  }

  factory FormatException.subtitleFormat({
    required String actualFormat,
    required List<String> supportedFormats,
  }) {
    return FormatException(
      'Unsupported subtitle format: $actualFormat. '
      'Supported formats: ${supportedFormats.join(", ")}',
      formatType: 'subtitle',
      actualFormat: actualFormat,
      expectedFormat: supportedFormats.join(', '),
      code: 'UNSUPPORTED_SUBTITLE_FORMAT',
    );
  }

  @override
  String toString() {
    var result = 'FormatException [$code]: $message';
    if (formatType != null) {
      result += '\nFormat type: $formatType';
    }
    if (expectedFormat != null) {
      result += '\nExpected: $expectedFormat';
    }
    if (actualFormat != null) {
      result += '\nActual: $actualFormat';
    }
    return result;
  }
}

/// Permission exception
class PermissionException extends PlayerException {
  final String permission;
  final String? platform;
  final bool isPermanent;

  PermissionException(
    super.message, {
    required this.permission,
    this.platform,
    this.isPermanent = false,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'PERMISSION_ERROR');

  factory PermissionException.denied({
    required String permission,
    String? platform,
  }) {
    return PermissionException(
      'Permission $permission denied',
      permission: permission,
      platform: platform,
      code: 'PERMISSION_DENIED',
    );
  }

  factory PermissionException.permanentlyDenied({
    required String permission,
    String? platform,
  }) {
    return PermissionException(
      'Permission $permission permanently denied',
      permission: permission,
      platform: platform,
      isPermanent: true,
      code: 'PERMISSION_PERMANENTLY_DENIED',
    );
  }

  @override
  String toString() {
    var result = 'PermissionException [$code]: $message';
    result += '\nPermission: $permission';
    if (platform != null) {
      result += '\nPlatform: $platform';
    }
    if (isPermanent) {
      result += '\n(Permanently denied)';
    }
    return result;
  }
}

/// Decoding exception
class DecodingException extends PlayerException {
  final String? codec;
  final String? container;
  final String? hardwareAccelerated;

  DecodingException(
    super.message, {
    this.codec,
    this.container,
    this.hardwareAccelerated,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'DECODING_ERROR');

  factory DecodingException.unsupportedCodec({
    required String codec,
    required String container,
  }) {
    return DecodingException(
      'Unsupported codec $codec in container $container',
      codec: codec,
      container: container,
      code: 'UNSUPPORTED_CODEC',
    );
  }

  factory DecodingException.hardwareAccelerationFailed({
    required String codec,
    required Object error,
  }) {
    return DecodingException(
      'Hardware acceleration failed for codec $codec: $error',
      codec: codec,
      hardwareAccelerated: 'failed',
      code: 'HARDWARE_ACCELERATION_FAILED',
    );
  }

  @override
  String toString() {
    var result = 'DecodingException [$code]: $message';
    if (codec != null) {
      result += '\nCodec: $codec';
    }
    if (container != null) {
      result += '\nContainer: $container';
    }
    if (hardwareAccelerated != null) {
      result += '\nHardware acceleration: $hardwareAccelerated';
    }
    return result;
  }
}

/// Player state exception
class PlayerStateException extends PlayerException {
  final String currentState;
  final String requiredState;
  final String operation;

  PlayerStateException(
    super.message, {
    required this.currentState,
    required this.requiredState,
    required this.operation,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'PLAYER_STATE_ERROR');

  factory PlayerStateException.invalidOperation({
    required String currentState,
    required String operation,
    required List<String> allowedStates,
  }) {
    return PlayerStateException(
      'Cannot $operation while in $currentState state. '
      'Allowed states: ${allowedStates.join(", ")}',
      currentState: currentState,
      requiredState: allowedStates.join(' or '),
      operation: operation,
      code: 'INVALID_OPERATION',
    );
  }

  @override
  String toString() {
    var result = 'PlayerStateException [$code]: $message';
    result += '\nCurrent state: $currentState';
    result += '\nRequired state: $requiredState';
    result += '\nOperation: $operation';
    return result;
  }
}

/// Configuration exception
class ConfigurationException extends PlayerException {
  final String configKey;
  final dynamic configValue;
  final String? expectedType;
  final String? validationRule;

  ConfigurationException(
    super.message, {
    required this.configKey,
    this.configValue,
    this.expectedType,
    this.validationRule,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'CONFIGURATION_ERROR');

  factory ConfigurationException.invalidValue({
    required String key,
    required dynamic value,
    required String expected,
    String? rule,
  }) {
    return ConfigurationException(
      'Invalid value for configuration $key: $value. Expected: $expected',
      configKey: key,
      configValue: value,
      expectedType: expected,
      validationRule: rule,
      code: 'INVALID_CONFIG_VALUE',
    );
  }

  factory ConfigurationException.missingRequired({required String key}) {
    return ConfigurationException(
      'Missing required configuration: $key',
      configKey: key,
      code: 'MISSING_CONFIG',
    );
  }

  @override
  String toString() {
    var result = 'ConfigurationException [$code]: $message';
    result += '\nConfig key: $configKey';
    if (configValue != null) {
      result += '\nConfig value: $configValue';
    }
    if (expectedType != null) {
      result += '\nExpected type: $expectedType';
    }
    if (validationRule != null) {
      result += '\nValidation rule: $validationRule';
    }
    return result;
  }
}

/// Resource cleanup exception
class ResourceCleanupException extends PlayerException {
  final String resourceType;
  final int? resourceId;
  final String? resourceName;

  ResourceCleanupException(
    super.message, {
    required this.resourceType,
    this.resourceId,
    this.resourceName,
    String? code,
    super.timestamp,
    super.stackTrace,
  }) : super(code: code ?? 'RESOURCE_CLEANUP_ERROR');

  factory ResourceCleanupException.leakDetected({
    required String type,
    required int count,
    String? name,
  }) {
    return ResourceCleanupException(
      'Potential resource leak detected: $count $type resources not cleaned up',
      resourceType: type,
      resourceName: name,
      code: 'RESOURCE_LEAK',
    );
  }

  @override
  String toString() {
    var result = 'ResourceCleanupException [$code]: $message';
    result += '\nResource type: $resourceType';
    if (resourceId != null) {
      result += '\nResource ID: $resourceId';
    }
    if (resourceName != null) {
      result += '\nResource name: $resourceName';
    }
    return result;
  }
}

/// Exception utility class
class ExceptionHandler {
  static Future<T> wrapAsync<T>(
    Future<T> Function() operation, {
    String? context,
    bool rethrowCritical = true,
    Function(PlayerException)? onError,
  }) async {
    try {
      return await operation();
    } on PlayerException catch (e) {
      // Log the exception
      _logException(e, context);

      // Call error callback
      onError?.call(e);

      // Rethrow if critical and configured to rethrow
      if (rethrowCritical && _isCriticalError(e)) {
        rethrow;
      }

      // Otherwise rethrow (to preserve stack trace)
      rethrow;
    } catch (e, stackTrace) {
      // Wrap unexpected exceptions as PlayerException
      final wrapped = PlayerException(
        'Unexpected error${context != null ? ' in $context' : ''}: $e',
        code: 'UNEXPECTED_ERROR',
        stackTrace: stackTrace,
      );

      _logException(wrapped, context);
      onError?.call(wrapped);

      if (rethrowCritical) {
        rethrow;
      }

      throw wrapped;
    }
  }

  static T wrapSync<T>(
    T Function() operation, {
    String? context,
    bool rethrowCritical = true,
    Function(PlayerException)? onError,
  }) {
    try {
      return operation();
    } on PlayerException catch (e) {
      _logException(e, context);
      onError?.call(e);

      if (rethrowCritical && _isCriticalError(e)) {
        rethrow;
      }

      rethrow;
    } catch (e, stackTrace) {
      final wrapped = PlayerException(
        'Unexpected error${context != null ? ' in $context' : ''}: $e',
        code: 'UNEXPECTED_ERROR',
        stackTrace: stackTrace,
      );

      _logException(wrapped, context);
      onError?.call(wrapped);

      if (rethrowCritical) {
        rethrow;
      }

      throw wrapped;
    }
  }

  static void _logException(PlayerException e, String? context) {
    final message = '${context != null ? '[$context] ' : ''}${e.toString()}';

    if (_isCriticalError(e)) {
      logger.e(message);
    } else {
      logger.w(message);
    }
  }

  static bool _isCriticalError(PlayerException e) {
    const criticalCodes = [
      'VIDEO_PLAY_FAILED',
      'DECODING_ERROR',
      'HARDWARE_ACCELERATION_FAILED',
      'RESOURCE_LEAK',
    ];

    return criticalCodes.contains(e.code) ||
        e is DecodingException ||
        e is ResourceCleanupException;
  }
}

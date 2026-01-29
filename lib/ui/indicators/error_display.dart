// ui/indicators/error_display.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/model/player_error.dart';
import '../../core/player_exceptions.dart';
import '../../controller/player_controller.dart';
import '../../core/model/player_ui_theme.dart';

/// Error display types
enum ErrorDisplayType {
  dialog, // Dialog
  inline, // Inline
  snackbar, // SnackBar
  fullscreen, // Fullscreen
}

/// Error display widget
class ErrorDisplay extends StatefulWidget {
  final PlayerController controller; // Added
  final PlayerError error;
  final ErrorDisplayType type;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;
  final VoidCallback? onReport;
  final String? retryText;
  final String? closeText;
  final String? reportText;
  final bool showStackTrace;
  final bool showErrorCode;
  final bool showTimestamp;
  final Duration? autoCloseDuration;
  final Widget? customIcon;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextStyle? detailStyle;

  const ErrorDisplay({
    super.key,
    required this.controller, // Added
    required this.error,
    this.type = ErrorDisplayType.dialog,
    this.onRetry,
    this.onClose,
    this.onReport,
    this.retryText,
    this.closeText,
    this.reportText,
    this.showStackTrace = false,
    this.showErrorCode = true,
    this.showTimestamp = false,
    this.autoCloseDuration,
    this.customIcon,
    this.titleStyle,
    this.messageStyle,
    this.detailStyle,
  });

  @override
  State<ErrorDisplay> createState() => _ErrorDisplayState();
}

class _ErrorDisplayState extends State<ErrorDisplay> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    if (widget.autoCloseDuration != null) {
      _autoCloseTimer = Timer(widget.autoCloseDuration!, () {
        if (mounted) {
          widget.onClose?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case ErrorDisplayType.dialog:
        return _buildDialogError();
      case ErrorDisplayType.inline:
        return _buildInlineError();
      case ErrorDisplayType.snackbar:
        return _buildSnackbarError();
      case ErrorDisplayType.fullscreen:
        return _buildFullscreenError();
    }
  }

  Widget _buildDialogError() {
    final theme = widget.controller.config.theme;
    final localization = widget.controller.localization;

    return Dialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Title
            Row(
              children: [
                widget.customIcon ??
                    Icon(
                      Icons.error_outline,
                      color: Colors
                          .red, // Was theme.colorScheme.error, hardcoding red for now or add errorColor to theme? Using red as safe fallback.
                      size: 32.0,
                    ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    localization.translate('playback_error'),
                    style:
                        widget.titleStyle ??
                        TextStyle(
                          color: theme.dialogTextColor,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20.0),

            // Error Message
            _buildErrorMessage(),

            const SizedBox(height: 24.0),

            // Action Buttons
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 16.0),
              const SizedBox(width: 8.0),
              Text(
                widget.controller.localization.translate('error'),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          Text(
            widget.error.message,
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (widget.onRetry != null || widget.onClose != null)
            const SizedBox(height: 12.0),

          if (widget.onRetry != null || widget.onClose != null)
            Row(
              children: [
                if (widget.onRetry != null)
                  TextButton(
                    onPressed: widget.onRetry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      widget.retryText ??
                          widget.controller.localization.translate('retry'),
                      style: const TextStyle(fontSize: 12.0),
                    ),
                  ),
                if (widget.onClose != null)
                  TextButton(
                    onPressed: widget.onClose,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      widget.closeText ??
                          widget.controller.localization.translate('close'),
                      style: const TextStyle(fontSize: 12.0),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSnackbarError() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              widget.error.message,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              child: Text(
                widget.retryText ?? '重试',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenError() {
    final theme = widget.controller.config.theme;
    final localization = widget.controller.localization;

    return Container(
      color: theme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.customIcon ??
                Icon(
                  Icons.error_outline,
                  color: Colors.red, // theme.errorColor missing
                  size: 64.0,
                ),

            const SizedBox(height: 32.0),

            Text(
              localization.translate('playback_failed'),
              style:
                  widget.titleStyle ??
                  TextStyle(
                    color: theme.textColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16.0),

            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildErrorMessage(),
            ),

            const SizedBox(height: 32.0),

            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error Message
        Text(
          widget.error.message,
          style:
              widget.messageStyle ??
              const TextStyle(color: Colors.white, fontSize: 16.0),
        ),

        const SizedBox(height: 8.0),

        // Error Details
        if (widget.error.details != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '详情: ${widget.error.details}',
                style:
                    widget.detailStyle ??
                    const TextStyle(color: Colors.white70, fontSize: 14.0),
              ),
              const SizedBox(height: 8.0),
            ],
          ),

        // Error Code
        if (widget.showErrorCode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '错误代码: ${widget.error.code}',
                style: const TextStyle(color: Colors.white60, fontSize: 12.0),
              ),
              const SizedBox(height: 8.0),
            ],
          ),

        // Timestamp
        if (widget.showTimestamp)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '时间: ${_formatDateTime(widget.error.timestamp)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12.0),
              ),
              const SizedBox(height: 8.0),
            ],
          ),

        // Stack Trace
        if (widget.showStackTrace && widget.error.stackTrace != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '堆栈跟踪:',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  widget.error.stackTrace.toString(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.0,
                    fontFamily: 'Monospace',
                  ),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons(PlayerUITheme theme) {
    final hasRetry = widget.onRetry != null;
    final hasClose = widget.onClose != null;
    final hasReport = widget.onReport != null;
    final localization = widget.controller.localization;

    if (!hasRetry && !hasClose && !hasReport) {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Report Button
        if (hasReport)
          TextButton(
            onPressed: widget.onReport,
            child: Text(
              widget.reportText ?? localization.translate('report_issue'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        const Spacer(),

        // Close Button
        if (hasClose)
          TextButton(
            onPressed: widget.onClose,
            child: Text(
              widget.closeText ?? localization.translate('close'),
              style: TextStyle(color: theme.textColor),
            ),
          ),

        // Retry Button
        if (hasRetry) const SizedBox(width: 12.0),
        if (hasRetry)
          ElevatedButton(
            onPressed: widget.onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
            ),
            child: Text(
              widget.retryText ?? localization.translate('retry'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}

/// Network Error Display
class NetworkErrorDisplay extends StatelessWidget {
  final PlayerController controller; // Added
  final NetworkException error;
  final VoidCallback onRetry;
  final VoidCallback? onClose;

  const NetworkErrorDisplay({
    super.key,
    required this.controller, // Added
    required this.error,
    required this.onRetry,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      controller: controller, // Added
      error: PlayerError(
        code: error.code ?? 'NETWORK_ERROR',
        message: _getErrorMessage(),
        details: _getErrorDetails(),
        timestamp: error.timestamp,
      ),
      onRetry: onRetry,
      onClose: onClose,
      customIcon: const Icon(Icons.wifi_off, color: Colors.orange, size: 32.0),
    );
  }

  String _getErrorMessage() {
    final l10n = controller.localization;
    if (error.statusCode != null) {
      switch (error.statusCode) {
        case 404:
          return l10n.translate('video_not_found');
        case 403:
          return l10n.translate('access_denied');
        case 401:
          return l10n.translate('authentication_required');
        case 500:
        case 502:
        case 503:
        case 504:
          return l10n.translate('server_error');
        case 408:
          return l10n.translate('request_timeout');
        default:
          return '${l10n.translate('network_error')} (${error.statusCode})';
      }
    }

    if (error.timeout != null) {
      return l10n.translate('connection_timeout');
    }

    return l10n.translate('connection_error');
  }

  String? _getErrorDetails() {
    final details = <String>[];
    final l10n = controller.localization;

    if (error.url != null) {
      details.add('URL: ${error.url}');
    }

    if (error.method != null) {
      details.add('${l10n.translate('method')}: ${error.method}');
    }

    if (error.timeout != null) {
      details.add(
        l10n.translate(
          'timeout_seconds',
          args: {'seconds': error.timeout!.inSeconds.toString()},
        ),
      );
    }

    return details.isNotEmpty ? details.join('\n') : null;
  }
}

/// Format Error Display
class FormatErrorDisplay extends StatelessWidget {
  final PlayerController controller; // Added
  final FormatException error;
  final VoidCallback? onClose;

  const FormatErrorDisplay({
    super.key,
    required this.controller,
    required this.error,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      controller: controller, // Added
      error: PlayerError(
        code: error.code ?? 'FORMAT_ERROR',
        message: _getErrorMessage(),
        details: _getErrorDetails(),
        timestamp: error.timestamp,
      ),
      onClose: onClose,
      customIcon: const Icon(
        Icons.videocam_off,
        color: Colors.purple,
        size: 32.0,
      ),
    );
  }

  String _getErrorMessage() {
    final l10n = controller.localization;
    if (error.formatType == 'video') {
      return l10n.translate('unsupported_video_format');
    } else if (error.formatType == 'subtitle') {
      return l10n.translate('unsupported_subtitle_format');
    }

    return l10n.translate('format_error');
  }

  String? _getErrorDetails() {
    final details = <String>[];
    final l10n = controller.localization;

    if (error.actualFormat != null) {
      details.add('${l10n.translate('current_format')}: ${error.actualFormat}');
    }

    if (error.expectedFormat != null) {
      details.add(
        '${l10n.translate('supported_formats')}: ${error.expectedFormat}',
      );
    }

    return details.isNotEmpty ? details.join('\n') : null;
  }
}

/// Decoding Error Display
class DecodingErrorDisplay extends StatelessWidget {
  final PlayerController controller; // Added
  final DecodingException error;
  final VoidCallback onRetryHardware;
  final VoidCallback onRetrySoftware;
  final VoidCallback? onClose;

  const DecodingErrorDisplay({
    super.key,
    required this.controller, // Added
    required this.error,
    required this.onRetryHardware,
    required this.onRetrySoftware,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = controller.localization;
    return ErrorDisplay(
      controller: controller, // Added
      error: PlayerError(
        code: error.code ?? 'DECODING_ERROR',
        message: _getErrorMessage(),
        details: _getErrorDetails(),
        timestamp: error.timestamp,
      ),
      onClose: onClose,
      customIcon: const Icon(Icons.broken_image, color: Colors.red, size: 32.0),
      retryText: l10n.translate('hardware_decoding'),
      onRetry: onRetryHardware,
      onReport: onRetrySoftware,
      reportText: l10n.translate('software_decoding'),
    );
  }

  String _getErrorMessage() {
    final l10n = controller.localization;
    if (error.codec != null) {
      return '${l10n.translate('decoder_error')}: ${error.codec}';
    }

    return l10n.translate('video_decoding_error');
  }

  String? _getErrorDetails() {
    final details = <String>[];
    final l10n = controller.localization;

    if (error.codec != null) {
      details.add('${l10n.translate('codec')}: ${error.codec}');
    }

    if (error.container != null) {
      details.add('${l10n.translate('container_format')}: ${error.container}');
    }

    if (error.hardwareAccelerated == 'failed') {
      details.add(l10n.translate('hardware_acceleration_failed'));
    }

    return details.isNotEmpty ? details.join('\n') : null;
  }
}

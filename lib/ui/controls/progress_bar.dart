// ui/controls/progress_bar.dart
import 'package:flutter/material.dart';

import '../../core/model/model.dart';
import '../../utils/util.dart';

class VideoProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final List<BufferRange> buffered;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  final Color? playedColor;
  final Color? bufferedColor;
  final Color? handleColor;
  final double barHeight;
  final double handleRadius;
  final double padding;

  const VideoProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    this.onSeek,
    this.onSeekStart,
    this.onSeekEnd,
    this.playedColor,
    this.bufferedColor,
    this.handleColor,
    this.barHeight = 3.0,
    this.handleRadius = 6.0, // using radius instead of height for slider thumb
    this.padding = 12,
    this.thumbVisible = true,
  });

  final bool thumbVisible;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar>
    with TickerProviderStateMixin {
  // Position management
  late final ValueNotifier<double> _currentPosition;
  late final ProgressAnimator _animator;

  // Toggle animation for thumb and height
  late final AnimationController _toggleController;
  late final Animation<double> _toggleAnimation;
  // Interaction state
  bool _isDragging = false;
  bool _isSeeking = false;
  double? _seekTarget;

  // Hover state
  late final ValueNotifier<double?> _hoverX;
  late final ValueNotifier<bool> _isHovering;

  @override
  void initState() {
    super.initState();
    _currentPosition = ValueNotifier(widget.position.inMilliseconds.toDouble());
    _hoverX = ValueNotifier(null);
    _isHovering = ValueNotifier(false);

    _animator = ProgressAnimator(vsync: this);

    _toggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toggleAnimation = CurvedAnimation(
      parent: _toggleController,
      curve: Curves.easeInOut,
    );

    if (widget.thumbVisible) {
      _toggleController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _toggleController.dispose();
    _animator.dispose(); // Fix: Dispose the animator to release its Ticker
    _currentPosition.dispose();
    _hoverX.dispose();
    _isHovering.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // During dragging, ignore external position updates completely
    if (_isDragging) {
      return;
    }

    if (oldWidget.position != widget.position) {
      final newPos = widget.position.inMilliseconds.toDouble();

      // If waiting for seek to complete
      if (_isSeeking && _seekTarget != null) {
        final targetPos = _seekTarget!;

        // Threshold set to 1000ms for fault tolerance
        const double threshold = 1000.0;
        final delta = (newPos - targetPos).abs();

        if (delta < threshold) {
          // Close to target, sync position and end seeking state
          _isSeeking = false;
          _seekTarget = null;
          _currentPosition.value = newPos;
        } else {
          // Still too far from target (possibly old stream data), keep _currentPosition as user intended
          // Do not update to avoid "rebound" flicker
        }
      } else {
        // Normal playback, update position directly
        _currentPosition.value = newPos;
      }
    }

    _animator.update(widget.position.inMilliseconds.toDouble());

    if (oldWidget.thumbVisible != widget.thumbVisible) {
      if (widget.thumbVisible) {
        _toggleController.forward();
      } else {
        _toggleController.reverse();
      }
    }
  }

  void _handleSliderChanged(double value) {
    if (!_isDragging) {
      _isDragging = true;
    }
    _currentPosition.value = value;
  }

  void _handleSliderChangeStart(double value) {
    _isDragging = true;
    _currentPosition.value = value;
    widget.onSeekStart?.call();
  }

  void _handleSliderChangeEnd(double value) {
    _isDragging = false;
    _isSeeking = true;
    _seekTarget = value;
    _currentPosition.value = value;

    widget.onSeek?.call(Duration(milliseconds: value.toInt()));
    widget.onSeekEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double maxDuration = widget.duration.inMilliseconds.toDouble();
    if (maxDuration <= 0) {
      // No valid duration, show empty progress bar
      return _buildEmptyProgressBar();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return MouseRegion(
          hitTestBehavior: HitTestBehavior.opaque,
          onEnter: (_) => _isHovering.value = true,
          onExit: (_) => _isHovering.value = false,
          onHover: (event) => _hoverX.value = event.localPosition.dx,
          child: AnimatedBuilder(
            animation: _toggleAnimation,
            builder: (context, child) {
              final double toggleValue = _toggleAnimation.value;
              // Interpolate height between 2.0 (collapsed) and widget.barHeight
              final double currentHeight =
                  2.0 + (widget.barHeight - 2.0) * toggleValue;
              // Interpolate radius between 0.0 and widget.handleRadius
              final double currentRadius = widget.handleRadius * toggleValue;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 1. Background Track
                  _buildBackgroundTrack(currentHeight),

                  // 2. Buffered Progress
                  _buildBufferedProgress(maxDuration, width, currentHeight),

                  // 3. Playback Progress and Slider
                  _buildPlaybackSlider(
                    maxDuration,
                    currentHeight,
                    currentRadius,
                  ),

                  // 4. Hover Tooltip
                  _buildHoverTooltip(maxDuration, width),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyProgressBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.padding),
      child: Container(
        width: double.infinity,
        height: widget.barHeight,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(widget.barHeight / 2),
        ),
      ),
    );
  }

  Widget _buildBackgroundTrack(double height) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.padding),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }

  Widget _buildBufferedProgress(
    double maxDuration,
    double width,
    double height,
  ) {
    if (widget.buffered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.padding),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: widget.buffered.map((range) {
            final double start = range.start.inMilliseconds / maxDuration;
            final double end = range.end.inMilliseconds / maxDuration;
            final double effectiveWidth = width - widget.padding * 2;

            return Positioned(
              left: start * effectiveWidth,
              width: (end - start) * effectiveWidth,
              top: 0,
              bottom: 0,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: widget.bufferedColor ?? Colors.white38,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlaybackSlider(
    double maxDuration,
    double height,
    double radius,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _currentPosition,
      builder: (context, currentPos, child) {
        final double clampedValue = currentPos.clamp(0.0, maxDuration);
        final double playedPercent = (clampedValue / maxDuration).clamp(
          0.0,
          1.0,
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Playback Progress Bar
              FractionallySizedBox(
                widthFactor: playedPercent,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: widget.playedColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),

              // Slider
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: height,
                  trackShape: _ZeroPaddingTrackShape(),
                  // Make track transparent, use custom progress bar display
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor:
                      widget.handleColor?.withValues(
                        alpha: (radius / widget.handleRadius).clamp(0.0, 1.0),
                      ) ??
                      Colors.red,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: radius),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: radius * 2,
                  ),
                  overlayColor: widget.handleColor?.withValues(alpha: 0.2),
                ),
                child: Slider(
                  padding: EdgeInsets.zero,
                  value: clampedValue,
                  min: 0.0,
                  max: maxDuration,
                  onChanged: (v) {
                    _animator.jump(v);
                    _handleSliderChanged(v);
                  },
                  onChangeStart: (v) {
                    _animator.lock();
                    _handleSliderChangeStart(v);
                  },
                  onChangeEnd: (v) {
                    _animator.unlock();
                    _handleSliderChangeEnd(v);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoverTooltip(double maxDuration, double width) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHovering,
      builder: (context, isHovering, child) {
        if (!isHovering && !_isDragging) return const SizedBox.shrink();

        return ValueListenableBuilder<double?>(
          valueListenable: _hoverX,
          builder: (context, hoverX, child) {
            return ValueListenableBuilder<double>(
              valueListenable: _currentPosition,
              builder: (context, currentPos, child) {
                final double effectiveWidth = width - widget.padding * 2;

                // Calculate displayed time and position
                final double displayTime;
                // Inner X relative to the start of the progress bar
                final double innerDisplayX;

                if (_isDragging) {
                  // Dragging: Show time at slider position
                  displayTime = currentPos;
                  // Tooltip position follows slider
                  final double percent = maxDuration > 0
                      ? (currentPos / maxDuration).clamp(0.0, 1.0)
                      : 0.0;
                  innerDisplayX = percent * effectiveWidth;
                } else {
                  // Hovering: Show time at mouse position
                  if (hoverX == null || width <= 0) {
                    return const SizedBox.shrink();
                  }
                  // hoverX is relative to the MouseRegion (outer width)
                  // relativeX handles clamping to the progress bar area
                  final double relativeX = (hoverX - widget.padding).clamp(
                    0.0,
                    effectiveWidth,
                  );
                  displayTime = effectiveWidth > 0
                      ? (relativeX / effectiveWidth) * maxDuration
                      : 0.0;
                  innerDisplayX = relativeX;
                }

                final duration = Duration(milliseconds: displayTime.toInt());

                // Positioned left is relative to Stack (which is inside padding)
                // So innerDisplayX is the correct left offset
                return Positioned(
                  left: (widget.padding + innerDisplayX - 25).clamp(
                    0.0,
                    width - 50,
                  ),
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Util.formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Smooth progress animator
///
/// Use cases:
/// - Smooth video playback position advancement
/// - Immediate response during seek / drag
/// - Prevent position rebound / jitter
class ProgressAnimator {
  final TickerProvider vsync;

  late final AnimationController _controller;
  Animation<double>? _animation;

  double _value = 0.0;
  bool _locked = false;

  ProgressAnimator({
    required this.vsync,
    Duration defaultDuration = const Duration(milliseconds: 300),
  }) {
    _controller = AnimationController(vsync: vsync, duration: defaultDuration);
  }

  /// Current value used by UI
  double get value => _value;

  /// Whether locked (seeking / dragging)
  bool get isLocked => _locked;

  /// External position update (normal playback)
  void update(
    double target, {
    Duration? duration,
    Curve curve = Curves.easeOut,
  }) {
    if (_locked) {
      _value = target;
      return;
    }

    final begin = _value;
    final end = target;

    if ((begin - end).abs() < 0.5) {
      // Tiny change, jump directly to avoid jitter
      _value = end;
      return;
    }

    _controller
      ..stop()
      ..duration = duration ?? _controller.duration;

    _animation =
        Tween<double>(begin: begin, end: end).animate(
          CurvedAnimation(parent: _controller, curve: curve),
        )..addListener(() {
          _value = _animation!.value;
        });

    _controller
      ..reset()
      ..forward();
  }

  /// Jump to value immediately (seek / drag)
  void jump(double value) {
    _controller.stop();
    _value = value;
  }

  /// Lock animation (start seek / drag)
  void lock() {
    _locked = true;
    _controller.stop();
  }

  /// Unlock animation (end seek / drag)
  void unlock() {
    _locked = false;
  }

  /// Reset immediately (switch video / init)
  void reset([double value = 0.0]) {
    _controller.stop();
    _value = value;
    _locked = false;
  }

  void dispose() {
    _controller.dispose();
  }
}

class _ZeroPaddingTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2.0;
    final double trackLeft = offset.dx;
    // Center vertically
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    // Use full width
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

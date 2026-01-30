import 'package:flutter/material.dart';
import '../../controller/player_controller.dart';
import '../../core/model/model.dart';
import '../../utils/util.dart';
import '../widget/thumbnail_preview.dart';

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
  final bool thumbVisible;
  final PlayerController? controller;

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
    this.handleRadius = 6.0,
    this.padding = 12,
    this.thumbVisible = true,
    this.controller,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar>
    with TickerProviderStateMixin {
  late final ValueNotifier<double> _currentPosition;
  late final ProgressAnimator _animator;

  late final AnimationController _toggleController;
  late final Animation<double> _toggleAnimation;

  bool _isDragging = false;
  bool _isSeeking = false;
  double? _seekTarget;

  late final ValueNotifier<double?> _hoverX;
  late final ValueNotifier<bool> _isHovering;

  late final AnimationController _hoverController;
  late final Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _currentPosition = ValueNotifier(widget.position.inMilliseconds.toDouble());
    _hoverX = ValueNotifier(null);
    _isHovering = ValueNotifier(false);

    _animator = ProgressAnimator(
      vsync: this,
      initialValue: _currentPosition.value,
    );

    _toggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toggleAnimation = CurvedAnimation(
      parent: _toggleController,
      curve: Curves.easeInOut,
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    );

    if (widget.thumbVisible) {
      _toggleController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _toggleController.dispose();
    _hoverController.dispose();
    _animator.dispose();
    _currentPosition.dispose();
    _hoverX.dispose();
    _isHovering.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isDragging) return;

    if (oldWidget.position != widget.position) {
      final oldPos = oldWidget.position.inMilliseconds.toDouble();
      final newPos = widget.position.inMilliseconds.toDouble();

      // Sync after user seek
      if (_isSeeking && _seekTarget != null) {
        const double threshold = 1000.0;
        final delta = (newPos - _seekTarget!).abs();

        if (delta < threshold) {
          _isSeeking = false;
          _seekTarget = null;
          _currentPosition.value = newPos;
          _animator.reset(newPos); // ensure animator consistent
        }
      } else {
        final delta = newPos - oldPos;
        final isPlayback = delta > 0 && delta < 1000; // optimized threshold

        if (isPlayback) {
          // Continuous playback → direct update
          _currentPosition.value = newPos;
          _animator.sync(newPos);
        } else {
          // Discrete jump / seek
          _currentPosition.value = newPos;
          _animator.reset(newPos);
        }
      }
    }

    if (oldWidget.thumbVisible != widget.thumbVisible) {
      if (widget.thumbVisible) {
        _toggleController.forward();
      } else {
        _toggleController.reverse();
      }
    }
  }

  void _handleSliderChanged(double value) {
    if (!_isDragging) _isDragging = true;
    _currentPosition.value = value;
    widget.controller?.uiManager.showControlsTemporarily();
  }

  void _handleSliderChangeStart(double value) {
    _isDragging = true;
    _currentPosition.value = value;
    widget.controller?.uiManager.showControlsPersistently();
    widget.onSeekStart?.call();
  }

  void _handleSliderChangeEnd(double value) {
    _isDragging = false;
    _isSeeking = true;
    _seekTarget = value;
    _currentPosition.value = value;
    _animator.reset(value); // keep animator consistent
    widget.onSeek?.call(Duration(milliseconds: value.toInt()));
    widget.controller?.uiManager.showControlsTemporarily();
    widget.onSeekEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double maxDuration = widget.duration.inMilliseconds.toDouble();
    if (maxDuration <= 0) return _buildEmptyProgressBar();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return MouseRegion(
          hitTestBehavior: HitTestBehavior.opaque,
          onEnter: (_) {
            _isHovering.value = true;
            _hoverController.forward();
            widget.controller?.uiManager.showControlsPersistently();
          },
          onExit: (_) {
            _isHovering.value = false;
            _hoverController.reverse();
            widget.controller?.uiManager.showControlsTemporarily();
          },
          onHover: (event) {
            _hoverX.value = event.localPosition.dx;
            widget.controller?.uiManager.showControlsTemporarily();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_toggleAnimation, _hoverAnimation]),
            builder: (context, child) {
              final toggleValue = _toggleAnimation.value;
              final thumbHoverScale = 1.0 + (_hoverAnimation.value * 0.2);
              final trackHoverScale = 1.0 + (_hoverAnimation.value * 1.0);

              final currentHeight =
                  (2.0 + (widget.barHeight - 2.0) * toggleValue) *
                  trackHoverScale;
              final currentRadius =
                  (widget.handleRadius * toggleValue) * thumbHoverScale;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  _buildBackgroundTrack(currentHeight),
                  _buildBufferedProgress(maxDuration, width, currentHeight),
                  _buildPlaybackSlider(
                    maxDuration,
                    currentHeight,
                    currentRadius,
                  ),
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
    final effectiveWidth = width - widget.padding * 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.padding),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: widget.buffered.map((range) {
            final start = range.start.inMilliseconds / maxDuration;
            final end = range.end.inMilliseconds / maxDuration;
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
        final clampedValue = currentPos.clamp(0.0, maxDuration);
        final playedPercent = (clampedValue / maxDuration).clamp(0.0, 1.0);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
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
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: height,
                  trackShape: _ZeroPaddingTrackShape(),
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
                  overlayColor:
                      widget.handleColor?.withValues(alpha: 0.2) ??
                      Colors.black26,
                ),
                child: Slider(
                  padding: EdgeInsets.zero,
                  value: clampedValue,
                  min: 0.0,
                  max: maxDuration,
                  onChanged: _handleSliderChanged,
                  onChangeStart: _handleSliderChangeStart,
                  onChangeEnd: _handleSliderChangeEnd,
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
                final effectiveWidth = width - widget.padding * 2;
                final double displayTime;
                final double innerDisplayX;

                if (_isDragging) {
                  displayTime = currentPos;
                  final percent = maxDuration > 0
                      ? (currentPos / maxDuration).clamp(0.0, 1.0)
                      : 0.0;
                  innerDisplayX = percent * effectiveWidth;
                } else {
                  if (hoverX == null || width <= 0) {
                    return const SizedBox.shrink();
                  }
                  final relativeX = (hoverX - widget.padding).clamp(
                    0.0,
                    effectiveWidth,
                  );
                  displayTime = effectiveWidth > 0
                      ? (relativeX / effectiveWidth) * maxDuration
                      : 0.0;
                  innerDisplayX = relativeX;
                }

                final duration = Duration(milliseconds: displayTime.toInt());

                // Calculate tooltip width dynamically
                final bool showThumbnail =
                    widget.controller != null &&
                    widget.controller!.enableThumbnail;
                final double tooltipWidth = showThumbnail ? 160.0 : 50.0;

                // Center the tooltip on the cursor (innerDisplayX), then clamp to screen bounds
                final double leftPos =
                    (widget.padding + innerDisplayX - (tooltipWidth / 2)).clamp(
                      0.0,
                      width - tooltipWidth,
                    );

                return Positioned(
                  left: leftPos,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showThumbnail)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ThumbnailPreview(
                            controller: widget.controller!,
                            url: widget
                                .controller!
                                .media
                                .currentEpisode!
                                .qualities
                                .first
                                .source
                                .path,
                            seconds: displayTime / 1000,
                          ),
                        ),
                      Container(
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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

/// Optimized ProgressAnimator
class ProgressAnimator {
  final TickerProvider vsync;
  late final AnimationController _controller;
  double _value;
  bool _locked = false;

  ProgressAnimator({
    required this.vsync,
    double initialValue = 0.0,
    Duration duration = const Duration(milliseconds: 300),
  }) : _value = initialValue {
    _controller = AnimationController(vsync: vsync, duration: duration);
    _controller.value = 0.0;
  }

  double get value => _value;
  bool get isLocked => _locked;

  void sync(double value) {
    if (_locked) return;
    _value = value;
    // Set controller starting point proportionally if needed for future animateTo
    _controller.value = 0.0;
  }

  void jump(double value) {
    _controller.stop();
    _value = value;
  }

  void lock() {
    _locked = true;
    _controller.stop();
  }

  void unlock() {
    _locked = false;
  }

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
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

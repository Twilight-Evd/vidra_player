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
      final newPos = widget.position.inMilliseconds.toDouble();

      if (_isSeeking && _seekTarget != null) {
        const double threshold = 1000.0;
        final delta = (newPos - _seekTarget!).abs();

        if (delta < threshold) {
          _isSeeking = false;
          _seekTarget = null;
          _currentPosition.value = newPos;
          _animator.reset(newPos);
        }
      } else {
        final oldPos = oldWidget.position.inMilliseconds.toDouble();
        final delta = newPos - oldPos;
        final isPlayback = delta > 0 && delta < 1000;

        _currentPosition.value = newPos;
        if (isPlayback) {
          _animator.sync(newPos);
        } else {
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
    _animator.reset(value);
    widget.onSeek?.call(Duration(milliseconds: value.toInt()));
    widget.controller?.uiManager.showControlsTemporarily();
    widget.onSeekEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double maxDuration = widget.duration.inMilliseconds.toDouble();
    if (maxDuration <= 0) return _buildEmptyProgressBar();

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
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.barHeight + widget.padding * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // CustomPaint for zero-layout updates
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.padding),
                  child: CustomPaint(
                    painter: ProgressBarPainter(
                      position: _currentPosition,
                      duration: maxDuration,
                      buffered: widget.buffered,
                      toggleAnimation: _toggleAnimation,
                      hoverAnimation: _hoverAnimation,
                      playedColor: widget.playedColor ?? Colors.red,
                      bufferedColor: widget.bufferedColor ?? Colors.white38,
                      backgroundColor: Colors.white24,
                      handleColor: widget.handleColor ?? Colors.red,
                      barHeight: widget.barHeight,
                      handleRadius: widget.handleRadius,
                    ),
                  ),
                ),
              ),

              // Invisible Slider for interactions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.padding),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: widget.barHeight * 2,
                    trackShape: _ZeroPaddingTrackShape(),
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.transparent,
                    thumbShape: _InvisibleThumbShape(),
                    overlayColor: Colors.transparent,
                  ),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _currentPosition,
                    builder: (context, currentPos, _) {
                      return Slider(
                        padding: EdgeInsets.zero,
                        value: currentPos.clamp(0.0, maxDuration),
                        min: 0.0,
                        max: maxDuration,
                        onChanged: _handleSliderChanged,
                        onChangeStart: _handleSliderChangeStart,
                        onChangeEnd: _handleSliderChangeEnd,
                      );
                    },
                  ),
                ),
              ),
              _buildHoverTooltipWrapper(maxDuration),
            ],
          ),
        ),
      ),
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

  Widget _buildHoverTooltipWrapper(double maxDuration) {
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
                final width = MediaQuery.of(context).size.width;
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

                final bool showThumbnail =
                    widget.controller != null &&
                    widget.controller!.enableThumbnail;
                final double tooltipWidth = showThumbnail ? 160.0 : 50.0;

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

class ProgressBarPainter extends CustomPainter {
  final ValueNotifier<double> position;
  final double duration;
  final List<BufferRange> buffered;
  final Animation<double> toggleAnimation;
  final Animation<double> hoverAnimation;
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
  final Color handleColor;
  final double barHeight;
  final double handleRadius;

  ProgressBarPainter({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.toggleAnimation,
    required this.hoverAnimation,
    required this.playedColor,
    required this.bufferedColor,
    required this.backgroundColor,
    required this.handleColor,
    required this.barHeight,
    required this.handleRadius,
  }) : super(
         repaint: Listenable.merge([position, toggleAnimation, hoverAnimation]),
       );

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;

    final toggleValue = toggleAnimation.value;
    final hoverValue = hoverAnimation.value;

    final trackHoverScale = 1.0 + (hoverValue * 1.0);
    final thumbHoverScale = 1.0 + (hoverValue * 0.2);

    final currentHeight =
        (2.0 + (barHeight - 2.0) * toggleValue) * trackHoverScale;
    final currentRadius = (handleRadius * toggleValue) * thumbHoverScale;

    final centerY = size.height / 2;
    final barRect = Rect.fromLTWH(
      0,
      centerY - currentHeight / 2,
      size.width,
      currentHeight,
    );
    final RRect barRRect = RRect.fromRectAndRadius(
      barRect,
      Radius.circular(currentHeight / 2),
    );

    // 1. Draw Background
    final Paint bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(barRRect, bgPaint);

    // 2. Draw Buffered Ranges
    final Paint bufferPaint = Paint()..color = bufferedColor;
    for (final range in buffered) {
      final start =
          (range.start.inMilliseconds / duration).clamp(0.0, 1.0) * size.width;
      final end =
          (range.end.inMilliseconds / duration).clamp(0.0, 1.0) * size.width;
      if (end > start) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              start,
              centerY - currentHeight / 2,
              end - start,
              currentHeight,
            ),
            Radius.circular(currentHeight / 2),
          ),
          bufferPaint,
        );
      }
    }

    // 3. Draw Played Progress
    final playedWidth =
        (position.value / duration).clamp(0.0, 1.0) * size.width;
    final Paint playedPaint = Paint()..color = playedColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          centerY - currentHeight / 2,
          playedWidth,
          currentHeight,
        ),
        Radius.circular(currentHeight / 2),
      ),
      playedPaint,
    );

    // 4. Draw Handle
    if (toggleValue > 0) {
      final Paint handlePaint = Paint()
        ..color = handleColor.withValues(alpha: toggleValue);
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        currentRadius,
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressBarPainter oldDelegate) => true;
}

class ProgressAnimator {
  final TickerProvider vsync;
  late final AnimationController _controller;
  bool _locked = false;

  ProgressAnimator({
    required this.vsync,
    double initialValue = 0.0,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    _controller = AnimationController(vsync: vsync, duration: duration);
    _controller.value = 0.0;
  }

  double get value => _controller.value;

  void sync(double value) {
    if (_locked) return;
    _controller.animateTo(value.clamp(0.0, 1.0));
  }

  void jumpTo(double value) {
    if (_locked) return;
    _controller.value = value.clamp(0.0, 1.0);
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
    _locked = false;
    _controller.value = value.clamp(0.0, 1.0);
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

class _InvisibleThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // Zero-draw: ensures no shadow or default material artifacts appear
  }
}

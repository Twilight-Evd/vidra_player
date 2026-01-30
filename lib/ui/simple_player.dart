import 'package:flutter/material.dart';

import '../adapters/video_player/video_player.dart';
import '../adapters/window/standard_window_delegate.dart';
import '../controller/player_controller.dart';
import '../core/model/model.dart';
import 'player_widget.dart';

/// Simplified Player Widget with lifecycle management
class SimpleVideoPlayer extends StatefulWidget {
  final PlayerConfig config;
  final VideoMetadata video;
  final List<VideoEpisode> episodes;

  const SimpleVideoPlayer({
    super.key,
    required this.config,
    required this.video,
    required this.episodes,
  });

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  late PlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = PlayerController(
      config: widget.config,
      player: VideoPlayerAdapter(),
      video: widget.video,
      episodes: widget.episodes,
      windowDelegate: const StandardWindowDelegate(),
    );
  }

  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // optimize: check for meaningful changes before reloading
    bool shouldReload = false;

    // 1. Check video identity
    if (widget.video.id != oldWidget.video.id) {
      shouldReload = true;
    }

    // 2. Check episodes (simplified check: length and first/last item)
    if (!shouldReload) {
      if (widget.episodes.length != oldWidget.episodes.length) {
        shouldReload = true;
      } else if (widget.episodes.isNotEmpty) {
        final newFirst = widget.episodes.first;
        final oldFirst = oldWidget.episodes.first;
        if (newFirst.index != oldFirst.index ||
            newFirst.title != oldFirst.title) {
          shouldReload = true;
        }
      }
    }

    if (shouldReload) {
      _controller.dispose();
      _initController();
    } else if (widget.config != oldWidget.config) {
      // Just update config if only config changed (e.g. theme, locale)
      _controller.updateConfig(widget.config);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: VideoPlayerWidget(controller: _controller),
    );
  }
}

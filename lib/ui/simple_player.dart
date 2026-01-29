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
    if (widget.config != oldWidget.config ||
        widget.video != oldWidget.video ||
        widget.episodes != oldWidget.episodes) {
      _controller.dispose();
      _initController();
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

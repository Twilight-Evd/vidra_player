# Vidra Player

Implementation of a production-quality video player SDK for Flutter, featuring a modular architecture, comprehensive state management, and strict public API boundaries.

## ✨ Features

- **Multi-Source Support**: Play videos from HTTP, assets, or file sources.
- **Episode Management**: Built-in support for multi-episode series with auto-switching.
- **Quality Switching**: Seamless switching between video qualities (1080p, 720p, etc.).
- **Smart Resume**: Remembers playback position and prompts user to resume (history > 30s).
- **Auto-Skip**: Configurable skip logic for intros and outros.
- **Customizable UI**: Full theming support via `PlayerUITheme`.
- **Keyboard Shortcuts**: Desktop-class keyboard control (Space, Arrows, F, M, etc.).
- **Strict Architecture**: Clear separation of `Public API` vs `Internal Implementation`.

## 📦 Installation

Add `vidra_player` to your `pubspec.yaml`:

```yaml
dependencies:
  vidra_player:
    path: ./path/to/vidra_player
```

## 🚀 Quick Start

### 1. Simple Usage

For basic validation, use `VideoPlayerWidget` directly with a configured controller.

```dart
import 'package:flutter/material.dart';
import 'package:vidra_player/vidra_player.dart';

class MyPlayerPage extends StatefulWidget {
  @override
  _MyPlayerPageState createState() => _MyPlayerPageState();
}

class _MyPlayerPageState extends State<MyPlayerPage> {
  late PlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PlayerController(
      config: PlayerConfig(
        autoPlay: true,
        features: const PlayerFeatures(
          enableHistory: true, // Enable strict resume logic
        ),
      ),
      player: VideoPlayerAdapter(), // Use your platform implementation
    );
    
    // Initialize with content
    _controller.initialize(
        video: VideoMetadata(id: 'v1', title: 'Example Video'),
        episodes: [
            VideoEpisode(
                title: 'Episode 1',
                qualities: [
                    VideoQuality(label: '1080p', source: VideoSource.network('https://example.com/video.mp4')),
                ],
            ),
        ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoPlayerWidget(controller: _controller),
    );
  }
}
```

## 📖 API Documentation

The SDK exposes a limited, stable public API. All internal implementation classes (Managers, Delegates, State) are hidden.

### Core Classes

| Class | Description |
|-------|-------------|
| **[PlayerController]** | The main brain of the player. Manages lifecycle, playback, and state. |
| **[VideoPlayerWidget]** | The visualization widget. Renders the video texture and UI overlays. |
| **[PlayerConfig]** | Configuration object for themes, behavior (loop, autoplay), and features. |
| **[PlayerUITheme]** | Styling engine for colors, fonts, and dimensions. |
| **[VideoMetadata]** | Model representing the video entity (ID, title, poster). |
| **[VideoEpisode]** | Model representing a single playable unit. |

### PlayerController Methods

```dart
// Playback Inteface
Future<void> play();
Future<void> pause();
Future<void> seek(Duration position);
Future<void> setVolume(double volume); // 0.0 to 1.0

// Navigation
Future<void> switchEpisode(int index);
Future<void> switchQuality(int index);

// Lifecycle
Future<void> initialize({required VideoMetadata video, required List<VideoEpisode> episodes});
void dispose();
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Space** | Play / Pause |
| **Esc** | Exit Fullscreen |
| **F** | Toggle Fullscreen |
| **M** | Toggle Mute |
| **→ / ←** | Seek +/- 10s |
| **↑ / ↓** | Volume +/- 10% |


## 🔄 Player Lifecycle Events

The player exposes a unified `lifecycleEvents` stream to help you track "what happened" without polling state. This is useful for analytics, UI orchestration, or custom business logic.

### Pattern Matching Example

Use Dart 3 pattern matching to handle events cleanly:

```dart
controller.lifecycleEvents.listen((event) {
  switch (event) {
    case PlayerCreated():
      print("Player ready");
    
    case MediaInitialized(duration: var d, aspectRatio: var r):
      print("Media loaded: $d, ratio: $r");

    case EpisodeChanged(from: var oldEp, to: var newEp):
      print("Switched from ${oldEp?.title} to ${newEp.title}");

    // Triggered ONLY when the last episode finishes naturally
    case PlaylistEnded(video: var v):
      print("Series ${v?.title} finished! Show e.g. 'Up Next' screen.");
      // Navigator.of(context).pushNamed('/post-play-screen');

    case MediaLoadFailed(error: var e):
      print("Error: ${e.message}");
      
    default:
      break;
  }
});
```

### Key Events

| Event | Trigger Condition |
|-------|-------------------|
| `MediaInitialized` | Video metadata loaded and player is ready to display. |
| `EpisodeChanged` | Episode index changes (auto-advance or user switch). |
| `EpisodeEnded` | Any episode finishes playing naturally. |
| `PlaylistEnded` | The **last** episode finishes naturally. Does NOT trigger on manual seek/skip. |

## 🏗️ Architecture

This project follows a **Delegate-Manager** architecture to ensure separation of concerns.

### 1. Delegates (Logic)
Complex logic is extracted from the Controller into focused Delegates:
- `ResumeDelegate`: Handles history checking and "Resume?" dialogs.
- `SkipDelegate`: Handles intro/outro timing and specific "Skip" notifications.
- `EpisodeDelegate`: Handles episode transition logic.

### 2. Managers (State)
Internal state is managed by specialized managers modules:
- `PlaybackManager`: Lifecycle & Position streams.
- `MediaManager`: Episode lists, Video metadata, History.
- `UIStateManager`: Visibility rules, Auto-hide timers.

### 3. Public Boundary
Using `export show ...`, we ensure that implementation details (Managers/Delegates) are **never** exposed to the end-user, allowing for safe internal refactoring.

## 🤝 Contributing

This is an internal SDK project. please verify changes using `flutter analyze` before committing.

1. Run `flutter analyze` ensuring 0 warnings.
2. Verify public API exports in `lib/vidra_player.dart`.
3. Test backward compatibility in `example/`.

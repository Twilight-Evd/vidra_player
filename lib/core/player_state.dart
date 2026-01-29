// // core/player_state.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';

// /// 播放器状态（不可变）
// @immutable
// class PlayerState {
//   final PlaybackStatus status;
//   final Duration position;
//   final Duration duration;
//   final List<DurationRange> buffered;
//   final double volume;
//   final bool isMuted;
//   final double playbackSpeed;
//   final bool isFullscreen;
//   final bool isInitialized;
//   final bool isBuffering;
//   final PlayerError? error;
//   final VideoMetadata? video;
//   final List<VideoEpisode> episodes;
//   final int currentEpisodeIndex;
//   final VideoQuality? currentQuality;
//   final List<VideoQuality> availableQualities;
//   final bool hasNextEpisode;
//   final bool hasPreviousEpisode;
//   final Duration? savedPosition;
//   final bool wasPlayingBeforeSeek;

//   const PlayerState({
//     this.status = PlaybackStatus.idle,
//     this.position = Duration.zero,
//     this.duration = Duration.zero,
//     this.buffered = const [],
//     this.volume = 1.0,
//     this.isMuted = false,
//     this.playbackSpeed = 1.0,
//     this.isFullscreen = false,
//     this.isInitialized = false,
//     this.isBuffering = false,
//     this.error,
//     this.video,
//     this.episodes = const [],
//     this.currentEpisodeIndex = 0,
//     this.currentQuality,
//     this.availableQualities = const [],
//     this.hasNextEpisode = false,
//     this.hasPreviousEpisode = false,
//     this.savedPosition,
//     this.wasPlayingBeforeSeek = false,
//   });

//   PlayerState copyWith({
//     PlaybackStatus? status,
//     Duration? position,
//     Duration? duration,
//     List<DurationRange>? buffered,
//     double? volume,
//     bool? isMuted,
//     double? playbackSpeed,
//     bool? isFullscreen,
//     bool? isInitialized,
//     bool? isBuffering,
//     PlayerError? error,
//     VideoMetadata? video,
//     List<VideoEpisode>? episodes,
//     int? currentEpisodeIndex,
//     VideoQuality? currentQuality,
//     List<VideoQuality>? availableQualities,
//     bool? hasNextEpisode,
//     bool? hasPreviousEpisode,
//     Duration? savedPosition,
//     bool? wasPlayingBeforeSeek,
//   }) {
//     return PlayerState(
//       status: status ?? this.status,
//       position: position ?? this.position,
//       duration: duration ?? this.duration,
//       buffered: buffered ?? this.buffered,
//       volume: volume ?? this.volume,
//       isMuted: isMuted ?? this.isMuted,
//       playbackSpeed: playbackSpeed ?? this.playbackSpeed,
//       isFullscreen: isFullscreen ?? this.isFullscreen,
//       isInitialized: isInitialized ?? this.isInitialized,
//       isBuffering: isBuffering ?? this.isBuffering,
//       error: error ?? this.error,
//       video: video ?? this.video,
//       episodes: episodes ?? this.episodes,
//       currentEpisodeIndex: currentEpisodeIndex ?? this.currentEpisodeIndex,
//       currentQuality: currentQuality ?? this.currentQuality,
//       availableQualities: availableQualities ?? this.availableQualities,
//       hasNextEpisode: hasNextEpisode ?? this.hasNextEpisode,
//       hasPreviousEpisode: hasPreviousEpisode ?? this.hasPreviousEpisode,
//       savedPosition: savedPosition ?? this.savedPosition,
//       wasPlayingBeforeSeek: wasPlayingBeforeSeek ?? this.wasPlayingBeforeSeek,
//     );
//   }

//   double get progress => duration.inMilliseconds > 0
//       ? position.inMilliseconds / duration.inMilliseconds
//       : 0.0;

//   bool get canPlay => isInitialized && !isBuffering && error == null;
//   bool get canPause => status == PlaybackStatus.playing;
//   bool get canSeek => duration > Duration.zero;
//   bool get showControls => !isBuffering || status != PlaybackStatus.playing;

//   @override
//   String toString() {
//     return 'PlayerState(status: $status, position: $position, duration: $duration, buffered: $buffered, volume: $volume, isMuted: $isMuted, playbackSpeed: $playbackSpeed, isFullscreen: $isFullscreen, isInitialized: $isInitialized, isBuffering: $isBuffering, error: $error, video: $video, episodes: $episodes, currentEpisodeIndex: $currentEpisodeIndex, currentQuality: $currentQuality, availableQualities: $availableQualities, hasNextEpisode: $hasNextEpisode, hasPreviousEpisode: $hasPreviousEpisode, savedPosition: $savedPosition, wasPlayingBeforeSeek: $wasPlayingBeforeSeek)';
//   }
// }

// enum PlaybackStatus {
//   idle,
//   loading,
//   ready,
//   playing,
//   paused,
//   buffering,
//   seeking,
//   ended,
//   error,
// }

// @immutable
// class VideoMetadata {
//   final String id;
//   final String title;
//   final String? description;
//   final String coverUrl;
//   final String? backdropUrl;
//   final int? year;
//   final double? rating;
//   final List<String>? genres;
//   final List<String>? actors;
//   final String? director;
//   final String? studio;
//   final String? sourceId;
//   final String? type;
//   final int? totalEpisodes;
//   final DateTime? releaseDate;

//   const VideoMetadata({
//     required this.id,
//     required this.title,
//     this.description,
//     required this.coverUrl,
//     this.backdropUrl,
//     this.year,
//     this.rating,
//     this.genres,
//     this.actors,
//     this.director,
//     this.studio,
//     this.sourceId,
//     this.type,
//     this.totalEpisodes,
//     this.releaseDate,
//   });

//   @override
//   String toString() {
//     return 'VideoMetadata(id: $id, title: $title, description: $description, coverUrl: $coverUrl, backdropUrl: $backdropUrl, year: $year, rating: $rating, genres: $genres, actors: $actors, director: $director, studio: $studio, sourceId: $sourceId, type: $type, totalEpisodes: $totalEpisodes, releaseDate: $releaseDate)';
//   }
// }

// @immutable
// class VideoEpisode {
//   final int index;
//   final String title;
//   final String? description;
//   final Duration? duration;
//   final String? thumbnailUrl;
//   final List<VideoQuality> qualities;
//   final DateTime? releaseDate;
//   final bool? isDownloaded;

//   const VideoEpisode({
//     required this.index,
//     required this.title,
//     this.description,
//     this.duration,
//     this.thumbnailUrl,
//     this.qualities = const [],
//     this.releaseDate,
//     this.isDownloaded,
//   });

//   @override
//   String toString() {
//     return 'VideoEpisode(index: $index, title: $title, description: $description, duration: $duration, thumbnailUrl: $thumbnailUrl, qualities: $qualities, releaseDate: $releaseDate, isDownloaded: $isDownloaded)';
//   }
// }

// @immutable
// class VideoQuality {
//   final String id;
//   final String label;
//   final VideoSource source;
//   final String? resolution;
//   final int? bitrate;
//   final String? codec;

//   const VideoQuality({
//     required this.id,
//     required this.label,
//     required this.source,
//     this.resolution,
//     this.bitrate,
//     this.codec,
//   });
// }

// @immutable
// class PlayerError {
//   final String code;
//   final String message;
//   final String? details;
//   final DateTime timestamp;
//   final StackTrace? stackTrace;

//   PlayerError({
//     required this.code,
//     required this.message,
//     this.details,
//     DateTime? timestamp,
//     this.stackTrace,
//   }) : timestamp = timestamp ?? DateTime.now();

//   @override
//   String toString() =>
//       'PlayerError[$code]: $message${details != null ? '\n$details' : ''}';
// }

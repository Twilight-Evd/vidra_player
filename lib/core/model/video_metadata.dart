import 'package:flutter/material.dart';

@immutable
class VideoMetadata {
  final String id;
  final String title;
  final String? description;
  final String coverUrl;
  final String? backdropUrl;
  final int? year;
  final double? rating;
  final List<String>? genres;
  final List<String>? actors;
  final String? director;
  final String? studio;
  final String? sourceId;
  final String? type;
  final int? totalEpisodes;
  final DateTime? releaseDate;

  const VideoMetadata({
    required this.id,
    required this.title,
    this.description,
    required this.coverUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    this.genres,
    this.actors,
    this.director,
    this.studio,
    this.sourceId,
    this.type,
    this.totalEpisodes,
    this.releaseDate,
  });
}

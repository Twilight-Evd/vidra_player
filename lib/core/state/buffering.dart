import 'package:flutter/material.dart';

@immutable
class BufferingState {
  final bool isBuffering;

  const BufferingState({this.isBuffering = false});
}

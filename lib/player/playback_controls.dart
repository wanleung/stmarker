import 'package:flutter/foundation.dart';

/// Minimal playback surface the UI needs. Implemented for real by
/// [MediaPlayerController]; test code implements a fake instead so
/// [PlayerControlsBar] and [MarkingScaffold] can be tested without a real
/// media backend.
abstract class PlaybackControls extends ChangeNotifier {
  int get positionMs;
  int get durationMs;
  bool get isPlaying;
  double get playbackRate;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(int ms);
  Future<void> setRate(double rate);
}

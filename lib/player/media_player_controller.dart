import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'playback_controls.dart';

class MediaPlayerController extends PlaybackControls {
  MediaPlayerController() : player = Player() {
    _positionSub = player.stream.position.listen((d) {
      _positionMs = d.inMilliseconds;
      notifyListeners();
    });
    _durationSub = player.stream.duration.listen((d) {
      _durationMs = d.inMilliseconds;
      notifyListeners();
    });
    _playingSub = player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _rateSub = player.stream.rate.listen((rate) {
      _playbackRate = rate;
      notifyListeners();
    });
  }

  final Player player;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<double> _rateSub;

  int _positionMs = 0;
  int _durationMs = 0;
  bool _isPlaying = false;
  double _playbackRate = 1.0;

  @override
  int get positionMs => _positionMs;
  @override
  int get durationMs => _durationMs;
  @override
  bool get isPlaying => _isPlaying;
  @override
  double get playbackRate => _playbackRate;

  Future<void> open(String path) => player.open(Media(path));
  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(int ms) => player.seek(Duration(milliseconds: ms));
  @override
  Future<void> setRate(double rate) => player.setRate(rate);

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _rateSub.cancel();
    player.dispose();
    super.dispose();
  }
}

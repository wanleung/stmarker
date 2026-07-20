import 'package:stmarker/player/playback_controls.dart';

/// Test double for [PlaybackControls]. [seekTestPosition] simulates the
/// media clock advancing on its own (e.g. during playback); [seek] is the
/// override that records what a caller *requested*, in [lastSeek].
class FakePlaybackControls extends PlaybackControls {
  int _positionMs = 0;
  int durationMsValue = 10000;
  bool playingValue = false;
  double rateValue = 1.0;
  int? lastSeek;
  double? lastRate;

  void seekTestPosition(int ms) {
    _positionMs = ms;
    notifyListeners();
  }

  @override
  int get positionMs => _positionMs;
  @override
  int get durationMs => durationMsValue;
  @override
  bool get isPlaying => playingValue;
  @override
  double get playbackRate => rateValue;

  @override
  Future<void> play() async {
    playingValue = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playingValue = false;
    notifyListeners();
  }

  @override
  Future<void> seek(int ms) async {
    lastSeek = ms;
    _positionMs = ms;
    notifyListeners();
  }

  @override
  Future<void> setRate(double rate) async {
    lastRate = rate;
    rateValue = rate;
    notifyListeners();
  }
}

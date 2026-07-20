import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../models/subtitle_line.dart';

class MarkingSession extends ChangeNotifier {
  MarkingSession(this._project)
    : _currentIndex = _firstUnmarkedIndex(_project.lines);

  Project _project;
  int _currentIndex;

  Project get project => _project;
  List<SubtitleLine> get lines => _project.lines;

  /// Index of the line space-down/space-up currently act on, or null once
  /// every line is fully marked.
  int? get currentIndex =>
      _currentIndex < _project.lines.length ? _currentIndex : null;

  static int _firstUnmarkedIndex(List<SubtitleLine> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].isFullyMarked) return i;
    }
    return lines.length;
  }

  void markStart(int positionMs) {
    final idx = currentIndex;
    if (idx == null) return;
    final line = _project.lines[idx];
    if (line.startMs != null) return;
    _replaceLine(idx, line.copyWith(startMs: positionMs));
  }

  void markEnd(int positionMs) {
    final idx = currentIndex;
    if (idx == null) return;
    final line = _project.lines[idx];
    _replaceLine(idx, line.copyWith(endMs: positionMs));
  }

  /// Clears the current line's timestamps so it can be re-marked. Returns
  /// where the player should seek back to: the line's previous start time,
  /// or null if nothing had been marked yet (caller picks a fallback).
  ///
  /// "Current" for redo purposes is not simply [currentIndex]: if the
  /// pointer line hasn't been touched yet (no startMs), the line the user
  /// actually just finished is the *previous* one (or, once every line is
  /// fully marked and the pointer is null, the last line). Redo targets
  /// that line instead, so "undo my last mark" works right after
  /// completing a line as well as mid-mark.
  int? redoCurrentLine() {
    final idx = _redoTargetIndex();
    if (idx == null) return null;
    final line = _project.lines[idx];
    final seekTarget = line.startMs;
    _replaceLine(idx, line.clearTimestamps());
    return seekTarget;
  }

  int? _redoTargetIndex() {
    final idx = currentIndex;
    if (idx != null) {
      if (_project.lines[idx].startMs != null) return idx;
      return idx > 0 ? idx - 1 : null;
    }
    return _project.lines.isEmpty ? null : _project.lines.length - 1;
  }

  /// Directly sets a line's timestamps from the review/edit table,
  /// independent of the sequential current-line pointer.
  void setLineTimestamps(int index, {int? startMs, int? endMs}) {
    final line = _project.lines[index];
    _replaceLine(
      index,
      line.withExactTimestamps(startMs: startMs, endMs: endMs),
    );
  }

  /// Clears several reviewed lines in one operation so they can be marked
  /// again, then moves the sequential pointer to the earliest cleared line.
  void clearLineTimestamps(Iterable<int> indices) {
    final validIndices = indices
        .where((index) => index >= 0 && index < _project.lines.length)
        .toSet();
    if (validIndices.isEmpty) return;

    final updated = List<SubtitleLine>.from(_project.lines);
    for (final index in validIndices) {
      updated[index] = updated[index].clearTimestamps();
    }
    _project = _project.copyWith(lines: updated);
    _currentIndex = _firstUnmarkedIndex(updated);
    notifyListeners();
  }

  void importLines(List<SubtitleLine> newLines) {
    _project = _project.copyWith(lines: newLines);
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }

  void setMediaPath(String path) {
    _project = _project.copyWith(mediaPath: path);
    notifyListeners();
  }

  void setPlaybackRate(double rate) {
    _project = _project.copyWith(playbackRate: rate);
    notifyListeners();
  }

  void loadProject(Project project) {
    _project = project;
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }

  void _replaceLine(int index, SubtitleLine newLine) {
    final updated = List<SubtitleLine>.from(_project.lines);
    updated[index] = newLine;
    _project = _project.copyWith(lines: updated);
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }
}

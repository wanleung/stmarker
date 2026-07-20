import 'package:flutter/foundation.dart';

import '../karaoke/karaoke_models.dart';
import '../karaoke/karaoke_timing.dart';
import '../models/project.dart';
import '../models/subtitle_line.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';

@immutable
final class AdvancedMarkingState {
  AdvancedMarkingState({
    required this.lineIndex,
    required List<KaraokeToken> tokens,
    required this.originalStartMs,
    required List<int> recordedStarts,
  }) : tokens = List.unmodifiable(tokens),
       recordedStarts = List.unmodifiable(recordedStarts);

  final int lineIndex;
  final List<KaraokeToken> tokens;
  final int originalStartMs;
  final List<int> recordedStarts;

  int get nextUnitIndex => recordedStarts.length;
  bool get isComplete => recordedStarts.length == tokens.length;
}

class MarkingSession extends ChangeNotifier {
  MarkingSession(this._project)
    : _currentIndex = _firstUnmarkedIndex(_project.lines);

  Project _project;
  int _currentIndex;
  AdvancedMarkingState? _advancedMarking;

  Project get project => _project;
  List<SubtitleLine> get lines => _project.lines;
  AdvancedMarkingState? get advancedMarking => _advancedMarking;

  void setKaraokeSettings({
    required KaraokeMode mode,
    required KaraokePreDisplay preDisplay,
  }) {
    _advancedMarking = null;
    _project = _project.copyWith(
      karaokeMode: mode,
      karaokePreDisplay: preDisplay,
    );
    notifyListeners();
  }

  int? beginAdvancedMarking(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= _project.lines.length) return null;
    final line = _project.lines[lineIndex];
    final startMs = line.startMs;
    final endMs = line.endMs;
    if (startMs == null || endMs == null || startMs < 0 || endMs <= startMs) {
      return null;
    }

    final tokens = List<KaraokeToken>.unmodifiable(
      tokenizeKaraokeText(line.text),
    );
    _advancedMarking = AdvancedMarkingState(
      lineIndex: lineIndex,
      tokens: tokens,
      originalStartMs: startMs,
      recordedStarts: const [],
    );
    notifyListeners();
    return (startMs - 2000).clamp(0, startMs);
  }

  bool recordKaraokeUnitStart(int positionMs) {
    final state = _advancedMarking;
    if (state == null || state.isComplete) return false;
    final line = _project.lines[state.lineIndex];
    final endMs = line.endMs!;
    if (positionMs < 0 || positionMs >= endMs) return false;
    if (state.recordedStarts.isNotEmpty &&
        positionMs <= state.recordedStarts.last) {
      return false;
    }

    final starts = List<int>.unmodifiable([
      ...state.recordedStarts,
      positionMs,
    ]);
    _advancedMarking = AdvancedMarkingState(
      lineIndex: state.lineIndex,
      tokens: state.tokens,
      originalStartMs: state.originalStartMs,
      recordedStarts: starts,
    );
    _replaceAdvancedLine(state.lineIndex, starts.first, starts, state.tokens);
    return true;
  }

  int? undoKaraokeUnitStart() {
    final state = _advancedMarking;
    if (state == null || state.recordedStarts.isEmpty) return null;
    final removed = state.recordedStarts.last;
    final starts = List<int>.unmodifiable(
      state.recordedStarts.take(state.recordedStarts.length - 1),
    );
    _advancedMarking = AdvancedMarkingState(
      lineIndex: state.lineIndex,
      tokens: state.tokens,
      originalStartMs: state.originalStartMs,
      recordedStarts: starts,
    );
    final startMs = starts.isEmpty ? state.originalStartMs : starts.first;
    _replaceAdvancedLine(state.lineIndex, startMs, starts, state.tokens);
    return removed;
  }

  int? restartAdvancedMarking() {
    final state = _advancedMarking;
    if (state == null) return null;
    _advancedMarking = AdvancedMarkingState(
      lineIndex: state.lineIndex,
      tokens: state.tokens,
      originalStartMs: state.originalStartMs,
      recordedStarts: const [],
    );
    _replaceAdvancedLine(
      state.lineIndex,
      state.originalStartMs,
      const [],
      state.tokens,
    );
    return (state.originalStartMs - 2000).clamp(0, state.originalStartMs);
  }

  void cancelAdvancedMarking() {
    if (_advancedMarking == null) return;
    _advancedMarking = null;
    notifyListeners();
  }

  void _replaceAdvancedLine(
    int lineIndex,
    int startMs,
    List<int> starts,
    List<KaraokeToken> tokens,
  ) {
    final marks = [
      for (var index = 0; index < starts.length; index++)
        KaraokeMark(unitText: tokens[index].identity, startMs: starts[index]),
    ];
    _replaceLine(
      lineIndex,
      _project.lines[lineIndex].withAdvancedKaraoke(
        startMs: startMs,
        marks: marks,
      ),
    );
  }

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
    _advancedMarking = null;
    final idx = currentIndex;
    if (idx == null) return;
    final line = _project.lines[idx];
    if (line.startMs != null) return;
    _replaceLine(idx, line.copyWith(startMs: positionMs));
  }

  void markEnd(int positionMs) {
    _advancedMarking = null;
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
    _advancedMarking = null;
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
    _advancedMarking = null;
    final line = _project.lines[index];
    _replaceLine(
      index,
      line.withExactTimestamps(startMs: startMs, endMs: endMs),
    );
  }

  /// Directly updates a reviewed line's text. Any active Advanced pass is
  /// cancelled; [SubtitleLine.withText] decides whether stored marks remain
  /// valid (unchanged text) or must be cleared (changed text).
  void setLineText(int index, String text) {
    _advancedMarking = null;
    _replaceLine(index, _project.lines[index].withText(text));
  }

  /// Clears several reviewed lines in one operation so they can be marked
  /// again, then moves the sequential pointer to the earliest cleared line.
  void clearLineTimestamps(Iterable<int> indices) {
    final validIndices = indices
        .where((index) => index >= 0 && index < _project.lines.length)
        .toSet();
    if (validIndices.isEmpty) return;
    _advancedMarking = null;

    final updated = List<SubtitleLine>.from(_project.lines);
    for (final index in validIndices) {
      updated[index] = updated[index].clearTimestamps();
    }
    _project = _project.copyWith(lines: updated);
    _currentIndex = _firstUnmarkedIndex(updated);
    notifyListeners();
  }

  void importLines(List<SubtitleLine> newLines) {
    _advancedMarking = null;
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

  void setSubtitleAppearance({
    required String fontFamily,
    required double fontSize,
  }) {
    final validatedSize = fontSize.isFinite
        ? fontSize.clamp(minimumSubtitleFontSize, maximumSubtitleFontSize)
        : defaultSubtitleFontSize;
    _project = _project.copyWith(
      subtitleFontFamily: SubtitleFontCatalog.byId(fontFamily).id,
      subtitleFontSize: validatedSize,
    );
    notifyListeners();
  }

  void loadProject(Project project) {
    _advancedMarking = null;
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

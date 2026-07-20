import 'package:flutter/services.dart';

import '../state/marking_session.dart';

class MarkingKeyHandler {
  MarkingKeyHandler({
    required this.session,
    required this.getPositionMs,
    required this.seekTo,
    this.redoFallbackOffsetMs = 1500,
  });

  final MarkingSession session;
  final int Function() getPositionMs;
  final void Function(int positionMs) seekTo;
  final int redoFallbackOffsetMs;

  bool handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        session.markStart(getPositionMs());
        return true;
      }
      if (event is KeyUpEvent) {
        session.markEnd(getPositionMs());
        return true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.backspace && event is KeyDownEvent) {
      final seekTarget = session.redoCurrentLine();
      final fallback = getPositionMs() - redoFallbackOffsetMs;
      seekTo(seekTarget ?? (fallback < 0 ? 0 : fallback));
      return true;
    }
    return false;
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/keyboard/marking_key_handler.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';

KeyDownEvent _spaceDown() => const KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: LogicalKeyboardKey.space,
  timeStamp: Duration.zero,
);

KeyUpEvent _spaceUp() => const KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: LogicalKeyboardKey.space,
  timeStamp: Duration.zero,
);

KeyRepeatEvent _spaceRepeat() => const KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: LogicalKeyboardKey.space,
  timeStamp: Duration.zero,
);

KeyDownEvent _backspaceDown() => const KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.backspace,
  logicalKey: LogicalKeyboardKey.backspace,
  timeStamp: Duration.zero,
);

void main() {
  test('Advanced consumes Space down once and ignores Space up', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one two', startMs: 3000, endMs: 8000),
        ],
      ),
    );
    session.beginAdvancedMarking(0);
    var position = 5100;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => position,
      seekTo: (_) {},
    );
    expect(handler.handleKeyEvent(_spaceDown()), isTrue);
    position = 5200;
    expect(handler.handleKeyEvent(_spaceUp()), isFalse);
    expect(session.advancedMarking?.recordedStarts, [5100]);
  });

  test('Advanced ignores repeated Space events', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 3000, endMs: 8000),
        ],
      ),
    )..beginAdvancedMarking(0);
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => 5100,
      seekTo: (_) {},
    );
    expect(handler.handleKeyEvent(_spaceRepeat()), isFalse);
    expect(session.advancedMarking?.recordedStarts, isEmpty);
  });

  test('Advanced Backspace undoes a unit and seeks to its position', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one two', startMs: 3000, endMs: 8000),
        ],
      ),
    );
    session.beginAdvancedMarking(0);
    session.recordKaraokeUnitStart(5100);
    int? seekedTo;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => 6000,
      seekTo: (ms) => seekedTo = ms,
    );
    expect(handler.handleKeyEvent(_backspaceDown()), isTrue);
    expect(seekedTo, 5100);
    expect(session.advancedMarking?.recordedStarts, isEmpty);
  });
  test('space down marks the current line start at the live position', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'a')],
      ),
    );
    var position = 0;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => position,
      seekTo: (_) {},
    );

    position = 1200;
    final handled = handler.handleKeyEvent(_spaceDown());

    expect(handled, isTrue);
    expect(session.lines[0].startMs, 1200);
  });

  test('space up marks the current line end and advances', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'a'),
          SubtitleLine(index: 1, text: 'b'),
        ],
      ),
    );
    var position = 0;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => position,
      seekTo: (_) {},
    );

    handler.handleKeyEvent(_spaceDown());
    position = 3400;
    handler.handleKeyEvent(_spaceUp());

    expect(session.lines[0].endMs, 3400);
    expect(session.currentIndex, 1);
  });

  test('backspace clears the current line and seeks to its previous start', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'a', startMs: 500, endMs: 900)],
      ),
    );
    int? seekedTo;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => 900,
      seekTo: (ms) => seekedTo = ms,
    );

    handler.handleKeyEvent(_backspaceDown());

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
    expect(seekedTo, 500);
  });

  test(
    'backspace with nothing marked yet seeks back by the fallback offset',
    () {
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [SubtitleLine(index: 0, text: 'a')],
        ),
      );
      int? seekedTo;
      final handler = MarkingKeyHandler(
        session: session,
        getPositionMs: () => 2000,
        seekTo: (ms) => seekedTo = ms,
        redoFallbackOffsetMs: 1500,
      );

      handler.handleKeyEvent(_backspaceDown());

      expect(seekedTo, 500);
    },
  );

  test('unrelated keys are not handled', () {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'a')],
      ),
    );
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => 0,
      seekTo: (_) {},
    );
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );
    expect(handler.handleKeyEvent(event), isFalse);
  });
}

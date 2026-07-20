import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/karaoke/karaoke_timing.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

Project _project(List<SubtitleLine> lines) =>
    Project(mediaPath: '/tmp/x.mp3', lines: lines);

void main() {
  test('karaoke settings update together and notify once', () {
    final session = MarkingSession(_project(const []));
    var notifications = 0;
    session.addListener(() => notifications++);

    session.setKaraokeSettings(
      mode: KaraokeMode.karaokeEasy,
      preDisplay: KaraokePreDisplay.seconds3,
    );

    expect(session.project.karaokeMode, KaraokeMode.karaokeEasy);
    expect(session.project.karaokePreDisplay, KaraokePreDisplay.seconds3);
    expect(session.advancedMarking, isNull);
    expect(notifications, 1);
  });

  group('advanced karaoke marking', () {
    late MarkingSession session;

    setUp(() {
      session = MarkingSession(
        _project(const [
          SubtitleLine(
            index: 0,
            text: 'hello world',
            startMs: 5000,
            endMs: 8000,
          ),
        ]),
      );
    });

    test('persists each accepted unit and undo returns its seek position', () {
      expect(session.beginAdvancedMarking(0), 3000);
      expect(session.advancedMarking!.nextUnitIndex, 0);

      expect(session.recordKaraokeUnitStart(5100), isTrue);
      expect(session.lines[0].startMs, 5100);
      expect(session.lines[0].karaokeMarks, const [
        KaraokeMark(unitText: 'hello', startMs: 5100),
      ]);
      expect(session.recordKaraokeUnitStart(6200), isTrue);
      expect(session.advancedMarking!.isComplete, isTrue);
      expect(session.undoKaraokeUnitStart(), 6200);
      expect(session.lines[0].karaokeMarks, const [
        KaraokeMark(unitText: 'hello', startMs: 5100),
      ]);
    });

    test('state snapshots source lists and exposes unmodifiable lists', () {
      final tokens = [const KaraokeToken(text: 'hello', identity: 'hello')];
      final starts = [5100];

      final state = AdvancedMarkingState(
        lineIndex: 0,
        tokens: tokens,
        originalStartMs: 5000,
        recordedStarts: starts,
      );
      tokens.add(const KaraokeToken(text: 'world', identity: 'world'));
      starts.add(6200);

      expect(state.tokens, hasLength(1));
      expect(state.recordedStarts, [5100]);
      expect(
        () => state.tokens.add(
          const KaraokeToken(text: 'world', identity: 'world'),
        ),
        throwsUnsupportedError,
      );
      expect(() => state.recordedStarts.add(6200), throwsUnsupportedError);
    });

    test('accepted presses notify once and rejected presses do not notify', () {
      session.beginAdvancedMarking(0);
      var notifications = 0;
      session.addListener(() => notifications++);

      expect(session.recordKaraokeUnitStart(5100), isTrue);
      expect(notifications, 1);
      expect(session.recordKaraokeUnitStart(5100), isFalse);
      expect(session.recordKaraokeUnitStart(8000), isFalse);
      expect(notifications, 1);
      expect(session.recordKaraokeUnitStart(6200), isTrue);
      expect(notifications, 2);
      expect(session.recordKaraokeUnitStart(7000), isFalse);
      expect(notifications, 2);
    });

    test('retiming, undo, restart, and completion keep pointer consistent', () {
      final pointerSession = MarkingSession(
        _project(const [
          SubtitleLine(
            index: 0,
            text: 'hello world',
            startMs: 5000,
            endMs: 8000,
          ),
          SubtitleLine(index: 1, text: 'later'),
        ]),
      );
      expect(pointerSession.currentIndex, 1);
      pointerSession.beginAdvancedMarking(0);

      pointerSession.recordKaraokeUnitStart(5100);
      expect(pointerSession.currentIndex, 1);
      pointerSession.recordKaraokeUnitStart(6200);
      expect(pointerSession.currentIndex, 1);
      pointerSession.undoKaraokeUnitStart();
      expect(pointerSession.currentIndex, 1);
      pointerSession.undoKaraokeUnitStart();
      expect(pointerSession.currentIndex, 1);
      pointerSession.recordKaraokeUnitStart(5200);
      pointerSession.restartAdvancedMarking();
      expect(pointerSession.currentIndex, 1);
      pointerSession.recordKaraokeUnitStart(5300);
      pointerSession.recordKaraokeUnitStart(6400);
      expect(pointerSession.advancedMarking!.isComplete, isTrue);
      expect(pointerSession.currentIndex, 1);
    });

    test('pre-roll clamps at media zero', () {
      session.setLineTimestamps(0, startMs: 1200, endMs: 4000);
      expect(session.beginAdvancedMarking(0), 0);
    });

    test('rejects invalid, out-of-order, after-end, and extra presses', () {
      expect(session.beginAdvancedMarking(-1), isNull);
      expect(session.beginAdvancedMarking(1), isNull);
      expect(session.beginAdvancedMarking(0), 3000);
      expect(session.recordKaraokeUnitStart(-1), isFalse);
      expect(session.recordKaraokeUnitStart(8000), isFalse);
      expect(session.recordKaraokeUnitStart(5100), isTrue);
      expect(session.recordKaraokeUnitStart(5100), isFalse);
      expect(session.recordKaraokeUnitStart(8001), isFalse);
      expect(session.recordKaraokeUnitStart(6200), isTrue);
      expect(session.recordKaraokeUnitStart(7000), isFalse);
    });

    test('undoing first unit restores original start and clears marks', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);

      expect(session.undoKaraokeUnitStart(), 5100);
      expect(session.lines[0].startMs, 5000);
      expect(session.lines[0].endMs, 8000);
      expect(session.lines[0].karaokeMarks, isEmpty);
    });

    test('restart clears marks, restores start, and keeps session active', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);
      session.recordKaraokeUnitStart(6200);

      expect(session.restartAdvancedMarking(), 3000);
      expect(session.advancedMarking!.nextUnitIndex, 0);
      expect(session.lines[0].startMs, 5000);
      expect(session.lines[0].karaokeMarks, isEmpty);
    });

    test('cancel preserves accepted marks and rejects later presses', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);

      session.cancelAdvancedMarking();

      expect(session.advancedMarking, isNull);
      expect(session.lines[0].karaokeMarks, hasLength(1));
      expect(session.recordKaraokeUnitStart(6200), isFalse);
    });

    test('switching modes cancels transient state but preserves marks', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);

      session.setKaraokeSettings(
        mode: KaraokeMode.karaokeEasy,
        preDisplay: KaraokePreDisplay.off,
      );

      expect(session.advancedMarking, isNull);
      expect(session.lines[0].karaokeMarks, hasLength(1));
    });

    test('direct timestamp edits cancel state and invalidate marks', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);

      session.setLineTimestamps(0, startMs: 5200, endMs: 8000);

      expect(session.advancedMarking, isNull);
      expect(session.lines[0].karaokeMarks, isEmpty);
    });

    test('changed direct text edit cancels marking and invalidates marks', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);
      var notifications = 0;
      session.addListener(() => notifications++);

      session.setLineText(0, 'goodbye world');

      expect(session.advancedMarking, isNull);
      expect(session.lines[0].text, 'goodbye world');
      expect(session.lines[0].karaokeMarks, isEmpty);
      expect(session.currentIndex, isNull);
      expect(notifications, 1);
    });

    test('unchanged direct text edit cancels marking and preserves marks', () {
      session.beginAdvancedMarking(0);
      session.recordKaraokeUnitStart(5100);
      var notifications = 0;
      session.addListener(() => notifications++);

      session.setLineText(0, 'hello world');

      expect(session.advancedMarking, isNull);
      expect(session.lines[0].karaokeMarks, hasLength(1));
      expect(session.currentIndex, isNull);
      expect(notifications, 1);
    });

    test('line import and project load cancel transient state', () {
      session.beginAdvancedMarking(0);
      session.importLines(const [SubtitleLine(index: 0, text: 'new')]);
      expect(session.advancedMarking, isNull);

      session.loadProject(
        _project(const [
          SubtitleLine(index: 0, text: 'loaded', startMs: 1, endMs: 2),
        ]),
      );
      expect(session.advancedMarking, isNull);
      expect(session.lines.single.text, 'loaded');
    });
  });

  test('currentIndex starts at the first unmarked line', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
        SubtitleLine(index: 1, text: 'b'),
      ]),
    );
    expect(session.currentIndex, 1);
  });

  test('markStart sets startMs on the current line only', () {
    final session = MarkingSession(
      _project(const [SubtitleLine(index: 0, text: 'a')]),
    );
    session.markStart(500);
    expect(session.lines[0].startMs, 500);
    expect(session.lines[0].endMs, isNull);
    expect(session.currentIndex, 0);
  });

  test('markStart is a no-op if start is already set', () {
    final session = MarkingSession(
      _project(const [SubtitleLine(index: 0, text: 'a', startMs: 500)]),
    );
    session.markStart(999);
    expect(session.lines[0].startMs, 500);
  });

  test('markEnd sets endMs and advances currentIndex to the next line', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 100),
        SubtitleLine(index: 1, text: 'b'),
      ]),
    );
    session.markEnd(700);
    expect(
      session.lines[0],
      const SubtitleLine(index: 0, text: 'a', startMs: 100, endMs: 700),
    );
    expect(session.currentIndex, 1);
  });

  test('markEnd on an import-provided start-only line still advances', () {
    final session = MarkingSession(
      _project(const [SubtitleLine(index: 0, text: 'a', startMs: 200)]),
    );
    expect(session.currentIndex, 0);
    session.markEnd(900);
    expect(
      session.lines[0],
      const SubtitleLine(index: 0, text: 'a', startMs: 200, endMs: 900),
    );
    expect(session.currentIndex, isNull);
  });

  test('currentIndex is null once every line is fully marked', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
      ]),
    );
    expect(session.currentIndex, isNull);
  });

  test(
    'redoCurrentLine clears timestamps and returns the previous start as seek target',
    () {
      final session = MarkingSession(
        _project(const [
          SubtitleLine(index: 0, text: 'a', startMs: 300, endMs: 900),
        ]),
      );
      final seekTarget = session.redoCurrentLine();
      expect(seekTarget, 300);
      expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
      expect(session.currentIndex, 0);
    },
  );

  test(
    'redoCurrentLine returns null seek target when nothing was marked yet',
    () {
      final session = MarkingSession(
        _project(const [SubtitleLine(index: 0, text: 'a')]),
      );
      expect(session.redoCurrentLine(), isNull);
    },
  );

  test(
    'setLineTimestamps edits an arbitrary row without disturbing the sequential pointer',
    () {
      final session = MarkingSession(
        _project(const [
          SubtitleLine(index: 0, text: 'a'),
          SubtitleLine(index: 1, text: 'b', startMs: 100, endMs: 200),
        ]),
      );
      expect(session.currentIndex, 0);
      session.setLineTimestamps(1, startMs: 150, endMs: 250);
      expect(
        session.lines[1],
        const SubtitleLine(index: 1, text: 'b', startMs: 150, endMs: 250),
      );
      expect(session.currentIndex, 0);
    },
  );

  test('importLines replaces all lines and resets the pointer', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
      ]),
    );
    session.importLines(const [
      SubtitleLine(index: 0, text: 'new a'),
      SubtitleLine(index: 1, text: 'new b'),
    ]);
    expect(session.lines.map((l) => l.text), ['new a', 'new b']);
    expect(session.currentIndex, 0);
  });

  test(
    'redoCurrentLine undoes the previously completed line when the current line is untouched',
    () {
      final session = MarkingSession(
        _project(const [
          SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
          SubtitleLine(index: 1, text: 'b'),
        ]),
      );
      expect(session.currentIndex, 1);
      final seekTarget = session.redoCurrentLine();
      expect(seekTarget, 0);
      expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
      expect(session.lines[1], const SubtitleLine(index: 1, text: 'b'));
      expect(session.currentIndex, 0);
    },
  );

  test('markStart and markEnd are no-ops once every line is fully marked', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
      ]),
    );
    expect(session.currentIndex, isNull);
    expect(() => session.markStart(999), returnsNormally);
    expect(() => session.markEnd(999), returnsNormally);
    expect(
      session.lines[0],
      const SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
    );
    expect(session.currentIndex, isNull);
  });

  test(
    'redoCurrentLine undoes the in-progress current line, not the previous completed one',
    () {
      final session = MarkingSession(
        _project(const [
          SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
          SubtitleLine(index: 1, text: 'b', startMs: 400),
        ]),
      );
      expect(session.currentIndex, 1);
      final seekTarget = session.redoCurrentLine();
      expect(seekTarget, 400);
      expect(
        session.lines[0],
        const SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
      );
      expect(session.lines[1], const SubtitleLine(index: 1, text: 'b'));
      expect(session.currentIndex, 1);
    },
  );

  test('clearLineTimestamps clears every flagged line in one update', () {
    final session = MarkingSession(
      _project(const [
        SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
        SubtitleLine(index: 1, text: 'b', startMs: 200, endMs: 300),
        SubtitleLine(index: 2, text: 'c', startMs: 400, endMs: 500),
      ]),
    );
    var notifications = 0;
    session.addListener(() => notifications++);

    session.clearLineTimestamps({2, 0});

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
    expect(
      session.lines[1],
      const SubtitleLine(index: 1, text: 'b', startMs: 200, endMs: 300),
    );
    expect(session.lines[2], const SubtitleLine(index: 2, text: 'c'));
    expect(session.currentIndex, 0);
    expect(notifications, 1);
  });

  test('setSubtitleAppearance validates both values and notifies once', () {
    final session = MarkingSession(_project(const []));
    var notifications = 0;
    session.addListener(() => notifications++);

    session.setSubtitleAppearance(fontFamily: 'noto_serif_cjk', fontSize: 36.0);

    expect(session.project.subtitleFontFamily, 'noto_serif_cjk');
    expect(session.project.subtitleFontSize, 36.0);
    expect(notifications, 1);

    session.setSubtitleAppearance(fontFamily: 'unknown', fontSize: 100.0);
    expect(
      session.project.subtitleFontFamily,
      SubtitleFontCatalog.defaultFace.id,
    );
    expect(session.project.subtitleFontSize, 64.0);
    expect(notifications, 2);

    session.setSubtitleAppearance(
      fontFamily: 'noto_serif_cjk',
      fontSize: double.nan,
    );
    expect(session.project.subtitleFontFamily, 'noto_serif_cjk');
    expect(session.project.subtitleFontSize, 24.0);
    expect(notifications, 3);
  });
}

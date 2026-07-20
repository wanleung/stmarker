import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';

Project _project(List<SubtitleLine> lines) =>
    Project(mediaPath: '/tmp/x.mp3', lines: lines);

void main() {
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
}

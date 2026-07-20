import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/ui/marking_scaffold.dart';

import '../support/fake_playback_controls.dart';

void main() {
  testWidgets(
    'space down/up marks the current line using the live fake position',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first line'),
            SubtitleLine(index: 1, text: 'second line'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: session,
            child: Scaffold(body: MarkingScaffold(controls: controls)),
          ),
        ),
      );
      await tester.pump();

      controls.seekTestPosition(1200);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      controls.seekTestPosition(3400);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(
        session.lines[0],
        const SubtitleLine(
          index: 0,
          text: 'first line',
          startMs: 1200,
          endMs: 3400,
        ),
      );
      expect(session.currentIndex, 1);
    },
  );

  testWidgets('backspace redoes the current line and seeks back', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first line', startMs: 500, endMs: 900),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(body: MarkingScaffold(controls: controls)),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'first line'));
    expect(controls.lastSeek, 500);
  });

  testWidgets(
    'changing the live playback rate persists it onto the session/project',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [SubtitleLine(index: 0, text: 'first line')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: session,
            child: Scaffold(body: MarkingScaffold(controls: controls)),
          ),
        ),
      );
      await tester.pump();

      await controls.setRate(1.25);
      await tester.pump();

      expect(session.project.playbackRate, 1.25);
    },
  );

  testWidgets(
    'tapping a row opens an edit dialog that saves start/end via setLineTimestamps',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [SubtitleLine(index: 0, text: 'first line')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: session,
            child: Scaffold(body: MarkingScaffold(controls: controls)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('line-row-0')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('edit-start-field')),
        '1000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-end-field')),
        '2500',
      );

      await tester.tap(find.byKey(const ValueKey('edit-save-button')));
      await tester.pumpAndSettle();

      expect(session.lines[0].startMs, 1000);
      expect(session.lines[0].endMs, 2500);
    },
  );

  testWidgets(
    'clicking the play/pause button does not steal focus from the marking Focus node',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [SubtitleLine(index: 0, text: 'first line')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: session,
            child: Scaffold(body: MarkingScaffold(controls: controls)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('play-pause-button')));
      await tester.pump();

      controls.seekTestPosition(1200);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      controls.seekTestPosition(3400);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(session.lines[0].startMs, 1200);
      expect(session.lines[0].endMs, 3400);
    },
  );

  testWidgets('review plays only the selected subtitle interval', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 500, endMs: 900),
          SubtitleLine(index: 1, text: 'second', startMs: 1200, endMs: 1800),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(controls: controls, reviewMode: true),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();
    expect(controls.lastSeek, 1200);

    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    expect(controls.lastSeek, 1200);
    expect(controls.playingValue, isTrue);

    controls.seekTestPosition(1800);
    await tester.pump();
    expect(controls.playingValue, isFalse);
  });

  testWidgets('finishing review clears all lines flagged for redo', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 500, endMs: 900),
          SubtitleLine(index: 1, text: 'second', startMs: 1200, endMs: 1800),
        ],
      ),
    );
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(
              controls: controls,
              reviewMode: true,
              onReviewFinished: () => finished = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('review-flag')));
    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-flag')));
    await tester.tap(find.byKey(const ValueKey('review-finish')));
    await tester.pump();

    expect(session.lines.every((line) => !line.isFullyMarked), isTrue);
    expect(session.currentIndex, 0);
    expect(finished, isTrue);
  });

  testWidgets('marking keyboard shortcuts are disabled during review', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 500, endMs: 900),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(controls: controls, reviewMode: true),
          ),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(session.lines.single.isFullyMarked, isTrue);
  });

  testWidgets('review shows the selected line beneath the video', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(
            index: 0,
            text: 'focused review text',
            startMs: 500,
            endMs: 900,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(
              controls: controls,
              reviewMode: true,
              videoArea: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );

    final panel = find.byKey(const ValueKey('review-subtitle-panel'));
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.text('focused review text')),
      findsOneWidget,
    );
  });

  testWidgets('normal marking mode does not show the review subtitle panel', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'not over video')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(body: MarkingScaffold(controls: controls)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('review-subtitle-panel')), findsNothing);
  });
}

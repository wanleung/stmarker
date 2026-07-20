import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';
import 'package:stmarker/ui/marking_scaffold.dart';
import 'package:stmarker/ui/karaoke_preview.dart';

import '../support/fake_playback_controls.dart';

void main() {
  testWidgets('karaoke sweep rebuilds on same-line playback ticks', (
    tester,
  ) async {
    final controls = FakePlaybackControls()..seekTestPosition(1100);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeEasy,
        lines: [
          SubtitleLine(index: 0, text: 'abcd', startMs: 1000, endMs: 2000),
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

    List<TextSpan> spans() =>
        ((tester
                        .widget<RichText>(
                          find.byKey(const ValueKey('karaoke-row-0')),
                        )
                        .text
                    as TextSpan)
                .children!)
            .cast<TextSpan>();
    expect(spans().single.text, 'abcd');
    expect(spans().single.style?.color, Colors.white);
    controls.seekTestPosition(1600);
    await tester.pump();
    expect(spans().first.text, 'ab');
    expect(spans().first.style?.color, const Color(0xFFFFD700));
    expect(spans().last.text, 'cd');
    expect(spans().last.style?.color, Colors.white);
  });

  testWidgets('karaoke sweep rebuilds after a direct paused seek', (
    tester,
  ) async {
    final controls = FakePlaybackControls()..seekTestPosition(1200);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeEasy,
        lines: [
          SubtitleLine(index: 0, text: 'abcd', startMs: 1000, endMs: 2000),
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
    expect(controls.isPlaying, isFalse);
    await controls.seek(1800);
    await tester.pump();
    final spans =
        ((tester
                        .widget<RichText>(
                          find.byKey(const ValueKey('karaoke-row-0')),
                        )
                        .text
                    as TextSpan)
                .children!)
            .cast<TextSpan>();
    expect(spans.first.text, 'abc');
    expect(spans.first.style?.color, const Color(0xFFFFD700));
    expect(spans.last.text, 'd');
  });

  testWidgets('adjacent karaoke boundary immediately selects next parity row', (
    tester,
  ) async {
    final controls = FakePlaybackControls()..seekTestPosition(2000);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeEasy,
        karaokePreDisplay: KaraokePreDisplay.oneLineAhead,
        lines: [
          SubtitleLine(index: 0, text: 'A', startMs: 1000, endMs: 2000),
          SubtitleLine(index: 1, text: 'B', startMs: 2000, endMs: 3000),
          SubtitleLine(index: 2, text: 'C', startMs: 3000, endMs: 4000),
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

    final row0 = tester.widget<RichText>(
      find.byKey(const ValueKey('karaoke-row-0')),
    );
    final row1 = tester.widget<RichText>(
      find.byKey(const ValueKey('karaoke-row-1')),
    );
    expect((row1.text as TextSpan).toPlainText(), 'B');
    expect((row0.text as TextSpan).toPlainText(), 'C');
    expect(
      (row1.text as TextSpan).children!.cast<TextSpan>().single.style?.color,
      Colors.white,
    );
  });

  testWidgets('timed karaoke review lead-in is white and uses project font', (
    tester,
  ) async {
    final controls = FakePlaybackControls()..seekTestPosition(0);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeEasy,
        karaokePreDisplay: KaraokePreDisplay.seconds3,
        subtitleFontFamily: 'noto_serif_cjk',
        subtitleFontSize: 36,
        lines: [
          SubtitleLine(index: 0, text: 'lead in', startMs: 2000, endMs: 4000),
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

    expect(find.byType(KaraokePreview), findsOneWidget);
    expect(find.byKey(const ValueKey('review-subtitle-panel')), findsNothing);
    final text = tester.widget<RichText>(
      find.byKey(const ValueKey('karaoke-row-0')),
    );
    final root = text.text as TextSpan;
    expect(root.style?.fontFamily, 'Noto Serif CJK SC');
    expect(root.style?.fontSize, 36);
    expect(
      root.children!.cast<TextSpan>().every(
        (span) => span.style?.color == Colors.white,
      ),
      isTrue,
    );
  });

  testWidgets('invalid Advanced timing does not attempt a resolved preview', (
    tester,
  ) async {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(
            index: 0,
            text: 'not marked',
            startMs: 1000,
            endMs: 2000,
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
              controls: FakePlaybackControls(),
              reviewMode: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(KaraokePreview), findsNothing);
    expect(find.text('Needs word timing'), findsOneWidget);
  });

  testWidgets(
    'Advanced completed line starts, marks, restarts and cancels a pass',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          karaokeMode: KaraokeMode.karaokeAdvanced,
          lines: [
            SubtitleLine(index: 0, text: 'one two', startMs: 5000, endMs: 9000),
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
      await tester.tap(find.text('Mark words'));
      await tester.pump();
      expect(controls.lastSeek, 3000);
      expect(find.text('Press Space: one'), findsOneWidget);
      controls.seekTestPosition(5100);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Press Space: two'), findsOneWidget);
      await tester.tap(find.text('Restart'));
      await tester.pump();
      expect(controls.lastSeek, 3000);
      expect(find.text('Press Space: one'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(session.advancedMarking, isNull);
    },
  );

  testWidgets('Mark words is only offered for valid completed Advanced lines', (
    tester,
  ) async {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.standard,
        lines: [SubtitleLine(index: 0, text: 'one', startMs: 100, endMs: 200)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(
              controls: FakePlaybackControls(),
              reviewMode: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Mark words'), findsNothing);
    session.setKaraokeSettings(
      mode: KaraokeMode.karaokeAdvanced,
      preDisplay: KaraokePreDisplay.off,
    );
    await tester.pump();
    expect(find.text('Mark words'), findsOneWidget);
    session.importLines(const [
      SubtitleLine(index: 0, text: 'one', startMs: 100),
    ]);
    await tester.pump();
    expect(find.text('Mark words'), findsNothing);
  });

  testWidgets('cancel invalidates a pass waiting for pause', (tester) async {
    final controls = DelayedPlaybackControls(delayPause: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 5000, endMs: 9000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    controls.completePause(0);
    await tester.pump();
    expect(controls.pendingSeekCount, 0);
    expect(controls.playCalls, 0);
  });

  testWidgets('project replacement invalidates a pass waiting for seek', (
    tester,
  ) async {
    final controls = DelayedPlaybackControls(delaySeek: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 5000, endMs: 9000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    session.loadProject(const Project(mediaPath: '/new.mp3', lines: []));
    controls.completeSeek(0);
    await tester.pump();
    expect(controls.playCalls, 0);
    expect(session.advancedMarking, isNull);
  });

  testWidgets('selecting another review line cancels an active Advanced pass', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 5000, endMs: 9000),
          SubtitleLine(index: 1, text: 'two', startMs: 10000, endMs: 12000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();
    expect(session.advancedMarking, isNull);
    expect(controls.lastSeek, 10000);
  });

  testWidgets(
    'selecting another line invalidates an Advanced pass pending pause',
    (tester) async {
      final controls = DelayedPlaybackControls(delayPause: true);
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          karaokeMode: KaraokeMode.karaokeAdvanced,
          lines: [
            SubtitleLine(index: 0, text: 'one', startMs: 5000, endMs: 9000),
            SubtitleLine(index: 1, text: 'two', startMs: 10000, endMs: 12000),
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
      await tester.tap(find.text('Mark words'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-next')));
      await tester.pump();
      controls.completePause(0);
      await tester.pump();
      expect(session.advancedMarking, isNull);
      expect(controls.pendingSeekCount, 0);
    },
  );

  testWidgets(
    'replacing the provided session cancels old async work and rebinds keys',
    (tester) async {
      final controls = DelayedPlaybackControls(delaySeek: true);
      final oldSession = MarkingSession(
        const Project(
          mediaPath: '/old.mp3',
          karaokeMode: KaraokeMode.karaokeAdvanced,
          lines: [
            SubtitleLine(index: 0, text: 'old', startMs: 5000, endMs: 9000),
          ],
        ),
      );
      final newSession = MarkingSession(
        const Project(
          mediaPath: '/new.mp3',
          lines: [SubtitleLine(index: 0, text: 'new')],
        ),
      );
      Widget app(MarkingSession session) => MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(controls: controls, reviewMode: true),
          ),
        ),
      );
      await tester.pumpWidget(app(oldSession));
      await tester.tap(find.text('Mark words'));
      await tester.pump();
      await tester.pumpWidget(app(newSession));
      controls.completeSeek(0);
      await tester.pump();
      expect(oldSession.advancedMarking, isNull);
      expect(controls.playCalls, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: newSession,
            child: Scaffold(body: MarkingScaffold(controls: controls)),
          ),
        ),
      );
      controls.seekTestPosition(1100);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      controls.seekTestPosition(2200);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(newSession.lines.single.startMs, 1100);
      expect(newSession.lines.single.endMs, 2200);
      expect(oldSession.lines.single.startMs, 5000);
    },
  );
  testWidgets('Advanced Backspace undoes and uses the pre-roll fallback', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one two', startMs: 1500, endMs: 9000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    controls.seekTestPosition(5100);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controls.lastSeek, 5100);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controls.lastSeek, 0);
  });

  testWidgets('the final Advanced unit pauses playback', (tester) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 1500, endMs: 9000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    expect(controls.playingValue, isTrue);
    controls.seekTestPosition(5100);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(session.advancedMarking?.isComplete, isTrue);
    expect(controls.playingValue, isFalse);
  });

  testWidgets('mode change makes a delayed play completion pause again', (
    tester,
  ) async {
    final controls = DelayedPlaybackControls(delayPlay: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        karaokeMode: KaraokeMode.karaokeAdvanced,
        lines: [
          SubtitleLine(index: 0, text: 'one', startMs: 1500, endMs: 9000),
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
    await tester.tap(find.text('Mark words'));
    await tester.pump();
    session.setKaraokeSettings(
      mode: KaraokeMode.standard,
      preDisplay: KaraokePreDisplay.off,
    );
    await tester.pump();
    controls.completePlay(0);
    await tester.pump();
    expect(session.advancedMarking, isNull);
    expect(controls.playingValue, isFalse);
  });

  testWidgets('cancelling review appearance leaves the session unchanged', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        subtitleFontFamily: 'noto_serif_cjk',
        subtitleFontSize: 36,
        lines: [SubtitleLine(index: 0, text: 'preview')],
      ),
    );
    var notifications = 0;
    session.addListener(() => notifications++);
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

    await tester.tap(find.byKey(const ValueKey('review-appearance')));
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const ValueKey('subtitle-appearance-size')))
        .onChanged!(48);
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(session.project.subtitleFontFamily, 'noto_serif_cjk');
    expect(session.project.subtitleFontSize, 36);
    expect(notifications, 0);
  });

  testWidgets('empty review uses the multilingual fallback preview', (
    tester,
  ) async {
    final session = MarkingSession(
      const Project(mediaPath: '/x.mp3', lines: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(
              controls: FakePlaybackControls(),
              reviewMode: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('review-appearance')));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle preview 字幕 미리보기'), findsOneWidget);
  });

  testWidgets(
    'review appearance saves once and styles text without changing a blank gap',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(
              index: 0,
              text: 'styled line',
              startMs: 100,
              endMs: 200,
            ),
            SubtitleLine(index: 1, text: 'later', startMs: 300, endMs: 400),
          ],
        ),
      );
      var notifications = 0;
      session.addListener(() => notifications++);

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

      await controls.play();
      controls.seekTestPosition(250);
      await tester.pump();
      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('styled line')),
        findsNothing,
      );
      expect(find.text('Line 1 of 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review-appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subtitle-appearance-font')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serif').last);
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('subtitle-appearance-size')),
          )
          .onChanged!(42);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('subtitle-appearance-save')));
      await tester.pumpAndSettle();

      expect(notifications, 1);
      expect(session.project.subtitleFontFamily, 'noto_serif_cjk');
      expect(session.project.subtitleFontSize, 42);
      final panelText = tester.widget<Text>(
        find.descendant(of: panel, matching: find.byType(Text)),
      );
      expect(panelText.data, '');
      expect(
        panelText.style?.fontFamily,
        SubtitleFontCatalog.byId('noto_serif_cjk').familyName,
      );
      expect(panelText.style?.fontSize, 42);
      expect(find.text('Line 1 of 2'), findsOneWidget);
      expect(controls.positionMs, 250);
      expect(controls.playingValue, isTrue);
    },
  );

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

  testWidgets(
    'exact review playback keeps the selected overlapping line through finish',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 500),
            SubtitleLine(index: 1, text: 'second', startMs: 200, endMs: 400),
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
      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      controls.seekTestPosition(250);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      final secondRowMaterial = find.ancestor(
        of: find.byKey(const ValueKey('line-row-1')),
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);
      expect(
        tester.widget<Material>(secondRowMaterial.first).color,
        Theme.of(
          tester.element(secondRowMaterial.first),
        ).colorScheme.primaryContainer,
      );

      controls.seekTestPosition(400);
      await tester.pump();
      expect(controls.playingValue, isFalse);
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review-flag')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-finish')));
      await tester.pump();

      expect(session.lines[0].isFullyMarked, isTrue);
      expect(session.lines[1].isFullyMarked, isFalse);
    },
  );

  testWidgets(
    'review auto-follow resumes after manual navigation cancels exact playback',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
            SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
            SubtitleLine(index: 2, text: 'third', startMs: 500, endMs: 600),
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
      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pumpAndSettle();
      expect(controls.playingValue, isTrue);

      final firstRow = find.byKey(const ValueKey('line-row-0'));
      await tester.ensureVisible(firstRow);
      await tester.tap(firstRow);
      await tester.pump();
      await controls.play();
      controls.seekTestPosition(550);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      final thirdRowMaterial = find.ancestor(
        of: find.byKey(const ValueKey('line-row-2')),
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: panel, matching: find.text('third')),
        findsOneWidget,
      );
      expect(find.text('Line 3 of 3'), findsOneWidget);
      expect(
        tester.widget<Material>(thirdRowMaterial.first).color,
        Theme.of(
          tester.element(thirdRowMaterial.first),
        ).colorScheme.primaryContainer,
      );
    },
  );

  testWidgets('review auto-follow resumes after lines replace exact playback', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'old', startMs: 100, endMs: 200)],
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

    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    expect(controls.playingValue, isTrue);
    session.importLines(const [
      SubtitleLine(index: 0, text: 'first', startMs: 300, endMs: 400),
      SubtitleLine(index: 1, text: 'second', startMs: 500, endMs: 600),
    ]);
    await tester.pump();

    await controls.play();
    controls.seekTestPosition(550);
    await tester.pump();

    final panel = find.byKey(const ValueKey('review-subtitle-panel'));
    expect(
      find.descendant(of: panel, matching: find.text('second')),
      findsOneWidget,
    );
    expect(find.text('Line 2 of 2'), findsOneWidget);
  });

  testWidgets(
    'review auto-follow resumes after review exit resets exact playback',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
            SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
          ],
        ),
      );
      Widget app({required bool reviewMode}) => MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(controls: controls, reviewMode: reviewMode),
          ),
        ),
      );

      await tester.pumpWidget(app(reviewMode: true));
      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      expect(controls.playingValue, isTrue);
      await tester.pumpWidget(app(reviewMode: false));
      await tester.pump();
      await tester.pumpWidget(app(reviewMode: true));
      await tester.pump();

      await controls.play();
      controls.seekTestPosition(350);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'stale delayed exact play never auto-follows after lines are replaced',
    (tester) async {
      final controls = DelayedPlaybackControls(delayPlay: true);
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'old first', startMs: 100, endMs: 200),
            SubtitleLine(
              index: 1,
              text: 'old second',
              startMs: 300,
              endMs: 400,
            ),
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

      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      session.importLines(const [
        SubtitleLine(index: 0, text: 'new first', startMs: 100, endMs: 200),
        SubtitleLine(index: 1, text: 'new second', startMs: 300, endMs: 400),
      ]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-next')));
      await tester.pumpAndSettle();
      controls.seekTestPosition(150);
      await tester.pump();

      controls.completePlay(0);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      final secondRowMaterial = find.ancestor(
        of: find.byKey(const ValueKey('line-row-1')),
        matching: find.byType(Material),
      );
      expect(controls.playingValue, isFalse);
      expect(
        find.descendant(of: panel, matching: find.text('new second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);
      expect(
        tester.widget<Material>(secondRowMaterial.first).color,
        Theme.of(
          tester.element(secondRowMaterial.first),
        ).colorScheme.primaryContainer,
      );

      await tester.tap(find.byKey(const ValueKey('review-flag')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-finish')));
      await tester.pump();
      expect(session.lines[0].isFullyMarked, isTrue);
      expect(session.lines[1].isFullyMarked, isFalse);
    },
  );

  testWidgets(
    'review auto-follow resumes after paused exact play and line replacement',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'old', startMs: 100, endMs: 200),
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

      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      await controls.pause();
      session.importLines(const [
        SubtitleLine(index: 0, text: 'first', startMs: 300, endMs: 400),
        SubtitleLine(index: 1, text: 'second', startMs: 500, endMs: 600),
      ]);
      await tester.pump();

      await controls.play();
      controls.seekTestPosition(550);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'review auto-follow resumes after paused exact play and review re-entry',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
            SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
          ],
        ),
      );
      Widget app({required bool reviewMode}) => MaterialApp(
        home: ChangeNotifierProvider.value(
          value: session,
          child: Scaffold(
            body: MarkingScaffold(controls: controls, reviewMode: reviewMode),
          ),
        ),
      );

      await tester.pumpWidget(app(reviewMode: true));
      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      await controls.pause();
      await tester.pumpWidget(app(reviewMode: false));
      await tester.pump();
      await tester.pumpWidget(app(reviewMode: true));
      await tester.pump();

      await controls.play();
      controls.seekTestPosition(350);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(find.text('Line 2 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'review auto-follow shows and highlights the active line and blanks gaps',
    (tester) async {
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

      await controls.play();
      controls.seekTestPosition(1250);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      final secondRow = find.byKey(const ValueKey('line-row-1'));
      final secondRowMaterial = find.ancestor(
        of: secondRow,
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
      expect(
        tester.widget<Material>(secondRowMaterial.first).color,
        Theme.of(
          tester.element(secondRowMaterial.first),
        ).colorScheme.primaryContainer,
      );

      controls.seekTestPosition(1000);
      await tester.pump();
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('first')),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsNothing,
      );
      final firstRowMaterial = find.ancestor(
        of: find.byKey(const ValueKey('line-row-0')),
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(firstRowMaterial.first).color,
        isNot(
          Theme.of(
            tester.element(firstRowMaterial.first),
          ).colorScheme.primaryContainer,
        ),
      );
      expect(
        tester.widget<Material>(secondRowMaterial.first).color,
        isNot(
          Theme.of(
            tester.element(secondRowMaterial.first),
          ).colorScheme.primaryContainer,
        ),
      );

      await controls.pause();
      await tester.pump();
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
    },
  );

  testWidgets('review auto-follow updates immediately after a direct seek', (
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

    await controls.play();
    controls.seekTestPosition(600);
    await tester.pump();
    final panel = find.byKey(const ValueKey('review-subtitle-panel'));
    expect(
      find.descendant(of: panel, matching: find.text('first')),
      findsOneWidget,
    );

    controls.seekTestPosition(1250);
    await tester.pump();
    expect(
      find.descendant(of: panel, matching: find.text('second')),
      findsOneWidget,
    );
  });

  testWidgets(
    'review auto-follow preserves manual row selection while paused',
    (tester) async {
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

      await tester.tap(find.byKey(const ValueKey('line-row-1')));
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('second')),
        findsOneWidget,
      );
    },
  );

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

  testWidgets('review panel updates with navigation and row selection', (
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

    final panel = find.byKey(const ValueKey('review-subtitle-panel'));
    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();
    expect(
      find.descendant(of: panel, matching: find.text('second')),
      findsOneWidget,
    );
    final firstRow = find.byKey(const ValueKey('line-row-0'));
    await tester.ensureVisible(firstRow);
    await tester.pumpAndSettle();
    await tester.tap(firstRow);
    await tester.pump();
    expect(
      find.descendant(of: panel, matching: find.text('first')),
      findsOneWidget,
    );
  });

  testWidgets('empty review hides the panel and disables playback', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(mediaPath: '/x.mp3', lines: []),
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

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('review-subtitle-panel')), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('review-play')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'review controls clamp selection when the line list becomes shorter',
    (tester) async {
      final controls = FakePlaybackControls();
      final session = MarkingSession(
        const Project(
          mediaPath: '/x.mp3',
          lines: [
            SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
            SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
            SubtitleLine(index: 2, text: 'third', startMs: 500, endMs: 600),
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
      await tester.tap(find.byKey(const ValueKey('review-next')));
      await tester.pump();

      session.importLines(const [
        SubtitleLine(index: 0, text: 'remaining', startMs: 700, endMs: 800),
      ]);
      await tester.pump();

      final panel = find.byKey(const ValueKey('review-subtitle-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('remaining')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('review-play')));
      await tester.pump();
      expect(controls.lastSeek, 700);

      await tester.tap(find.byKey(const ValueKey('review-flag')));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('review-flag')))
            .selected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('review-finish')));
      await tester.pump();
      expect(session.lines.single.isFullyMarked, isFalse);
    },
  );

  testWidgets('rapid review selection cannot resume stale playback', (
    tester,
  ) async {
    final controls = DelayedPlaybackControls(delayPause: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
          SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
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

    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();

    controls.completePause(1);
    await tester.pump();
    expect(controls.lastSeek, 300);

    controls.completePause(0);
    await tester.pump();
    expect(controls.lastSeek, 300);
    expect(controls.playCalls, 0);
  });

  testWidgets('leaving review during a pending seek cannot start playback', (
    tester,
  ) async {
    final controls = DelayedPlaybackControls(delaySeek: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
        ],
      ),
    );

    Widget app({required bool reviewMode}) => MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(
          body: MarkingScaffold(controls: controls, reviewMode: reviewMode),
        ),
      ),
    );

    await tester.pumpWidget(app(reviewMode: true));
    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    expect(controls.pendingSeekCount, 1);

    await tester.pumpWidget(app(reviewMode: false));
    controls.completeSeek(0);
    await tester.pump();

    expect(controls.playCalls, 0);
    expect(controls.playingValue, isFalse);
  });

  testWidgets('stale play completion cannot pause newer review playback', (
    tester,
  ) async {
    final controls = DelayedPlaybackControls(delayPlay: true);
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
          SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
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

    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();

    controls.completePlay(1);
    await tester.pump();
    expect(controls.playingValue, isTrue);

    controls.completePlay(0);
    await tester.pump();
    expect(controls.playingValue, isTrue);
  });

  testWidgets('leaving review pauses an active review interval', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
        ],
      ),
    );

    Widget app({required bool reviewMode}) => MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(
          body: MarkingScaffold(controls: controls, reviewMode: reviewMode),
        ),
      ),
    );

    await tester.pumpWidget(app(reviewMode: true));
    await tester.tap(find.byKey(const ValueKey('review-play')));
    await tester.pump();
    expect(controls.playingValue, isTrue);

    await tester.pumpWidget(app(reviewMode: false));
    await tester.pump();
    expect(controls.playingValue, isFalse);
  });

  testWidgets('replacing lines discards review flags before finish', (
    tester,
  ) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [SubtitleLine(index: 0, text: 'old', startMs: 100, endMs: 200)],
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

    await tester.tap(find.byKey(const ValueKey('review-flag')));
    await tester.pump();
    session.importLines(const [
      SubtitleLine(index: 0, text: 'replacement', startMs: 500, endMs: 600),
    ]);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-finish')));
    await tester.pump();

    expect(session.lines.single.text, 'replacement');
    expect(session.lines.single.startMs, 500);
    expect(session.lines.single.endMs, 600);
  });
}

class DelayedPlaybackControls extends FakePlaybackControls {
  DelayedPlaybackControls({
    this.delayPause = false,
    this.delaySeek = false,
    this.delayPlay = false,
  });

  final bool delayPause;
  final bool delaySeek;
  final bool delayPlay;
  final List<Completer<void>> _pauses = [];
  final List<Completer<void>> _seeks = [];
  final List<int> _seekTargets = [];
  final List<Completer<void>> _plays = [];
  int playCalls = 0;

  int get pendingSeekCount => _seeks.length;

  @override
  Future<void> pause() {
    if (!delayPause) return super.pause();
    playingValue = false;
    notifyListeners();
    final completer = Completer<void>();
    _pauses.add(completer);
    return completer.future;
  }

  void completePause(int index) => _pauses[index].complete();

  @override
  Future<void> seek(int ms) {
    if (!delaySeek) return super.seek(ms);
    final completer = Completer<void>();
    _seeks.add(completer);
    _seekTargets.add(ms);
    return completer.future.then(
      (_) => super.seek(_seekTargets[indexOf(completer)]),
    );
  }

  int indexOf(Completer<void> completer) => _seeks.indexOf(completer);

  void completeSeek(int index) => _seeks[index].complete();

  @override
  Future<void> play() {
    playCalls++;
    if (delayPlay) {
      final completer = Completer<void>();
      _plays.add(completer);
      return completer.future.then((_) => super.play());
    }
    return super.play();
  }

  void completePlay(int index) => _plays[index].complete();
}

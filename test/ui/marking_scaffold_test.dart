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
  testWidgets('space down/up marks the current line using the live fake position', (tester) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line'),
      SubtitleLine(index: 1, text: 'second line'),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls)),
      ),
    ));
    await tester.pump();

    controls.seekTestPosition(1200);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    controls.seekTestPosition(3400);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'first line', startMs: 1200, endMs: 3400));
    expect(session.currentIndex, 1);
  });

  testWidgets('backspace redoes the current line and seeks back', (tester) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line', startMs: 500, endMs: 900),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls)),
      ),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'first line'));
    expect(controls.lastSeek, 500);
  });
}

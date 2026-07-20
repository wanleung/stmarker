// test/ui/widgets/line_list_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/ui/widgets/line_list_view.dart';

Widget _wrap(MarkingSession session, void Function(int) onRowTap) {
  return MaterialApp(
    home: ChangeNotifierProvider.value(
      value: session,
      child: Scaffold(body: LineListView(onRowTap: onRowTap)),
    ),
  );
}

void main() {
  testWidgets('renders every line with its text and formatted timestamps', (tester) async {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line', startMs: 1000, endMs: 2500),
      SubtitleLine(index: 1, text: 'second line'),
    ]));

    await tester.pumpWidget(_wrap(session, (_) {}));

    expect(find.text('first line'), findsOneWidget);
    expect(find.text('00:01.000 → 00:02.500'), findsOneWidget);
    expect(find.text('second line'), findsOneWidget);
    expect(find.text('— → —'), findsOneWidget);
  });

  testWidgets("tapping a row calls onRowTap with that row's index", (tester) async {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line'),
      SubtitleLine(index: 1, text: 'second line'),
    ]));
    int? tapped;

    await tester.pumpWidget(_wrap(session, (index) => tapped = index));
    await tester.tap(find.byKey(const ValueKey('line-row-1')));

    expect(tapped, 1);
  });

  testWidgets('auto-scroll does not trigger on unrelated session mutations', (tester) async {
    // Create 25 lines with the first 5 fully marked so currentIndex starts at 5.
    // Each row is 48px tall, so currentIndex=5 means offset=240px.
    final lines = <SubtitleLine>[
      for (int i = 0; i < 5; i++)
        SubtitleLine(index: i, text: 'marked line $i', startMs: i * 1000, endMs: i * 1000 + 500),
      for (int i = 5; i < 25; i++)
        SubtitleLine(index: i, text: 'unmarked line $i'),
    ];
    final session = MarkingSession(Project(mediaPath: '/x.mp3', lines: lines));

    await tester.pumpWidget(_wrap(session, (_) {}));

    // Pump to let the initial auto-scroll animation complete (~200ms).
    await tester.pumpAndSettle();

    // Get the scroll offset after initial scroll to currentIndex=5.
    final scrollOffsetAfterInit = tester.widget<ListView>(find.byType(ListView)).controller!.offset;
    expect(scrollOffsetAfterInit, greaterThan(0), reason: 'Should have scrolled to index 5');

    // Call an unrelated mutation (setPlaybackRate) that does NOT change currentIndex.
    session.setPlaybackRate(0.75);
    await tester.pumpAndSettle();

    // Verify the scroll offset is unchanged (the regression: offset should not change).
    final scrollOffsetAfterMutation = tester.widget<ListView>(find.byType(ListView)).controller!.offset;
    expect(scrollOffsetAfterMutation, scrollOffsetAfterInit,
      reason: 'Offset should not change on unrelated mutations');

    // Sanity check: drive a real currentIndex change by marking the current line.
    // currentIndex is now 5, mark its start and end to advance to index 6.
    session.markStart(5000);
    session.markEnd(5500);
    await tester.pumpAndSettle();

    // Verify currentIndex has advanced and offset has changed.
    expect(session.currentIndex, isNotNull, reason: 'Should still have an unmarked line');
    expect(session.currentIndex, greaterThan(5), reason: 'Should have advanced past the marked line');
    final scrollOffsetAfterMarking = tester.widget<ListView>(find.byType(ListView)).controller!.offset;
    expect(scrollOffsetAfterMarking, greaterThan(scrollOffsetAfterInit),
      reason: 'Offset should increase when currentIndex advances');
  });
}

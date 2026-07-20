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
  testWidgets('renders every line with its text and formatted timestamps', (
    tester,
  ) async {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(
            index: 0,
            text: 'first line',
            startMs: 1000,
            endMs: 2500,
          ),
          SubtitleLine(index: 1, text: 'second line'),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(session, (_) {}));

    expect(find.text('first line'), findsOneWidget);
    expect(find.text('00:01.000 → 00:02.500'), findsOneWidget);
    expect(find.text('second line'), findsOneWidget);
    expect(find.text('— → —'), findsOneWidget);
  });

  testWidgets("tapping a row calls onRowTap with that row's index", (
    tester,
  ) async {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first line'),
          SubtitleLine(index: 1, text: 'second line'),
        ],
      ),
    );
    int? tapped;

    await tester.pumpWidget(_wrap(session, (index) => tapped = index));
    await tester.tap(find.byKey(const ValueKey('line-row-1')));

    expect(tapped, 1);
  });

  testWidgets(
    'auto-scroll guard prevents snap-back after an unrelated mutation, but real currentIndex changes still scroll',
    (tester) async {
      final lines = [
        for (var i = 0; i < 5; i++)
          SubtitleLine(
            index: i,
            text: 'line $i',
            startMs: i * 1000,
            endMs: i * 1000 + 500,
          ),
        for (var i = 5; i < 25; i++) SubtitleLine(index: i, text: 'line $i'),
      ];
      final session = MarkingSession(
        Project(mediaPath: '/x.mp3', lines: lines),
      );
      expect(session.currentIndex, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: session,
            child: Scaffold(body: LineListView(onRowTap: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      final initialOffset = controller.offset;
      expect(initialOffset, greaterThan(0));

      // Simulate the user manually scrolling away from the current line.
      controller.jumpTo(0);
      await tester.pump();
      expect(controller.offset, 0);

      // An unrelated mutation must NOT snap the list back to currentIndex.
      session.setPlaybackRate(0.75);
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        0,
        reason: 'unrelated mutation should not re-trigger auto-scroll',
      );

      // A real currentIndex change must still scroll.
      session.markStart(5000);
      session.markEnd(5500);
      await tester.pumpAndSettle();
      expect(session.currentIndex, 6);
      expect(controller.offset, greaterThan(0));
    },
  );

  testWidgets('flags invalid and overlapping timestamp rows', (tester) async {
    final session = MarkingSession(
      const Project(
        mediaPath: '/x.mp3',
        lines: [
          SubtitleLine(index: 0, text: 'first', startMs: 1000, endMs: 2500),
          SubtitleLine(index: 1, text: 'overlap', startMs: 2000, endMs: 3000),
          SubtitleLine(index: 2, text: 'invalid', startMs: 5000, endMs: 4000),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(session, (_) {}));

    expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
    expect(
      find.byTooltip('Starts before the previous line ends'),
      findsOneWidget,
    );
    expect(find.byTooltip('Invalid timestamp range'), findsOneWidget);
  });
}

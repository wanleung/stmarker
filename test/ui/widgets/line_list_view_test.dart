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
}

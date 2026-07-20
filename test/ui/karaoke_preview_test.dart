import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_timing.dart';
import 'package:stmarker/ui/karaoke_preview.dart';

const _segments = [
  KaraokeSegment(text: 'Hi ', startMs: 1000, endMs: 2000),
  KaraokeSegment(text: '你好', startMs: 2500, endMs: 3500),
];

Widget _app({
  required int positionMs,
  List<KaraokeSegment> current = _segments,
  List<KaraokeSegment>? next,
  int currentLineIndex = 0,
}) => MaterialApp(
  home: Scaffold(
    body: KaraokePreview(
      current: current,
      next: next,
      currentLineIndex: currentLineIndex,
      positionMs: positionMs,
      fontFamily: 'Noto Serif CJK SC',
      fontSize: 31,
    ),
  ),
);

List<InlineSpan> _spans(WidgetTester tester, String key) {
  final span = tester.widget<RichText>(find.byKey(ValueKey(key))).text;
  return (span as TextSpan).children!;
}

String _text(InlineSpan span) => (span as TextSpan).text!;
Color? _color(InlineSpan span) => (span as TextSpan).style?.color;

void main() {
  testWidgets('renders future text white before singing and during a gap', (
    tester,
  ) async {
    await tester.pumpWidget(_app(positionMs: 500));
    var spans = _spans(tester, 'karaoke-row-0');
    expect(spans.map(_text).join(), 'Hi 你好');
    expect(spans.every((span) => _color(span) == Colors.white), isTrue);

    await tester.pumpWidget(_app(positionMs: 2250));
    spans = _spans(tester, 'karaoke-row-0');
    expect(_text(spans.first), 'Hi ');
    expect(_color(spans.first), const Color(0xFFFFD700));
    expect(_text(spans.last), '你好');
    expect(_color(spans.last), Colors.white);
  });

  testWidgets('sweeps an active token by grapheme and honors boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(_app(positionMs: 1500));
    var spans = _spans(tester, 'karaoke-row-0');
    expect(spans.map(_text), ['H', 'i ', '你好']);
    expect(_color(spans[0]), const Color(0xFFFFD700));
    expect(_color(spans[1]), Colors.white);

    await tester.pumpWidget(_app(positionMs: 2000));
    spans = _spans(tester, 'karaoke-row-0');
    expect(_text(spans.first), 'Hi ');
    expect(_color(spans.first), const Color(0xFFFFD700));

    await tester.pumpWidget(_app(positionMs: 3500));
    spans = _spans(tester, 'karaoke-row-0');
    expect(spans.map(_text).join(), 'Hi 你好');
    expect(
      spans.every((span) => _color(span) == const Color(0xFFFFD700)),
      isTrue,
    );
  });

  testWidgets('keeps current parity stable and next line white', (
    tester,
  ) async {
    const next = [
      KaraokeSegment(text: '  next line', startMs: 4000, endMs: 5000),
    ];
    await tester.pumpWidget(
      _app(positionMs: 3000, currentLineIndex: 3, next: next),
    );

    expect(find.byKey(const ValueKey('karaoke-row-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('karaoke-row-1')), findsOneWidget);
    final current = _spans(tester, 'karaoke-row-1');
    final upcoming = _spans(tester, 'karaoke-row-0');
    expect(current.map(_text).join(), 'Hi 你好');
    expect(upcoming.map(_text).join(), '  next line');
    expect(upcoming.every((span) => _color(span) == Colors.white), isTrue);
    expect(
      find.bySemanticsLabel(RegExp('Current karaoke line')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Next karaoke line')), findsOneWidget);
  });

  test('timed lead-in start clamps at zero', () {
    expect(karaokeDisplayStartMs(firstSegmentStartMs: 2000, leadMs: 3000), 0);
    expect(
      karaokeDisplayStartMs(firstSegmentStartMs: 5000, leadMs: 3000),
      2000,
    );
  });
}

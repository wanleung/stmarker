import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/karaoke/karaoke_timing.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  group('tokenizeKaraokeText', () {
    test('preserves western words, spacing, and punctuation', () {
      final tokens = tokenizeKaraokeText('Hello,  world!');

      expect(tokens.map((token) => token.text), ['Hello,', '  world!']);
      expect(tokens.map((token) => token.identity), ['Hello', 'world']);
    });

    test('uses individual CJK grapheme clusters as units', () {
      expect(tokenizeKaraokeText('你好世界').map((token) => token.text), [
        '你',
        '好',
        '世',
        '界',
      ]);
    });

    test('attaches leading punctuation forward and trailing backward', () {
      final tokens = tokenizeKaraokeText('「你好！」');

      expect(tokens.map((token) => token.text), ['「你', '好！」']);
      expect(tokens.map((token) => token.identity), ['你', '好']);
    });

    test('keeps punctuation-only and empty sources as one unit', () {
      expect(tokenizeKaraokeText('!!!').map((token) => token.text), ['!!!']);
      expect(tokenizeKaraokeText('').map((token) => token.text), ['']);
    });

    test('does not split extended Unicode grapheme clusters', () {
      const source = 'A e\u0301 👩‍👩‍👧‍👦 好';
      final tokens = tokenizeKaraokeText(source);

      expect(tokens.map((token) => token.text).join(), source);
      expect(tokens.map((token) => token.identity), [
        'A',
        'e\u0301',
        '👩‍👩‍👧‍👦',
        '好',
      ]);
    });
  });

  group('resolveKaraokeSegments', () {
    test('Easy uses deterministic integer boundaries and exact line end', () {
      const line = SubtitleLine(
        index: 0,
        text: 'one two three',
        startMs: 1000,
        endMs: 2000,
      );

      final segments = resolveKaraokeSegments(line, KaraokeMode.karaokeEasy);

      expect(segments.map((segment) => (segment.startMs, segment.endMs)), [
        (1000, 1333),
        (1333, 1666),
        (1666, 2000),
      ]);
      expect(segments.map((segment) => segment.text).join(), line.text);
    });

    test('Advanced resolves a valid exact mark sequence', () {
      final line = markedLine(
        marks: const [
          KaraokeMark(unitText: 'one', startMs: 1000),
          KaraokeMark(unitText: 'two', startMs: 1300),
          KaraokeMark(unitText: 'three', startMs: 1700),
        ],
      );

      expect(karaokeTimingIssue(line, KaraokeMode.karaokeAdvanced), isNull);
      expect(
        resolveKaraokeSegments(
          line,
          KaraokeMode.karaokeAdvanced,
        ).map((segment) => (segment.text, segment.startMs, segment.endMs)),
        [('one', 1000, 1300), (' two', 1300, 1700), (' three', 1700, 2000)],
      );
    });

    test('reports invalid or incomplete line ranges', () {
      const missingEnd = SubtitleLine(index: 0, text: 'one', startMs: 1000);
      const reversed = SubtitleLine(
        index: 0,
        text: 'one',
        startMs: 1000,
        endMs: 1000,
      );

      expect(
        karaokeTimingIssue(missingEnd, KaraokeMode.karaokeEasy),
        KaraokeTimingIssue.invalidLineRange,
      );
      expect(
        karaokeTimingIssue(reversed, KaraokeMode.karaokeAdvanced),
        KaraokeTimingIssue.invalidLineRange,
      );
      expect(
        resolveKaraokeSegments(missingEnd, KaraokeMode.karaokeEasy),
        isEmpty,
      );
    });

    test('reports missing marks, including incomplete mark counts', () {
      expect(
        karaokeTimingIssue(markedLine(), KaraokeMode.karaokeAdvanced),
        KaraokeTimingIssue.missingMarks,
      );
      expect(
        karaokeTimingIssue(
          markedLine(
            marks: const [KaraokeMark(unitText: 'one', startMs: 1000)],
          ),
          KaraokeMode.karaokeAdvanced,
        ),
        KaraokeTimingIssue.missingMarks,
      );
    });

    test('reports stale marks when token identities changed', () {
      final line = markedLine(
        marks: const [
          KaraokeMark(unitText: 'one', startMs: 1000),
          KaraokeMark(unitText: 'stale', startMs: 1300),
          KaraokeMark(unitText: 'three', startMs: 1700),
        ],
      );

      expect(
        karaokeTimingIssue(line, KaraokeMode.karaokeAdvanced),
        KaraokeTimingIssue.staleMarks,
      );
      expect(
        resolveKaraokeSegments(line, KaraokeMode.karaokeAdvanced),
        isEmpty,
      );
    });

    test('reports duplicate and decreasing marks as non-increasing', () {
      for (final starts in [
        [1000, 1000, 1700],
        [1000, 1700, 1600],
      ]) {
        final line = markedLine(
          marks: [
            KaraokeMark(unitText: 'one', startMs: starts[0]),
            KaraokeMark(unitText: 'two', startMs: starts[1]),
            KaraokeMark(unitText: 'three', startMs: starts[2]),
          ],
        );

        expect(
          karaokeTimingIssue(line, KaraokeMode.karaokeAdvanced),
          KaraokeTimingIssue.nonIncreasingMarks,
        );
      }
    });

    test('reports marks outside the line', () {
      final line = markedLine(
        marks: const [
          KaraokeMark(unitText: 'one', startMs: 999),
          KaraokeMark(unitText: 'two', startMs: 1300),
          KaraokeMark(unitText: 'three', startMs: 1700),
        ],
      );

      expect(
        karaokeTimingIssue(line, KaraokeMode.karaokeAdvanced),
        KaraokeTimingIssue.markOutsideLine,
      );
    });

    test('reports a final zero-duration unit', () {
      final line = markedLine(
        marks: const [
          KaraokeMark(unitText: 'one', startMs: 1000),
          KaraokeMark(unitText: 'two', startMs: 1300),
          KaraokeMark(unitText: 'three', startMs: 2000),
        ],
      );

      expect(
        karaokeTimingIssue(line, KaraokeMode.karaokeAdvanced),
        KaraokeTimingIssue.nonPositiveUnitDuration,
      );
    });

    test('Standard mode has no karaoke timing or segments', () {
      expect(karaokeTimingIssue(markedLine(), KaraokeMode.standard), isNull);
      expect(
        resolveKaraokeSegments(markedLine(), KaraokeMode.standard),
        isEmpty,
      );
    });
  });
}

SubtitleLine markedLine({List<KaraokeMark> marks = const []}) {
  return SubtitleLine.withKaraokeMarks(
    index: 0,
    text: 'one two three',
    startMs: 1000,
    endMs: 2000,
    karaokeMarks: marks,
  );
}

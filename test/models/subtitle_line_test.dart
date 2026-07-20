import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  const marks = [KaraokeMark(unitText: 'hello', startMs: 100)];

  test('ordinary copyWith preserves marks when timestamps do not change', () {
    final line = SubtitleLine.withKaraokeMarks(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
      karaokeMarks: marks,
    );

    expect(line.copyWith().karaokeMarks, marks);
    expect(line.copyWith(startMs: 100).karaokeMarks, marks);
  });

  test('timestamp changes and clearing invalidate karaoke marks', () {
    final line = SubtitleLine.withKaraokeMarks(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
      karaokeMarks: marks,
    );

    expect(line.copyWith(startMs: 101).karaokeMarks, isEmpty);
    expect(
      line.withExactTimestamps(startMs: 100, endMs: 201).karaokeMarks,
      isEmpty,
    );
    expect(line.clearTimestamps().karaokeMarks, isEmpty);
  });

  test(
    'changing text invalidates marks while unchanged text preserves them',
    () {
      final line = SubtitleLine.withKaraokeMarks(
        index: 0,
        text: 'hello',
        startMs: 100,
        endMs: 200,
        karaokeMarks: marks,
      );

      expect(line.withText('hello').karaokeMarks, marks);
      expect(line.withText('goodbye').karaokeMarks, isEmpty);
      expect(line.withText('goodbye').text, 'goodbye');
    },
  );

  test('constructor snapshots marks and exposes an unmodifiable list', () {
    final source = <KaraokeMark>[
      const KaraokeMark(unitText: 'hello', startMs: 100),
    ];
    final line = SubtitleLine.withKaraokeMarks(
      index: 0,
      text: 'hello',
      karaokeMarks: source,
    );
    final initialHash = line.hashCode;

    source.add(const KaraokeMark(unitText: 'world', startMs: 150));

    expect(line.karaokeMarks, marks);
    expect(line.hashCode, initialHash);
    expect(
      () => line.karaokeMarks.add(
        const KaraokeMark(unitText: 'world', startMs: 150),
      ),
      throwsUnsupportedError,
    );
  });

  test('Advanced karaoke snapshots its marks input', () {
    final source = <KaraokeMark>[
      const KaraokeMark(unitText: 'hello', startMs: 100),
    ];
    final updated = SubtitleLine(
      index: 0,
      text: 'hello',
      endMs: 200,
    ).withAdvancedKaraoke(startMs: 100, marks: source);

    source.clear();

    expect(updated.karaokeMarks, marks);
    expect(() => updated.karaokeMarks.clear(), throwsUnsupportedError);
  });

  test('JSON parsing produces an unmodifiable marks snapshot', () {
    final rawMark = <String, dynamic>{'unitText': 'hello', 'startMs': 100};
    final rawMarks = <Object?>[rawMark];
    final line = SubtitleLine.fromJson({
      'index': 0,
      'text': 'hello',
      'karaokeMarks': rawMarks,
    });

    rawMarks.clear();
    rawMark['startMs'] = 999;

    expect(line.karaokeMarks, marks);
    expect(() => line.karaokeMarks.clear(), throwsUnsupportedError);
  });

  test('Advanced karaoke updates singing start and marks atomically', () {
    final line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );

    final updated = line.withAdvancedKaraoke(startMs: 120, marks: marks);

    expect(updated.startMs, 120);
    expect(updated.endMs, 200);
    expect(updated.karaokeMarks, marks);
  });

  test('equality includes karaoke marks', () {
    expect(
      SubtitleLine.withKaraokeMarks(
        index: 0,
        text: 'hello',
        karaokeMarks: marks,
      ),
      isNot(SubtitleLine(index: 0, text: 'hello')),
    );
  });

  test('malformed karaoke marks are ignored', () {
    final line = SubtitleLine.fromJson({
      'index': 0,
      'text': 'hello',
      'startMs': 100,
      'endMs': 200,
      'karaokeMarks': <Object?>[
        {'unitText': 'hello', 'startMs': 100},
        {'unitText': 4, 'startMs': 110},
        {'unitText': 'world'},
        'bad',
      ],
    });

    expect(line.karaokeMarks, marks);
  });

  test('malformed marks do not weaken required-field validation', () {
    expect(
      () => SubtitleLine.fromJson({'text': 'hello', 'karaokeMarks': 'bad'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('legacy JSON keeps text and timestamp field types strict', () {
    Map<String, dynamic> jsonWith(Map<String, dynamic> fields) => {
      'index': 0,
      'text': 'hello',
      ...fields,
    };

    expect(
      () => SubtitleLine.fromJson({'index': 0}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => SubtitleLine.fromJson({'index': 0, 'text': 4}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => SubtitleLine.fromJson(jsonWith({'startMs': '100'})),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => SubtitleLine.fromJson(jsonWith({'endMs': 2.5})),
      throwsA(isA<TypeError>()),
    );
    expect(
      SubtitleLine.fromJson(
        jsonWith({'startMs': null, 'endMs': null}),
      ).isFullyMarked,
      isFalse,
    );
  });

  test('isFullyMarked is false when either timestamp is missing', () {
    final line = SubtitleLine(index: 0, text: 'hello');
    expect(line.isFullyMarked, isFalse);
  });

  test('isFullyMarked is true when both timestamps are set', () {
    final line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    expect(line.isFullyMarked, isTrue);
  });

  test('copyWith only overrides provided fields', () {
    final line = SubtitleLine(index: 0, text: 'hello', startMs: 100);
    final updated = line.copyWith(endMs: 200);
    expect(
      updated,
      SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200),
    );
  });

  test('withExactTimestamps replaces both fields even with null', () {
    final line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    final updated = line.withExactTimestamps(startMs: 50);
    expect(updated, SubtitleLine(index: 0, text: 'hello', startMs: 50));
  });

  test('clearTimestamps resets both to null', () {
    final line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    expect(line.clearTimestamps(), SubtitleLine(index: 0, text: 'hello'));
  });

  test('toJson/fromJson round-trip with timestamps set', () {
    final line = SubtitleLine(
      index: 3,
      text: 'hi there',
      startMs: 1000,
      endMs: 2500,
    );
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('toJson/fromJson round-trip with null timestamps', () {
    final line = SubtitleLine(index: 3, text: 'hi there');
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('hasInvalidRange rejects negative and non-positive ranges', () {
    expect(
      SubtitleLine(index: 0, text: 'negative', startMs: -1).hasInvalidRange,
      isTrue,
    );
    expect(
      SubtitleLine(
        index: 0,
        text: 'backwards',
        startMs: 200,
        endMs: 100,
      ).hasInvalidRange,
      isTrue,
    );
    expect(
      SubtitleLine(
        index: 0,
        text: 'valid',
        startMs: 100,
        endMs: 200,
      ).hasInvalidRange,
      isFalse,
    );
  });
}

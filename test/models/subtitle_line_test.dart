import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  const marks = [KaraokeMark(unitText: 'hello', startMs: 100)];

  test('ordinary copyWith preserves marks when timestamps do not change', () {
    const line = SubtitleLine(
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
    const line = SubtitleLine(
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

  test('Advanced karaoke updates singing start and marks atomically', () {
    const line = SubtitleLine(
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
      const SubtitleLine(index: 0, text: 'hello', karaokeMarks: marks),
      isNot(const SubtitleLine(index: 0, text: 'hello')),
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

  test('isFullyMarked is false when either timestamp is missing', () {
    const line = SubtitleLine(index: 0, text: 'hello');
    expect(line.isFullyMarked, isFalse);
  });

  test('isFullyMarked is true when both timestamps are set', () {
    const line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    expect(line.isFullyMarked, isTrue);
  });

  test('copyWith only overrides provided fields', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100);
    final updated = line.copyWith(endMs: 200);
    expect(
      updated,
      const SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200),
    );
  });

  test('withExactTimestamps replaces both fields even with null', () {
    const line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    final updated = line.withExactTimestamps(startMs: 50);
    expect(updated, const SubtitleLine(index: 0, text: 'hello', startMs: 50));
  });

  test('clearTimestamps resets both to null', () {
    const line = SubtitleLine(
      index: 0,
      text: 'hello',
      startMs: 100,
      endMs: 200,
    );
    expect(line.clearTimestamps(), const SubtitleLine(index: 0, text: 'hello'));
  });

  test('toJson/fromJson round-trip with timestamps set', () {
    const line = SubtitleLine(
      index: 3,
      text: 'hi there',
      startMs: 1000,
      endMs: 2500,
    );
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('toJson/fromJson round-trip with null timestamps', () {
    const line = SubtitleLine(index: 3, text: 'hi there');
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('hasInvalidRange rejects negative and non-positive ranges', () {
    expect(
      const SubtitleLine(
        index: 0,
        text: 'negative',
        startMs: -1,
      ).hasInvalidRange,
      isTrue,
    );
    expect(
      const SubtitleLine(
        index: 0,
        text: 'backwards',
        startMs: 200,
        endMs: 100,
      ).hasInvalidRange,
      isTrue,
    );
    expect(
      const SubtitleLine(
        index: 0,
        text: 'valid',
        startMs: 100,
        endMs: 200,
      ).hasInvalidRange,
      isFalse,
    );
  });
}

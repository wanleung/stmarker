import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  test('isFullyMarked is false when either timestamp is missing', () {
    const line = SubtitleLine(index: 0, text: 'hello');
    expect(line.isFullyMarked, isFalse);
  });

  test('isFullyMarked is true when both timestamps are set', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    expect(line.isFullyMarked, isTrue);
  });

  test('copyWith only overrides provided fields', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100);
    final updated = line.copyWith(endMs: 200);
    expect(updated, const SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200));
  });

  test('withExactTimestamps replaces both fields even with null', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    final updated = line.withExactTimestamps(startMs: 50);
    expect(updated, const SubtitleLine(index: 0, text: 'hello', startMs: 50));
  });

  test('clearTimestamps resets both to null', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    expect(line.clearTimestamps(), const SubtitleLine(index: 0, text: 'hello'));
  });

  test('toJson/fromJson round-trip with timestamps set', () {
    const line = SubtitleLine(index: 3, text: 'hi there', startMs: 1000, endMs: 2500);
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('toJson/fromJson round-trip with null timestamps', () {
    const line = SubtitleLine(index: 3, text: 'hi there');
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });
}

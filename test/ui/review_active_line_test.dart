import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/ui/review_active_line.dart';

void main() {
  test('matches inside an interval and includes only its start boundary', () {
    const lines = [
      SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
    ];

    expect(findActiveReviewLine(lines, 100), 0);
    expect(findActiveReviewLine(lines, 199), 0);
    expect(findActiveReviewLine(lines, 200), isNull);
  });

  test('returns null in gaps between intervals', () {
    const lines = [
      SubtitleLine(index: 0, text: 'first', startMs: 100, endMs: 200),
      SubtitleLine(index: 1, text: 'second', startMs: 300, endMs: 400),
    ];

    expect(findActiveReviewLine(lines, 250), isNull);
  });

  test('skips incomplete lines', () {
    const lines = [
      SubtitleLine(index: 0, text: 'unmarked'),
      SubtitleLine(index: 1, text: 'start only', startMs: 100),
      SubtitleLine(index: 2, text: 'end only', endMs: 200),
    ];

    expect(findActiveReviewLine(lines, 150), isNull);
  });

  test('returns the first list-order match for overlapping intervals', () {
    const lines = [
      SubtitleLine(index: 8, text: 'earlier in list', startMs: 100, endMs: 300),
      SubtitleLine(index: 2, text: 'later in list', startMs: 150, endMs: 250),
    ];

    expect(findActiveReviewLine(lines, 200), 0);
  });
}

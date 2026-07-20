// test/services/srt_codec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/srt_codec.dart';

void main() {
  test('encode formats a single fully-marked line correctly', () {
    const lines = [
      SubtitleLine(
        index: 0,
        text: "it's been a while",
        startMs: 92100,
        endMs: 94800,
      ),
    ];
    expect(
      SrtCodec.encode(lines),
      "1\n00:01:32,100 --> 00:01:34,800\nit's been a while\n",
    );
  });

  test(
    'encode skips lines missing a start or end, renumbering what remains',
    () {
      const lines = [
        SubtitleLine(index: 0, text: 'no timing'),
        SubtitleLine(index: 1, text: 'only start', startMs: 1000),
        SubtitleLine(index: 2, text: 'complete', startMs: 2000, endMs: 3000),
      ];
      expect(
        SrtCodec.encode(lines),
        "1\n00:00:02,000 --> 00:00:03,000\ncomplete\n",
      );
    },
  );

  test('decode parses a two-entry SRT file', () {
    const content =
        '1\n'
        '00:01:32,100 --> 00:01:34,800\n'
        "it's been a while\n"
        '\n'
        '2\n'
        '00:01:35,000 --> 00:01:37,200\n'
        "since I've seen your face\n";
    expect(SrtCodec.decode(content), const [
      SubtitleLine(
        index: 0,
        text: "it's been a while",
        startMs: 92100,
        endMs: 94800,
      ),
      SubtitleLine(
        index: 1,
        text: "since I've seen your face",
        startMs: 95000,
        endMs: 97200,
      ),
    ]);
  });

  test('decode ignores malformed blocks without a valid time line', () {
    const content = '1\nnot a timestamp\nsome text\n';
    expect(SrtCodec.decode(content), isEmpty);
  });

  test('encode then decode round-trips timestamps and text', () {
    const original = [
      SubtitleLine(index: 0, text: 'line one', startMs: 500, endMs: 1500),
      SubtitleLine(index: 1, text: 'line two', startMs: 1600, endMs: 3000),
    ];
    expect(SrtCodec.decode(SrtCodec.encode(original)), original);
  });

  test('invalidLines identifies ranges that need an export warning', () {
    const lines = [
      SubtitleLine(index: 0, text: 'valid', startMs: 100, endMs: 200),
      SubtitleLine(index: 1, text: 'equal', startMs: 300, endMs: 300),
      SubtitleLine(index: 2, text: 'negative', startMs: -1, endMs: 100),
      SubtitleLine(index: 3, text: 'incomplete', startMs: 400),
    ];

    expect(SrtCodec.invalidLines(lines).map((line) => line.index), [1, 2]);
  });
}

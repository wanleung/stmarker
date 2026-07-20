import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/lrc_codec.dart';

void main() {
  test(
    'decode parses centisecond timestamps into startMs, leaving endMs null',
    () {
      const content =
          "[ar:Someone]\n[01:32.10]it's been a while\n[01:35.00]since I've seen your face\n";
      expect(LrcCodec.decode(content), const [
        SubtitleLine(index: 0, text: "it's been a while", startMs: 92100),
        SubtitleLine(
          index: 1,
          text: "since I've seen your face",
          startMs: 95000,
        ),
      ]);
    },
  );

  test('decode supports millisecond-precision tags', () {
    const content = '[00:02.500]precise line';
    expect(LrcCodec.decode(content), const [
      SubtitleLine(index: 0, text: 'precise line', startMs: 2500),
    ]);
  });

  test('decode ignores lines with no valid time tag', () {
    const content = '[00:01.00]kept\nnot a tag at all\n';
    expect(LrcCodec.decode(content), const [
      SubtitleLine(index: 0, text: 'kept', startMs: 1000),
    ]);
  });
}

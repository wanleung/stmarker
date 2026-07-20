import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/ass_codec.dart';

void main() {
  test('encode writes the exact ASS headers and selected style', () {
    expect(
      AssCodec.encode(const [], fontFamily: 'Noto Sans CJK SC', fontSize: 36.0),
      '[Script Info]\n'
      'ScriptType: v4.00+\n'
      'PlayResX: 1280\n'
      'PlayResY: 720\n'
      'WrapStyle: 0\n'
      'ScaledBorderAndShadow: yes\n'
      '\n'
      '[V4+ Styles]\n'
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
      'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, '
      'ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, '
      'MarginL, MarginR, MarginV, Encoding\n'
      'Style: Default,Noto Sans CJK SC,36,&H00FFFFFF,&H000000FF,&H00000000,'
      '&H64000000,0,0,0,0,100,100,0,0,1,2,0,2,20,20,20,1\n'
      '\n'
      '[Events]\n'
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, '
      'Effect, Text\n',
    );
  });

  test('encode trims only an integral font size representation', () {
    expect(
      AssCodec.encode(const [], fontFamily: 'Family', fontSize: 35.5),
      contains('Style: Default,Family,35.5,'),
    );
  });

  test('encode preserves input order and skips unusable ranges', () {
    const lines = [
      SubtitleLine(index: 9, text: 'first', startMs: 1500, endMs: 2500),
      SubtitleLine(index: 0, text: 'incomplete', startMs: 3000),
      SubtitleLine(index: 1, text: 'equal', startMs: 4000, endMs: 4000),
      SubtitleLine(index: 2, text: 'negative', startMs: -1, endMs: 1000),
      SubtitleLine(index: 3, text: 'backwards', startMs: 6000, endMs: 5000),
      SubtitleLine(index: 4, text: 'second', startMs: 100, endMs: 900),
    ];

    final events = AssCodec.encode(
      lines,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').where((line) => line.startsWith('Dialogue:')).toList();

    expect(events, [
      'Dialogue: 0,0:00:01.50,0:00:02.50,Default,,0,0,0,,first',
      'Dialogue: 0,0:00:00.10,0:00:00.90,Default,,0,0,0,,second',
    ]);
  });

  test('encode rounds each millisecond timestamp to nearest centisecond', () {
    const lines = [
      SubtitleLine(index: 0, text: 'round', startMs: 4, endMs: 995),
      SubtitleLine(index: 1, text: 'carry', startMs: 3599995, endMs: 3600005),
    ];

    final output = AssCodec.encode(lines, fontFamily: 'Family', fontSize: 24);

    expect(
      output,
      contains('Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,round'),
    );
    expect(
      output,
      contains('Dialogue: 0,1:00:00.00,1:00:00.01,Default,,0,0,0,,carry'),
    );
  });

  test('encode keeps commas in Text and escapes ASS control syntax', () {
    const lines = [
      SubtitleLine(
        index: 0,
        text: 'one,two {\\b1} C:\\New\r\nnext\nlast',
        startMs: 0,
        endMs: 1000,
      ),
    ];

    final event = AssCodec.encode(
      lines,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').singleWhere((line) => line.startsWith('Dialogue:'));

    expect(
      event,
      r'Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,one,two \{\\b1\} C:\\New\Nnext\Nlast',
    );
    expect(event.split(',').take(10).length, 10);
  });
}

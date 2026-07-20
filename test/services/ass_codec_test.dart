import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/ass_codec.dart';

void main() {
  test('karaoke validation exceptions snapshot immutable line numbers', () {
    final source = [2, 4];
    final error = AssKaraokeValidationException(source);
    source.add(6);

    expect(error.lineNumbers, [2, 4]);
    expect(() => error.lineNumbers.add(8), throwsUnsupportedError);
  });

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

  test('encode converts a lone carriage return to an ASS line break', () {
    const lines = [
      SubtitleLine(index: 0, text: 'first\rsecond', startMs: 0, endMs: 1000),
    ];

    final output = AssCodec.encode(lines, fontFamily: 'Family', fontSize: 24);

    expect(output, contains(r',,first\Nsecond'));
  });

  test('encodeProject keeps Standard output byte-for-byte compatible', () {
    const lines = [
      SubtitleLine(index: 0, text: 'Hello', startMs: 1000, endMs: 2000),
    ];
    final project = _project(lines: lines);

    expect(
      AssCodec.encodeProject(project, fontFamily: 'Family', fontSize: 24),
      AssCodec.encode(lines, fontFamily: 'Family', fontSize: 24),
    );
  });

  test('Easy karaoke writes gold-to-white kf tags and escapes only text', () {
    final project = _project(
      mode: KaraokeMode.karaokeEasy,
      lines: const [
        SubtitleLine(
          index: 0,
          text: r'one {two}\three',
          startMs: 0,
          endMs: 1000,
        ),
      ],
    );

    final output = AssCodec.encodeProject(
      project,
      fontFamily: 'Family',
      fontSize: 24,
    );

    expect(
      output,
      contains(
        'Style: Default,Family,24,&H00FFFFFF,&H000000FF,&H00000000,'
        '&H64000000,0,0,0,0,100,100,0,0,1,2,0,2,20,20,20,1',
      ),
    );
    expect(
      output,
      contains(
        'Style: KaraokeTop,Family,24,&H0000D7FF,&H00FFFFFF,&H00000000,'
        '&H64000000,0,0,0,0,100,100,0,0,1,2,0,8,20,20,20,1',
      ),
    );
    expect(
      output,
      contains(
        r'Dialogue: 0,0:00:00.00,0:00:01.00,KaraokeTop,,0,0,0,,{\kf50}one{\kf50} \{two\}\\three',
      ),
    );
  });

  test('Advanced assigns centisecond rounding remainder to the final unit', () {
    final project = _project(
      mode: KaraokeMode.karaokeAdvanced,
      lines: [
        SubtitleLine.withKaraokeMarks(
          index: 1,
          text: 'a b',
          startMs: 0,
          endMs: 30,
          karaokeMarks: const [
            KaraokeMark(unitText: 'a', startMs: 0),
            KaraokeMark(unitText: 'b', startMs: 15),
          ],
        ),
      ],
    );

    final event = AssCodec.encodeProject(
      project,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').singleWhere((line) => line.startsWith('Dialogue:'));

    expect(event, endsWith(r',,{\kf1}a{\kf2} b'));
  });

  test('rejects lines whose rounded duration cannot give every unit 1cs', () {
    final project = _project(
      mode: KaraokeMode.karaokeAdvanced,
      lines: [
        SubtitleLine.withKaraokeMarks(
          index: 0,
          text: 'a b c d',
          startMs: 0,
          endMs: 24,
          karaokeMarks: const [
            KaraokeMark(unitText: 'a', startMs: 0),
            KaraokeMark(unitText: 'b', startMs: 6),
            KaraokeMark(unitText: 'c', startMs: 12),
            KaraokeMark(unitText: 'd', startMs: 18),
          ],
        ),
      ],
    );

    expect(
      () => AssCodec.encodeProject(project, fontFamily: 'Family', fontSize: 24),
      throwsA(
        isA<AssKaraokeValidationException>().having(
          (error) => error.lineNumbers,
          'lineNumbers',
          [1],
        ),
      ),
    );
  });

  test('sub-10ms units receive positive durations with an exact total', () {
    final project = _project(
      mode: KaraokeMode.karaokeAdvanced,
      lines: [
        SubtitleLine.withKaraokeMarks(
          index: 0,
          text: 'a b c',
          startMs: 0,
          endMs: 30,
          karaokeMarks: const [
            KaraokeMark(unitText: 'a', startMs: 0),
            KaraokeMark(unitText: 'b', startMs: 6),
            KaraokeMark(unitText: 'c', startMs: 12),
          ],
        ),
      ],
    );

    final event = AssCodec.encodeProject(
      project,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').singleWhere((line) => line.startsWith('Dialogue:'));
    final durations = RegExp(
      r'\\kf(\d+)',
    ).allMatches(event).map((match) => int.parse(match.group(1)!)).toList();

    expect(durations, [1, 1, 1]);
    expect(durations.every((duration) => duration > 0), isTrue);
    expect(durations.reduce((left, right) => left + right), 3);
    expect(event, isNot(contains(r'\kf0')));
  });

  test('kf durations sum to the rounded active millisecond duration', () {
    final project = _project(
      mode: KaraokeMode.karaokeEasy,
      lines: const [
        SubtitleLine(index: 0, text: 'one two', startMs: 4, endMs: 995),
      ],
    );

    final event = AssCodec.encodeProject(
      project,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').singleWhere((line) => line.startsWith('Dialogue:'));
    final durations = RegExp(
      r'\\kf(\d+)',
    ).allMatches(event).map((match) => int.parse(match.group(1)!));

    expect(durations.reduce((left, right) => left + right), 99);
  });

  test('timed pre-display clamps start and keeps text white during delay', () {
    for (final entry in const [
      (KaraokePreDisplay.seconds3, 2000, 0, 200),
      (KaraokePreDisplay.seconds4, 6000, 2000, 400),
      (KaraokePreDisplay.seconds5, 7000, 2000, 500),
    ]) {
      final project = _project(
        mode: KaraokeMode.karaokeEasy,
        preDisplay: entry.$1,
        lines: [
          SubtitleLine(
            index: 0,
            text: 'hello',
            startMs: entry.$2,
            endMs: entry.$2 + 1000,
          ),
        ],
      );

      final event = AssCodec.encodeProject(
        project,
        fontFamily: 'Family',
        fontSize: 24,
      ).split('\n').singleWhere((line) => line.startsWith('Dialogue:'));

      expect(
        event,
        startsWith(
          'Dialogue: 0,${_timestamp(entry.$3)},${_timestamp(entry.$2 + 1000)},',
        ),
      );
      expect(
        event,
        endsWith(
          r',,{\kf'
          '${entry.$4}'
          r'}{\kf100}hello',
        ),
      );
    }
  });

  test('one-line-ahead uses fixed parity rows and half-open previews', () {
    final project = _project(
      mode: KaraokeMode.karaokeEasy,
      preDisplay: KaraokePreDisplay.oneLineAhead,
      lines: const [
        SubtitleLine(index: 0, text: 'first', startMs: 1000, endMs: 2000),
        SubtitleLine(index: 1, text: 'skip', startMs: 2500),
        SubtitleLine(index: 2, text: 'second', startMs: 3000, endMs: 4000),
        SubtitleLine(index: 3, text: 'third', startMs: 4500, endMs: 5000),
      ],
    );

    final events = AssCodec.encodeProject(
      project,
      fontFamily: 'Family',
      fontSize: 24,
    ).split('\n').where((line) => line.startsWith('Dialogue:')).toList();

    expect(events, [
      r'Dialogue: 0,0:00:01.00,0:00:02.00,KaraokeTop,,0,0,0,,{\kf100}first',
      r'Dialogue: 0,0:00:01.00,0:00:03.00,KaraokeTop,,0,0,0,,{\1c&H00FFFFFF&}second',
      r'Dialogue: 0,0:00:03.00,0:00:04.00,KaraokeTop,,0,0,0,,{\kf100}second',
      r'Dialogue: 0,0:00:03.00,0:00:04.50,KaraokeBottom,,0,0,0,,{\1c&H00FFFFFF&}third',
      r'Dialogue: 0,0:00:04.50,0:00:05.00,KaraokeBottom,,0,0,0,,{\kf50}third',
    ]);
  });
}

Project _project({
  KaraokeMode mode = KaraokeMode.standard,
  KaraokePreDisplay preDisplay = KaraokePreDisplay.off,
  required List<SubtitleLine> lines,
}) => Project(
  mediaPath: '/tmp/media.mp4',
  karaokeMode: mode,
  karaokePreDisplay: preDisplay,
  lines: lines,
);

String _timestamp(int milliseconds) {
  final centiseconds = milliseconds ~/ 10;
  final seconds = centiseconds ~/ 100;
  final fraction = centiseconds % 100;
  return '0:00:${seconds.toString().padLeft(2, '0')}.${fraction.toString().padLeft(2, '0')}';
}

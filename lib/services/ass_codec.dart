import '../models/subtitle_line.dart';

class AssCodec {
  const AssCodec._();

  static String encode(
    List<SubtitleLine> lines, {
    required String fontFamily,
    required double fontSize,
  }) {
    final buffer = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('PlayResX: 1280')
      ..writeln('PlayResY: 720')
      ..writeln('WrapStyle: 0')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
        'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, '
        'ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, '
        'MarginL, MarginR, MarginV, Encoding',
      )
      ..writeln(
        'Style: Default,$fontFamily,${_formatFontSize(fontSize)},&H00FFFFFF,'
        '&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,0,2,'
        '20,20,20,1',
      )
      ..writeln()
      ..writeln('[Events]')
      ..writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, '
        'Effect, Text',
      );

    for (final line in lines) {
      if (!line.isFullyMarked || line.hasInvalidRange) continue;
      buffer.writeln(
        'Dialogue: 0,${_formatTimestamp(line.startMs!)},'
        '${_formatTimestamp(line.endMs!)},Default,,0,0,0,,${_escapeText(line.text)}',
      );
    }
    return buffer.toString();
  }

  static String _formatFontSize(double fontSize) {
    final value = fontSize.toString();
    return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
  }

  static String _formatTimestamp(int milliseconds) {
    final centiseconds = (milliseconds + 5) ~/ 10;
    final hours = centiseconds ~/ 360000;
    final minutes = (centiseconds % 360000) ~/ 6000;
    final seconds = (centiseconds % 6000) ~/ 100;
    final fraction = centiseconds % 100;
    String pad2(int value) => value.toString().padLeft(2, '0');
    return '$hours:${pad2(minutes)}:${pad2(seconds)}.${pad2(fraction)}';
  }

  static String _escapeText(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}')
      .replaceAll('\r\n', r'\N')
      .replaceAll('\r', r'\N')
      .replaceAll('\n', r'\N');
}

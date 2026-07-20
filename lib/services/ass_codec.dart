import '../karaoke/karaoke_models.dart';
import '../karaoke/karaoke_timing.dart';
import '../models/project.dart';
import '../models/subtitle_line.dart';

final class AssKaraokeValidationException implements Exception {
  AssKaraokeValidationException(List<int> lineNumbers)
    : lineNumbers = List.unmodifiable(lineNumbers);

  final List<int> lineNumbers;

  @override
  String toString() =>
      'Invalid karaoke timing on line(s): ${lineNumbers.join(', ')}';
}

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

  static String encodeProject(
    Project project, {
    required String fontFamily,
    required double fontSize,
  }) {
    if (project.karaokeMode == KaraokeMode.standard) {
      return encode(project.lines, fontFamily: fontFamily, fontSize: fontSize);
    }
    final invalidLineNumbers = invalidKaraokeLineNumbers(project);
    if (invalidLineNumbers.isNotEmpty) {
      throw AssKaraokeValidationException(invalidLineNumbers);
    }

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
      ..writeln(_karaokeStyle('KaraokeTop', fontFamily, fontSize, 8))
      ..writeln(_karaokeStyle('KaraokeBottom', fontFamily, fontSize, 2))
      ..writeln()
      ..writeln('[Events]')
      ..writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, '
        'Effect, Text',
      );

    final resolved = <_ResolvedKaraokeLine>[];
    for (final line in project.lines) {
      final segments = resolveKaraokeSegments(line, project.karaokeMode);
      if (segments.isEmpty) continue;
      resolved.add(_ResolvedKaraokeLine(line, segments));
    }

    for (var index = 0; index < resolved.length; index++) {
      final current = resolved[index];
      final singingStartMs = current.segments.first.startMs;
      final eventStartMs = switch (project.karaokePreDisplay) {
        KaraokePreDisplay.seconds3 ||
        KaraokePreDisplay.seconds4 ||
        KaraokePreDisplay.seconds5 =>
          (singingStartMs - project.karaokePreDisplay.leadMs!).clamp(
            0,
            singingStartMs,
          ),
        KaraokePreDisplay.off ||
        KaraokePreDisplay.oneLineAhead => singingStartMs,
      };
      buffer.writeln(
        _dialogue(
          startMs: eventStartMs,
          endMs: current.segments.last.endMs,
          style: _karaokeStyleFor(current.line),
          text: _karaokeText(current.segments, eventStartMs: eventStartMs),
        ),
      );

      if (project.karaokePreDisplay != KaraokePreDisplay.oneLineAhead ||
          index + 1 >= resolved.length) {
        continue;
      }
      final next = resolved[index + 1];
      final nextStartMs = next.segments.first.startMs;
      if (singingStartMs >= nextStartMs) continue;
      buffer.writeln(
        _dialogue(
          startMs: singingStartMs,
          endMs: nextStartMs,
          style: _karaokeStyleFor(next.line),
          text: r'{\1c&H00FFFFFF&}' + _escapeText(next.line.text),
        ),
      );
    }
    return buffer.toString();
  }

  static List<int> invalidKaraokeLineNumbers(Project project) {
    if (project.karaokeMode == KaraokeMode.standard) return const [];

    return List.unmodifiable([
      for (final line in project.lines)
        if (line.isFullyMarked &&
            !_canEncodeKaraokeLine(line, project.karaokeMode))
          line.index + 1,
    ]);
  }

  static bool _canEncodeKaraokeLine(SubtitleLine line, KaraokeMode mode) {
    if (karaokeTimingIssue(line, mode) != null) return false;
    final segments = resolveKaraokeSegments(line, mode);
    if (segments.isEmpty) return false;
    final totalDuration = _roundedCentiseconds(
      segments.last.endMs - segments.first.startMs,
    );
    return totalDuration >= segments.length;
  }

  static String _karaokeStyle(
    String name,
    String fontFamily,
    double fontSize,
    int alignment,
  ) =>
      'Style: $name,$fontFamily,${_formatFontSize(fontSize)},&H0000D7FF,'
      '&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,0,'
      '$alignment,20,20,20,1';

  static String _karaokeStyleFor(SubtitleLine line) =>
      line.index.isEven ? 'KaraokeTop' : 'KaraokeBottom';

  static String _dialogue({
    required int startMs,
    required int endMs,
    required String style,
    required String text,
  }) =>
      'Dialogue: 0,${_formatTimestamp(startMs)},${_formatTimestamp(endMs)},'
      '$style,,0,0,0,,$text';

  static String _karaokeText(
    List<KaraokeSegment> segments, {
    required int eventStartMs,
  }) {
    final buffer = StringBuffer();
    final singingStartMs = segments.first.startMs;
    if (eventStartMs < singingStartMs) {
      final delay = _roundedCentiseconds(singingStartMs - eventStartMs);
      if (delay > 0) buffer.write('{\\kf$delay}');
    }

    final durations = _karaokeDurations(segments);
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      buffer
        ..write('{\\kf${durations[index]}}')
        ..write(_escapeText(segment.text));
    }
    return buffer.toString();
  }

  static List<int> _karaokeDurations(List<KaraokeSegment> segments) {
    final totalDuration = _roundedCentiseconds(
      segments.last.endMs - segments.first.startMs,
    );
    final durations = List<int>.filled(segments.length, 1);
    var remaining = totalDuration - segments.length;

    // Preserve each non-final unit's floored duration when the total permits;
    // the final unit receives the stable exact remainder.
    for (var index = 0; index < segments.length - 1; index++) {
      final floored = (segments[index].endMs - segments[index].startMs) ~/ 10;
      final extra = (floored - 1).clamp(0, remaining);
      durations[index] += extra;
      remaining -= extra;
    }
    durations[durations.length - 1] += remaining;
    return durations;
  }

  static int _roundedCentiseconds(int milliseconds) => (milliseconds + 5) ~/ 10;

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

final class _ResolvedKaraokeLine {
  const _ResolvedKaraokeLine(this.line, this.segments);

  final SubtitleLine line;
  final List<KaraokeSegment> segments;
}

import '../models/subtitle_line.dart';

class LrcCodec {
  const LrcCodec._();

  static final RegExp _tag = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

  static List<SubtitleLine> decode(String content) {
    final result = <SubtitleLine>[];
    final rawLines = content.replaceAll('\r\n', '\n').split('\n');
    for (final rawLine in rawLines) {
      final match = _tag.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3)!;
      final millis = fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;
      final startMs = (minutes * 60 + seconds) * 1000 + millis;
      result.add(SubtitleLine(index: result.length, text: text, startMs: startMs));
    }
    return result;
  }
}

import '../models/subtitle_line.dart';

class SrtCodec {
  const SrtCodec._();

  static final RegExp _timeLine = RegExp(
    r'^(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})',
  );

  static String encode(List<SubtitleLine> lines) {
    final marked = lines.where((line) => line.isFullyMarked).toList();
    final buffer = StringBuffer();
    for (var i = 0; i < marked.length; i++) {
      final line = marked[i];
      buffer.writeln(i + 1);
      buffer.writeln('${_formatTimestamp(line.startMs!)} --> ${_formatTimestamp(line.endMs!)}');
      buffer.writeln(line.text);
      if (i != marked.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  static List<SubtitleLine> decode(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return [];
    final blocks = normalized.split(RegExp(r'\n{2,}'));
    final result = <SubtitleLine>[];
    for (final rawBlock in blocks) {
      final blockLines = rawBlock.trim().split('\n');
      if (blockLines.length < 2) continue;
      final match = _timeLine.firstMatch(blockLines[1].trim());
      if (match == null) continue;
      final startMs = _msFromGroups(match, 1);
      final endMs = _msFromGroups(match, 5);
      final text = blockLines.sublist(2).join('\n');
      result.add(SubtitleLine(index: result.length, text: text, startMs: startMs, endMs: endMs));
    }
    return result;
  }

  static int _msFromGroups(RegExpMatch match, int startGroup) {
    final hours = int.parse(match.group(startGroup)!);
    final minutes = int.parse(match.group(startGroup + 1)!);
    final seconds = int.parse(match.group(startGroup + 2)!);
    final millis = int.parse(match.group(startGroup + 3)!);
    return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
  }

  static String _formatTimestamp(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    String pad2(int n) => n.toString().padLeft(2, '0');
    String pad3(int n) => n.toString().padLeft(3, '0');
    return '${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)},${pad3(millis)}';
  }
}

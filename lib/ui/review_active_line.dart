import '../models/subtitle_line.dart';

int? findActiveReviewLine(List<SubtitleLine> lines, int positionMs) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final startMs = line.startMs;
    final endMs = line.endMs;
    if (startMs != null &&
        endMs != null &&
        startMs <= positionMs &&
        positionMs < endMs) {
      return index;
    }
  }
  return null;
}

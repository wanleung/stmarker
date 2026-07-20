import '../karaoke/karaoke_models.dart';

class SubtitleLine {
  SubtitleLine({
    required this.index,
    required this.text,
    this.startMs,
    this.endMs,
    List<KaraokeMark> karaokeMarks = const [],
  }) : karaokeMarks = List.unmodifiable(karaokeMarks);

  final int index;
  final String text;
  final int? startMs;
  final int? endMs;
  final List<KaraokeMark> karaokeMarks;

  bool get isFullyMarked => startMs != null && endMs != null;

  /// A completed range must be non-negative and have a positive duration.
  bool get hasInvalidRange =>
      (startMs != null && startMs! < 0) ||
      (endMs != null && endMs! < 0) ||
      (startMs != null && endMs != null && endMs! <= startMs!);

  /// Overrides only the fields provided; omitted fields keep their value.
  SubtitleLine copyWith({int? startMs, int? endMs}) {
    final nextStartMs = startMs ?? this.startMs;
    final nextEndMs = endMs ?? this.endMs;
    return SubtitleLine(
      index: index,
      text: text,
      startMs: nextStartMs,
      endMs: nextEndMs,
      karaokeMarks: nextStartMs == this.startMs && nextEndMs == this.endMs
          ? karaokeMarks
          : const [],
    );
  }

  /// Replaces both timestamps outright, including with null — unlike
  /// [copyWith], which can't be used to clear a single field back to null.
  SubtitleLine withExactTimestamps({int? startMs, int? endMs}) {
    return SubtitleLine(
      index: index,
      text: text,
      startMs: startMs,
      endMs: endMs,
      karaokeMarks: startMs == this.startMs && endMs == this.endMs
          ? karaokeMarks
          : const [],
    );
  }

  SubtitleLine clearTimestamps() {
    return SubtitleLine(index: index, text: text);
  }

  SubtitleLine withText(String text) {
    return SubtitleLine(
      index: index,
      text: text,
      startMs: startMs,
      endMs: endMs,
      karaokeMarks: text == this.text ? karaokeMarks : const [],
    );
  }

  SubtitleLine withAdvancedKaraoke({
    required int startMs,
    required List<KaraokeMark> marks,
  }) {
    return SubtitleLine(
      index: index,
      text: text,
      startMs: startMs,
      endMs: endMs,
      karaokeMarks: marks,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
    'karaokeMarks': karaokeMarks.map((mark) => mark.toJson()).toList(),
  };

  factory SubtitleLine.fromJson(Map<String, dynamic> json) {
    final rawMarks = json['karaokeMarks'];
    final marks = <KaraokeMark>[];
    if (rawMarks is List) {
      for (final rawMark in rawMarks) {
        if (rawMark is! Map) continue;
        final unitText = rawMark['unitText'];
        final startMs = rawMark['startMs'];
        if (unitText is String && startMs is int) {
          marks.add(KaraokeMark(unitText: unitText, startMs: startMs));
        }
      }
    }

    return SubtitleLine(
      index: json['index'] as int,
      text: json['text'] as String,
      startMs: json['startMs'] as int?,
      endMs: json['endMs'] as int?,
      karaokeMarks: marks,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SubtitleLine &&
      other.index == index &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      _marksEqual(other.karaokeMarks, karaokeMarks);

  @override
  int get hashCode =>
      Object.hash(index, text, startMs, endMs, Object.hashAll(karaokeMarks));
}

bool _marksEqual(List<KaraokeMark> left, List<KaraokeMark> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

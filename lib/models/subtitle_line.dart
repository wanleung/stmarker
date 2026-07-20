class SubtitleLine {
  const SubtitleLine({
    required this.index,
    required this.text,
    this.startMs,
    this.endMs,
  });

  final int index;
  final String text;
  final int? startMs;
  final int? endMs;

  bool get isFullyMarked => startMs != null && endMs != null;

  /// A completed range must be non-negative and have a positive duration.
  bool get hasInvalidRange =>
      (startMs != null && startMs! < 0) ||
      (endMs != null && endMs! < 0) ||
      (startMs != null && endMs != null && endMs! <= startMs!);

  /// Overrides only the fields provided; omitted fields keep their value.
  SubtitleLine copyWith({int? startMs, int? endMs}) {
    return SubtitleLine(
      index: index,
      text: text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
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
    );
  }

  SubtitleLine clearTimestamps() {
    return SubtitleLine(index: index, text: text);
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory SubtitleLine.fromJson(Map<String, dynamic> json) => SubtitleLine(
    index: json['index'] as int,
    text: json['text'] as String,
    startMs: json['startMs'] as int?,
    endMs: json['endMs'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is SubtitleLine &&
      other.index == index &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(index, text, startMs, endMs);
}

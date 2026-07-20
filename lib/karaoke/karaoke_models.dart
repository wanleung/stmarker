enum KaraokeMode { standard, karaokeEasy, karaokeAdvanced }

enum KaraokePreDisplay { off, seconds3, seconds4, seconds5, oneLineAhead }

extension KaraokePreDisplayDuration on KaraokePreDisplay {
  int? get leadMs => switch (this) {
    KaraokePreDisplay.seconds3 => 3000,
    KaraokePreDisplay.seconds4 => 4000,
    KaraokePreDisplay.seconds5 => 5000,
    KaraokePreDisplay.off || KaraokePreDisplay.oneLineAhead => null,
  };
}

KaraokeMode karaokeModeFromName(Object? name) => KaraokeMode.values.firstWhere(
  (value) => value.name == name,
  orElse: () => KaraokeMode.standard,
);

KaraokePreDisplay karaokePreDisplayFromName(Object? name) =>
    KaraokePreDisplay.values.firstWhere(
      (value) => value.name == name,
      orElse: () => KaraokePreDisplay.off,
    );

final class KaraokeMark {
  const KaraokeMark({required this.unitText, required this.startMs});

  final String unitText;
  final int startMs;

  Map<String, Object> toJson() => {'unitText': unitText, 'startMs': startMs};

  factory KaraokeMark.fromJson(Map<String, dynamic> json) => KaraokeMark(
    unitText: json['unitText'] as String,
    startMs: json['startMs'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is KaraokeMark &&
      other.unitText == unitText &&
      other.startMs == startMs;

  @override
  int get hashCode => Object.hash(unitText, startMs);
}

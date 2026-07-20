import 'subtitle_line.dart';

class Project {
  const Project({
    required this.mediaPath,
    this.playbackRate = 1.0,
    required this.lines,
  });

  final String mediaPath;
  final double playbackRate;
  final List<SubtitleLine> lines;

  Project copyWith({
    String? mediaPath,
    double? playbackRate,
    List<SubtitleLine>? lines,
  }) {
    return Project(
      mediaPath: mediaPath ?? this.mediaPath,
      playbackRate: playbackRate ?? this.playbackRate,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() => {
    'mediaPath': mediaPath,
    'playbackRate': playbackRate,
    'lines': lines.map((line) => line.toJson()).toList(),
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    mediaPath: json['mediaPath'] as String,
    playbackRate: (json['playbackRate'] as num?)?.toDouble() ?? 1.0,
    lines: (json['lines'] as List<dynamic>)
        .map((raw) => SubtitleLine.fromJson(raw as Map<String, dynamic>))
        .toList(),
  );
}

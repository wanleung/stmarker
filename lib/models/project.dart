import '../karaoke/karaoke_models.dart';
import 'subtitle_line.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';

const double defaultSubtitleFontSize = 24.0;
const double minimumSubtitleFontSize = 16.0;
const double maximumSubtitleFontSize = 64.0;

class Project {
  const Project({
    required this.mediaPath,
    this.playbackRate = 1.0,
    this.subtitleFontFamily = 'noto_sans_cjk',
    this.subtitleFontSize = defaultSubtitleFontSize,
    this.karaokeMode = KaraokeMode.standard,
    this.karaokePreDisplay = KaraokePreDisplay.off,
    required this.lines,
  });

  final String mediaPath;
  final double playbackRate;
  final String subtitleFontFamily;
  final double subtitleFontSize;
  final KaraokeMode karaokeMode;
  final KaraokePreDisplay karaokePreDisplay;
  final List<SubtitleLine> lines;

  Project copyWith({
    String? mediaPath,
    double? playbackRate,
    String? subtitleFontFamily,
    double? subtitleFontSize,
    KaraokeMode? karaokeMode,
    KaraokePreDisplay? karaokePreDisplay,
    List<SubtitleLine>? lines,
  }) {
    return Project(
      mediaPath: mediaPath ?? this.mediaPath,
      playbackRate: playbackRate ?? this.playbackRate,
      subtitleFontFamily: subtitleFontFamily ?? this.subtitleFontFamily,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      karaokeMode: karaokeMode ?? this.karaokeMode,
      karaokePreDisplay: karaokePreDisplay ?? this.karaokePreDisplay,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() => {
    'mediaPath': mediaPath,
    'playbackRate': playbackRate,
    'subtitleFontFamily': subtitleFontFamily,
    'subtitleFontSize': subtitleFontSize,
    'karaokeMode': karaokeMode.name,
    'karaokePreDisplay': karaokePreDisplay.name,
    'lines': lines.map((line) => line.toJson()).toList(),
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawFontSize =
        (json['subtitleFontSize'] as num?)?.toDouble() ??
        defaultSubtitleFontSize;
    final fontSize = rawFontSize.isFinite
        ? rawFontSize.clamp(minimumSubtitleFontSize, maximumSubtitleFontSize)
        : defaultSubtitleFontSize;

    return Project(
      mediaPath: json['mediaPath'] as String,
      playbackRate: (json['playbackRate'] as num?)?.toDouble() ?? 1.0,
      subtitleFontFamily: SubtitleFontCatalog.byId(
        json['subtitleFontFamily'] as String?,
      ).id,
      subtitleFontSize: fontSize,
      karaokeMode: karaokeModeFromName(json['karaokeMode']),
      karaokePreDisplay: karaokePreDisplayFromName(json['karaokePreDisplay']),
      lines: (json['lines'] as List<dynamic>)
          .map((raw) => SubtitleLine.fromJson(raw as Map<String, dynamic>))
          .toList(),
    );
  }
}

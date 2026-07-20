import 'package:flutter/services.dart';

import '../models/project.dart';
import '../models/subtitle_line.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';
import 'asset_bytes_loader.dart';

final class ExportWarnings {
  const ExportWarnings({
    required this.invalidCount,
    required this.incompleteCount,
  });

  final int invalidCount;
  final int incompleteCount;

  bool get isEmpty => invalidCount == 0 && incompleteCount == 0;

  String get message =>
      '${invalidCount == 0 ? '' : '$invalidCount line(s) have invalid ranges. '}'
      '${incompleteCount == 0 ? '' : '$incompleteCount incomplete line(s) will be skipped. '}'
      'Export anyway?';
}

ExportWarnings exportWarnings(List<SubtitleLine> lines) => ExportWarnings(
  invalidCount: lines.where((line) => line.hasInvalidRange).length,
  incompleteCount: lines.where((line) => !line.isFullyMarked).length,
);

AssetBytesLoader bundleAssetLoader(AssetBundle bundle) => (assetPath) async {
  final data = await bundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
};

final class VideoExportSettings {
  const VideoExportSettings({
    required this.subtitleFont,
    required this.subtitleFontSize,
    required this.loadAsset,
  });

  final SubtitleFontFace subtitleFont;
  final double subtitleFontSize;
  final AssetBytesLoader loadAsset;
}

VideoExportSettings buildVideoExportSettings(
  Project project,
  AssetBytesLoader loadAsset,
) => VideoExportSettings(
  subtitleFont: SubtitleFontCatalog.byId(project.subtitleFontFamily),
  subtitleFontSize: project.subtitleFontSize,
  loadAsset: loadAsset,
);

Future<void> runExportAction(
  String label,
  Future<void> Function() action,
  void Function(String message) showFailure,
) async {
  try {
    await action();
  } catch (error) {
    showFailure('$label failed: $error');
  }
}

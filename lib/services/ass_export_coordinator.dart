import 'ass_codec.dart';
import 'ass_export_service.dart';
import 'asset_bytes_loader.dart';
import '../models/subtitle_line.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';

typedef AssWarningConfirmation =
    Future<bool> Function(int invalidCount, int incompleteCount);
typedef AssCompanionReplacementConfirmation =
    Future<bool> Function(String companionPath);
typedef AssPackageExporter =
    Future<void> Function({
      required String outputPath,
      required String content,
      required SubtitleFontFace face,
      required AssetBytesLoader loadAsset,
    });

final class AssExportCoordinator {
  AssExportCoordinator({
    Future<bool> Function(String outputPath)? wouldReplaceCompanions,
    AssPackageExporter? exportPackage,
  }) : _wouldReplaceCompanions =
           wouldReplaceCompanions ??
           const AssExportService().wouldReplaceCompanions,
       _exportPackage = exportPackage ?? const AssExportService().export;

  final Future<bool> Function(String outputPath) _wouldReplaceCompanions;
  final AssPackageExporter _exportPackage;

  Future<bool> export({
    required String outputPath,
    required List<SubtitleLine> lines,
    required SubtitleFontFace face,
    required double fontSize,
    required AssetBytesLoader loadAsset,
    required AssWarningConfirmation confirmWarnings,
    required AssCompanionReplacementConfirmation confirmCompanionReplacement,
  }) async {
    final invalidCount = lines.where((line) => line.hasInvalidRange).length;
    final incompleteCount = lines.where((line) => !line.isFullyMarked).length;
    if ((invalidCount > 0 || incompleteCount > 0) &&
        !await confirmWarnings(invalidCount, incompleteCount)) {
      return false;
    }

    if (await _wouldReplaceCompanions(outputPath)) {
      final companionPath = AssExportService.companionDirectoryFor(outputPath);
      if (!await confirmCompanionReplacement(companionPath)) return false;
    }

    await _exportPackage(
      outputPath: outputPath,
      content: AssCodec.encode(
        lines,
        fontFamily: face.familyName,
        fontSize: fontSize,
      ),
      face: face,
      loadAsset: loadAsset,
    );
    return true;
  }
}

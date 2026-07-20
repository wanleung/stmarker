import '../models/subtitle_line.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';
import 'ass_codec.dart';
import 'ass_export_service.dart';
import 'asset_bytes_loader.dart';
import 'export_integration_support.dart';

typedef AssPathPicker =
    Future<String?> Function({required String defaultFileName});
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

enum AssExportResult { cancelled, exported }

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

  Future<AssExportResult> export({
    required AssPathPicker choosePath,
    required List<SubtitleLine> lines,
    required SubtitleFontFace face,
    required double fontSize,
    required AssetBytesLoader loadAsset,
    required bool Function() isActive,
    required AssWarningConfirmation confirmWarnings,
    required AssCompanionReplacementConfirmation confirmCompanionReplacement,
    required void Function(String message) showSuccess,
  }) async {
    if (!isActive()) return AssExportResult.cancelled;
    final warnings = exportWarnings(lines);
    if (!warnings.isEmpty) {
      if (!await confirmWarnings(
            warnings.invalidCount,
            warnings.incompleteCount,
          ) ||
          !isActive()) {
        return AssExportResult.cancelled;
      }
    }

    final outputPath = await choosePath(defaultFileName: 'export.ass');
    if (outputPath == null || !isActive()) return AssExportResult.cancelled;

    final replacesCompanions = await _wouldReplaceCompanions(outputPath);
    if (!isActive()) return AssExportResult.cancelled;
    if (replacesCompanions &&
        (!await confirmCompanionReplacement(
              AssExportService.companionDirectoryFor(outputPath),
            ) ||
            !isActive())) {
      return AssExportResult.cancelled;
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
    if (isActive()) showSuccess('ASS subtitles exported to $outputPath');
    return AssExportResult.exported;
  }
}

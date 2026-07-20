import '../karaoke/karaoke_models.dart';
import '../karaoke/karaoke_timing.dart';
import '../models/project.dart';
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

final class AssExportResult {
  const AssExportResult._(this._status, this.invalidLineNumbers);

  static const cancelled = AssExportResult._(_AssExportStatus.cancelled, []);
  static const exported = AssExportResult._(_AssExportStatus.exported, []);

  factory AssExportResult.invalidAdvanced(List<int> lineNumbers) =>
      AssExportResult._(
        _AssExportStatus.invalidAdvanced,
        List.unmodifiable(lineNumbers),
      );

  final _AssExportStatus _status;
  final List<int> invalidLineNumbers;

  bool get isCancelled => _status == _AssExportStatus.cancelled;
  bool get isExported => _status == _AssExportStatus.exported;
  bool get hasInvalidAdvancedTiming =>
      _status == _AssExportStatus.invalidAdvanced;
}

enum _AssExportStatus { cancelled, exported, invalidAdvanced }

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
    Project? project,
    required SubtitleFontFace face,
    required double fontSize,
    required AssetBytesLoader loadAsset,
    required bool Function() isActive,
    required AssWarningConfirmation confirmWarnings,
    required AssCompanionReplacementConfirmation confirmCompanionReplacement,
    required void Function(String message) showSuccess,
  }) async {
    if (!isActive()) return AssExportResult.cancelled;
    if (project?.karaokeMode == KaraokeMode.karaokeAdvanced) {
      final invalidLineNumbers = [
        for (final line in project!.lines)
          if (karaokeTimingIssue(line, project.karaokeMode) != null)
            line.index + 1,
      ];
      if (invalidLineNumbers.isNotEmpty) {
        return AssExportResult.invalidAdvanced(invalidLineNumbers);
      }
    }
    final warnings = exportWarnings(project?.lines ?? lines);
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
      content: project == null
          ? AssCodec.encode(
              lines,
              fontFamily: face.familyName,
              fontSize: fontSize,
            )
          : AssCodec.encodeProject(
              project,
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

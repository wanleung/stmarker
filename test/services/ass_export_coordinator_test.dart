import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/ass_export_coordinator.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

void main() {
  const face = SubtitleFontFace(
    id: 'serif',
    label: 'Serif',
    familyName: 'Chosen Serif',
    assetPath: 'assets/fonts/chosen.otf',
  );
  const lines = [
    SubtitleLine(index: 0, text: 'Hello', startMs: 0, endMs: 1000),
  ];

  test('cancellation at warnings makes no export writes', () async {
    var exported = false;
    final coordinator = AssExportCoordinator(
      wouldReplaceCompanions: (_) async => false,
      exportPackage:
          ({
            required outputPath,
            required content,
            required face,
            required loadAsset,
          }) async {
            exported = true;
          },
    );

    final result = await coordinator.export(
      outputPath: '/tmp/export.ass',
      lines: const [SubtitleLine(index: 0, text: 'Incomplete')],
      face: face,
      fontSize: 31,
      loadAsset: (_) async => Uint8List(0),
      confirmWarnings: (_, _) async => false,
      confirmCompanionReplacement: (_) async => true,
    );

    expect(result, isFalse);
    expect(exported, isFalse);
  });

  test('asks before replacing an existing companion directory', () async {
    var replacementPath = '';
    var exported = false;
    final coordinator = AssExportCoordinator(
      wouldReplaceCompanions: (_) async => true,
      exportPackage:
          ({
            required outputPath,
            required content,
            required face,
            required loadAsset,
          }) async {
            exported = true;
          },
    );

    final result = await coordinator.export(
      outputPath: '/tmp/export.ass',
      lines: lines,
      face: face,
      fontSize: 31,
      loadAsset: (_) async => Uint8List(0),
      confirmWarnings: (_, _) async => true,
      confirmCompanionReplacement: (path) async {
        replacementPath = path;
        return false;
      },
    );

    expect(result, isFalse);
    expect(replacementPath, '/tmp/export_fonts');
    expect(exported, isFalse);
  });

  test(
    'encodes selected style and passes face and loader to package export',
    () async {
      SubtitleFontFace? exportedFace;
      Future<Uint8List> Function(String)? exportedLoader;
      Future<Uint8List> loader(String _) async => Uint8List.fromList([1, 2, 3]);
      final coordinator = AssExportCoordinator(
        wouldReplaceCompanions: (_) async => false,
        exportPackage:
            ({
              required outputPath,
              required String content,
              required SubtitleFontFace face,
              required loadAsset,
            }) async {
              expect(outputPath, '/tmp/export.ass');
              exportedFace = face;
              exportedLoader = loadAsset;
              expect(content, contains('Style: Default,Chosen Serif,31,'));
            },
      );

      final result = await coordinator.export(
        outputPath: '/tmp/export.ass',
        lines: lines,
        face: face,
        fontSize: 31,
        loadAsset: loader,
        confirmWarnings: (_, _) async => true,
        confirmCompanionReplacement: (_) async => true,
      );

      expect(result, isTrue);
      expect(exportedFace, same(face));
      expect(exportedLoader, same(loader));
    },
  );
}

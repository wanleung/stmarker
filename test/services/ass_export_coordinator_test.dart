import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/ass_codec.dart';
import 'package:stmarker/services/ass_export_coordinator.dart';
import 'package:stmarker/services/asset_bytes_loader.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

void main() {
  const face = SubtitleFontFace(
    id: 'serif',
    label: 'Serif',
    familyName: 'Chosen Serif',
    assetPath: 'assets/fonts/chosen.otf',
  );
  const complete = [
    SubtitleLine(index: 0, text: 'Hello', startMs: 0, endMs: 1000),
  ];

  test('AssExportResult retains its original public enum shape', () {
    expect(AssExportResult.values, [
      AssExportResult.cancelled,
      AssExportResult.exported,
    ]);
    expect(AssExportResult.cancelled.name, 'cancelled');
    expect(AssExportResult.cancelled.index, 0);
    expect(AssExportResult.exported.name, 'exported');
    expect(AssExportResult.exported.index, 1);
    expect(_describeResult(AssExportResult.exported), 'exported');
  });

  test(
    'picker receives export.ass default and cancellation stops before warnings',
    () async {
      final events = <String>[];
      final result = await _coordinator(events).export(
        choosePath: ({required defaultFileName}) async {
          events.add('pick:$defaultFileName');
          return null;
        },
        lines: complete,
        face: face,
        fontSize: 31,
        loadAsset: _loader,
        isActive: () => true,
        confirmWarnings: (_, _) async {
          events.add('warnings');
          return true;
        },
        confirmCompanionReplacement: (_) async => true,
        showSuccess: (_) => events.add('success'),
      );
      expect(result, AssExportResult.cancelled);
      expect(events, ['pick:export.ass']);
    },
  );

  test(
    'warning cancel skips companion probe, asset loading, and writes',
    () async {
      final events = <String>[];
      var loaded = false;
      final coordinator = AssExportCoordinator(
        wouldReplaceCompanions: (_) async {
          events.add('probe');
          return false;
        },
        exportPackage:
            ({
              required outputPath,
              required content,
              required face,
              required loadAsset,
            }) async {
              events.add('write');
              await loadAsset(face.assetPath);
            },
      );
      final result = await coordinator.export(
        choosePath: ({required defaultFileName}) async {
          events.add('pick');
          return '/tmp/export.ass';
        },
        lines: const [SubtitleLine(index: 0, text: 'Incomplete')],
        face: face,
        fontSize: 31,
        loadAsset: (_) async {
          loaded = true;
          return Uint8List(0);
        },
        isActive: () => true,
        confirmWarnings: (invalid, incomplete) async {
          events.add('warnings:$invalid:$incomplete');
          return false;
        },
        confirmCompanionReplacement: (_) async => true,
        showSuccess: (_) => events.add('success'),
      );
      expect(result, AssExportResult.cancelled);
      expect(events, ['warnings:0:1']);
      expect(loaded, isFalse);
    },
  );

  test(
    'inactive after warning confirmation cannot probe or open companion dialog',
    () async {
      var active = true;
      final events = <String>[];
      final coordinator = AssExportCoordinator(
        wouldReplaceCompanions: (_) async {
          events.add('probe');
          return true;
        },
        exportPackage:
            ({
              required outputPath,
              required content,
              required face,
              required loadAsset,
            }) async {},
      );
      final result = await coordinator.export(
        choosePath: ({required defaultFileName}) async => '/tmp/export.ass',
        lines: const [SubtitleLine(index: 0, text: 'Incomplete')],
        face: face,
        fontSize: 31,
        loadAsset: _loader,
        isActive: () => active,
        confirmWarnings: (_, _) async {
          active = false;
          return true;
        },
        confirmCompanionReplacement: (_) async {
          events.add('companion');
          return true;
        },
        showSuccess: (_) => events.add('success'),
      );
      expect(result, AssExportResult.cancelled);
      expect(events, isEmpty);
    },
  );

  test(
    'companion cancellation follows picker, warnings, then probe order',
    () async {
      final events = <String>[];
      final coordinator = AssExportCoordinator(
        wouldReplaceCompanions: (_) async {
          events.add('probe');
          return true;
        },
        exportPackage:
            ({
              required outputPath,
              required content,
              required face,
              required loadAsset,
            }) async {
              events.add('write');
            },
      );
      final result = await coordinator.export(
        choosePath: ({required defaultFileName}) async {
          events.add('pick');
          return '/tmp/export.ass';
        },
        lines: const [
          SubtitleLine(index: 0, text: 'Bad', startMs: 2, endMs: 1),
        ],
        face: face,
        fontSize: 31,
        loadAsset: _loader,
        isActive: () => true,
        confirmWarnings: (invalid, incomplete) async {
          events.add('warnings:$invalid:$incomplete');
          return true;
        },
        confirmCompanionReplacement: (path) async {
          events.add('companion:$path');
          return false;
        },
        showSuccess: (_) => events.add('success'),
      );
      expect(result, AssExportResult.cancelled);
      expect(events, [
        'warnings:1:0',
        'pick',
        'probe',
        'companion:/tmp/export_fonts',
      ]);
    },
  );

  test('success propagates style, loader, and exact success message', () async {
    final events = <String>[];
    AssetBytesLoader? capturedLoader;
    final coordinator = AssExportCoordinator(
      wouldReplaceCompanions: (_) async => false,
      exportPackage:
          ({
            required outputPath,
            required content,
            required face,
            required loadAsset,
          }) async {
            expect(content, contains('Style: Default,Chosen Serif,31,'));
            capturedLoader = loadAsset;
          },
    );
    final result = await coordinator.export(
      choosePath: ({required defaultFileName}) async => '/tmp/export.ass',
      lines: complete,
      face: face,
      fontSize: 31,
      loadAsset: _loader,
      isActive: () => true,
      confirmWarnings: (_, _) async => true,
      confirmCompanionReplacement: (_) async => true,
      showSuccess: (message) => events.add(message),
    );
    expect(result, AssExportResult.exported);
    expect(capturedLoader, same(_loader));
    expect(events, ['ASS subtitles exported to /tmp/export.ass']);
  });

  test('package errors propagate and do not report success', () async {
    var success = false;
    final coordinator = AssExportCoordinator(
      wouldReplaceCompanions: (_) async => false,
      exportPackage:
          ({
            required outputPath,
            required content,
            required face,
            required loadAsset,
          }) async => throw StateError('disk'),
    );
    await expectLater(
      coordinator.export(
        choosePath: ({required defaultFileName}) async => '/tmp/export.ass',
        lines: complete,
        face: face,
        fontSize: 31,
        loadAsset: _loader,
        isActive: () => true,
        confirmWarnings: (_, _) async => true,
        confirmCompanionReplacement: (_) async => true,
        showSuccess: (_) => success = true,
      ),
      throwsStateError,
    );
    expect(success, isFalse);
  });

  test(
    'invalid Advanced timing returns exact lines and writes nothing',
    () async {
      final invalidLines = [
        const SubtitleLine(
          index: 4,
          text: 'missing marks',
          startMs: 0,
          endMs: 1000,
        ),
        SubtitleLine.withKaraokeMarks(
          index: 6,
          text: 'stale mark',
          startMs: 0,
          endMs: 1000,
          karaokeMarks: const [KaraokeMark(unitText: 'wrong', startMs: 0)],
        ),
        SubtitleLine.withKaraokeMarks(
          index: 8,
          text: 'bad marks',
          startMs: 0,
          endMs: 1000,
          karaokeMarks: const [
            KaraokeMark(unitText: 'bad', startMs: 0),
            KaraokeMark(unitText: 'marks', startMs: 0),
          ],
        ),
      ];
      final events = <String>[];

      await expectLater(
        _coordinator(events).export(
          choosePath: ({required defaultFileName}) async {
            events.add('pick');
            return '/tmp/export.ass';
          },
          lines: invalidLines,
          project: Project(
            mediaPath: '/tmp/media.mp4',
            karaokeMode: KaraokeMode.karaokeAdvanced,
            lines: invalidLines,
          ),
          face: face,
          fontSize: 31,
          loadAsset: _loader,
          isActive: () => true,
          confirmWarnings: (_, _) async => true,
          confirmCompanionReplacement: (_) async => true,
          showSuccess: (_) => events.add('success'),
        ),
        throwsA(
          isA<AssKaraokeValidationException>().having(
            (error) => error.lineNumbers,
            'lineNumbers',
            [5, 7, 9],
          ),
        ),
      );
      expect(events, isEmpty);
    },
  );

  test(
    'invalid Easy timing and allocation return exact lines before side effects',
    () async {
      final events = <String>[];
      const lines = [
        SubtitleLine(index: 1, text: 'a b c', startMs: 0, endMs: 2),
        SubtitleLine(index: 2, text: 'a b c d', startMs: 0, endMs: 24),
      ];

      await expectLater(
        _coordinator(events).export(
          choosePath: ({required defaultFileName}) async {
            events.add('pick');
            return '/tmp/export.ass';
          },
          lines: lines,
          project: const Project(
            mediaPath: '/tmp/media.mp4',
            karaokeMode: KaraokeMode.karaokeEasy,
            lines: lines,
          ),
          face: face,
          fontSize: 31,
          loadAsset: _loader,
          isActive: () => true,
          confirmWarnings: (_, _) async {
            events.add('warnings');
            return true;
          },
          confirmCompanionReplacement: (_) async {
            events.add('companion');
            return true;
          },
          showSuccess: (_) => events.add('success'),
        ),
        throwsA(
          isA<AssKaraokeValidationException>().having(
            (error) => error.lineNumbers,
            'lineNumbers',
            [2, 3],
          ),
        ),
      );
      expect(events, isEmpty);
    },
  );
}

String _describeResult(AssExportResult result) => switch (result) {
  AssExportResult.cancelled => 'cancelled',
  AssExportResult.exported => 'exported',
};

Future<Uint8List> _loader(String _) async => Uint8List.fromList([1, 2, 3]);

AssExportCoordinator _coordinator(List<String> events) => AssExportCoordinator(
  wouldReplaceCompanions: (_) async {
    events.add('probe');
    return false;
  },
  exportPackage:
      ({
        required outputPath,
        required content,
        required face,
        required loadAsset,
      }) async {
        events.add('write');
      },
);

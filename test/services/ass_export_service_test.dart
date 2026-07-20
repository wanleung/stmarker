import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/services/ass_export_service.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

void main() {
  const face = SubtitleFontFace(
    id: 'test',
    label: 'Test',
    familyName: 'Test Font',
    assetPath: 'assets/fonts/TestFont.otf',
  );
  final fontBytes = Uint8List.fromList(<int>[0, 1, 2, 127, 255]);
  final licenceBytes = Uint8List.fromList(<int>[79, 70, 76]);

  late Directory temporaryDirectory;
  late String outputPath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ass_export_service_test_',
    );
    outputPath = '${temporaryDirectory.path}/name.ass';
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<Uint8List> loadAsset(String path) async {
    return switch (path) {
      'assets/fonts/TestFont.otf' => fontBytes,
      'assets/fonts/OFL.txt' => licenceBytes,
      _ => throw StateError('Unexpected asset: $path'),
    };
  }

  test(
    'exports ASS, selected font, and licence with identical bytes',
    () async {
      await const AssExportService().export(
        outputPath: outputPath,
        content: 'ASS content 字幕',
        face: face,
        loadAsset: loadAsset,
      );

      expect(await File(outputPath).readAsString(), 'ASS content 字幕');
      final companion = Directory('${temporaryDirectory.path}/name_fonts');
      expect(
        await File('${companion.path}/TestFont.otf').readAsBytes(),
        fontBytes,
      );
      expect(
        await File('${companion.path}/OFL.txt').readAsBytes(),
        licenceBytes,
      );
    },
  );

  test('derives companion directory from the final extension', () {
    expect(
      AssExportService.companionDirectoryFor('/tmp/sub.title.ass'),
      '/tmp/sub.title_fonts',
    );
    expect(
      AssExportService.companionDirectoryFor('/tmp/subtitle'),
      '/tmp/subtitle_fonts',
    );
  });

  test('reports whether export would replace companion files', () async {
    const service = AssExportService();
    expect(await service.wouldReplaceCompanions(outputPath), isFalse);

    await Directory('${temporaryDirectory.path}/name_fonts').create();

    expect(await service.wouldReplaceCompanions(outputPath), isTrue);
  });

  test(
    'loader failure preserves an existing package and leaves no siblings',
    () async {
      await _writeOldPackage(outputPath);

      await expectLater(
        const AssExportService().export(
          outputPath: outputPath,
          content: 'new ASS',
          face: face,
          loadAsset: (path) async => throw StateError('load failed'),
        ),
        throwsStateError,
      );

      await _expectOldPackageAndNoGeneratedSiblings(outputPath);
    },
  );

  test('staged write failure preserves an existing package', () async {
    await _writeOldPackage(outputPath);
    final fileSystem = _FaultFileSystem(
      failWhen: (operation, path) =>
          operation == 'writeBytes' && path.endsWith('/OFL.txt'),
    );

    await expectLater(
      AssExportService(fileSystem: fileSystem).export(
        outputPath: outputPath,
        content: 'new ASS',
        face: face,
        loadAsset: loadAsset,
      ),
      throwsA(isA<FileSystemException>()),
    );

    await _expectOldPackageAndNoGeneratedSiblings(outputPath);
  });

  test(
    'failure cleanup leaves unrelated similarly named siblings untouched',
    () async {
      await _writeOldPackage(outputPath);
      final unrelated = File(
        '${temporaryDirectory.path}/unrelated.ass-export-stage-keep',
      );
      await unrelated.writeAsString('keep me');
      final fileSystem = _FaultFileSystem(
        failWhen: (operation, path) =>
            operation == 'writeBytes' && path.endsWith('/OFL.txt'),
      );

      await expectLater(
        AssExportService(fileSystem: fileSystem).export(
          outputPath: outputPath,
          content: 'new ASS',
          face: face,
          loadAsset: loadAsset,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await File(outputPath).readAsString(), 'old ASS');
      expect(await unrelated.readAsString(), 'keep me');
      final generatedForDestination = await temporaryDirectory
          .list()
          .where(
            (entity) =>
                entity.path.contains('name.ass-export-stage-') ||
                entity.path.contains('name.ass-export-backup-') ||
                entity.path.contains('name_fonts.ass-export-stage-') ||
                entity.path.contains('name_fonts.ass-export-backup-'),
          )
          .toList();
      expect(generatedForDestination, isEmpty);
    },
  );

  for (final failure in <({String name, bool Function(String, String) when})>[
    (
      name: 'ASS backup rename',
      when: (operation, path) =>
          operation == 'renameFile' && path == outputPath,
    ),
    (
      name: 'companion backup rename',
      when: (operation, path) =>
          operation == 'renameDirectory' &&
          path == AssExportService.companionDirectoryFor(outputPath),
    ),
    (
      name: 'staged ASS install rename',
      when: (operation, path) =>
          operation == 'renameFile' && path.contains('.ass-export-stage-'),
    ),
    (
      name: 'staged companion install rename',
      when: (operation, path) =>
          operation == 'renameDirectory' && path.contains('.ass-export-stage-'),
    ),
  ]) {
    test('${failure.name} preserves an existing package', () async {
      await _writeOldPackage(outputPath);
      final fileSystem = _FaultFileSystem(failWhen: failure.when);

      await expectLater(
        AssExportService(fileSystem: fileSystem).export(
          outputPath: outputPath,
          content: 'new ASS',
          face: face,
          loadAsset: loadAsset,
        ),
        throwsA(isA<FileSystemException>()),
      );

      await _expectOldPackageAndNoGeneratedSiblings(outputPath);
    });
  }
}

Future<void> _writeOldPackage(String outputPath) async {
  await File(outputPath).writeAsString('old ASS');
  final companion = Directory(
    AssExportService.companionDirectoryFor(outputPath),
  );
  await companion.create();
  await File('${companion.path}/old-font.otf').writeAsBytes(<int>[9, 8, 7]);
  await File('${companion.path}/OFL.txt').writeAsString('old licence');
}

Future<void> _expectOldPackageAndNoGeneratedSiblings(String outputPath) async {
  expect(await File(outputPath).readAsString(), 'old ASS');
  final companionPath = AssExportService.companionDirectoryFor(outputPath);
  expect(await File('$companionPath/old-font.otf').readAsBytes(), <int>[
    9,
    8,
    7,
  ]);
  expect(await File('$companionPath/OFL.txt').readAsString(), 'old licence');

  final parent = Directory(outputPath).parent;
  final generated = await parent
      .list()
      .where(
        (entity) =>
            entity.path.contains('.ass-export-stage-') ||
            entity.path.contains('.ass-export-backup-'),
      )
      .toList();
  expect(generated, isEmpty);
}

final class _FaultFileSystem extends LocalAssExportFileSystem {
  _FaultFileSystem({required this.failWhen});

  final bool Function(String operation, String path) failWhen;
  final Set<String> _failedOperations = <String>{};

  void _maybeFail(String operation, String path) {
    final key = '$operation:$path';
    if (failWhen(operation, path) && _failedOperations.add(key)) {
      throw FileSystemException('Injected $operation failure', path);
    }
  }

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    _maybeFail('writeBytes', path);
    await super.writeBytes(path, bytes);
  }

  @override
  Future<void> renameFile(String path, String newPath) async {
    _maybeFail('renameFile', path);
    await super.renameFile(path, newPath);
  }

  @override
  Future<void> renameDirectory(String path, String newPath) async {
    _maybeFail('renameDirectory', path);
    await super.renameDirectory(path, newPath);
  }
}

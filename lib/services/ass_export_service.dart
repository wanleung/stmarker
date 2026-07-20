import 'dart:convert';
import 'dart:io';

import '../subtitle_fonts/subtitle_font_catalog.dart';
import 'asset_bytes_loader.dart';

abstract interface class AssExportFileSystem {
  Future<bool> fileExists(String path);

  Future<bool> directoryExists(String path);

  Future<void> createDirectory(String path, {bool recursive = false});

  Future<void> writeBytes(String path, List<int> bytes);

  Future<void> renameFile(String path, String newPath);

  Future<void> renameDirectory(String path, String newPath);

  Future<void> deleteFile(String path);

  Future<void> deleteDirectory(String path, {bool recursive = false});
}

class LocalAssExportFileSystem implements AssExportFileSystem {
  const LocalAssExportFileSystem();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    await Directory(path).create(recursive: recursive);
  }

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> renameFile(String path, String newPath) async {
    await File(path).rename(newPath);
  }

  @override
  Future<void> renameDirectory(String path, String newPath) async {
    await Directory(path).rename(newPath);
  }

  @override
  Future<void> deleteFile(String path) async {
    await File(path).delete();
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    await Directory(path).delete(recursive: recursive);
  }
}

final class AssExportService {
  const AssExportService({this.fileSystem = const LocalAssExportFileSystem()});

  final AssExportFileSystem fileSystem;

  static int _uniqueSequence = 0;

  static String companionDirectoryFor(String outputPath) {
    final separatorIndex = _lastSeparatorIndex(outputPath);
    final extensionIndex = outputPath.lastIndexOf('.');
    final stem = extensionIndex > separatorIndex
        ? outputPath.substring(0, extensionIndex)
        : outputPath;
    return '${stem}_fonts';
  }

  Future<bool> wouldReplaceCompanions(String outputPath) {
    return fileSystem.directoryExists(companionDirectoryFor(outputPath));
  }

  Future<void> export({
    required String outputPath,
    required String content,
    required SubtitleFontFace face,
    required AssetBytesLoader loadAsset,
  }) async {
    final fontBytes = await loadAsset(face.assetPath);
    final licenceBytes = await loadAsset('assets/fonts/OFL.txt');

    final companionPath = companionDirectoryFor(outputPath);
    final parentPath = _parentOf(outputPath);
    await fileSystem.createDirectory(parentPath, recursive: true);

    final token = await _uniqueToken(outputPath, companionPath);
    final stagedOutputPath = '$outputPath.ass-export-stage-$token';
    final stagedCompanionPath = '$companionPath.ass-export-stage-$token';
    final backupOutputPath = '$outputPath.ass-export-backup-$token';
    final backupCompanionPath = '$companionPath.ass-export-backup-$token';

    var outputBackedUp = false;
    var companionBackedUp = false;
    var outputInstalled = false;
    var companionInstalled = false;

    try {
      await fileSystem.createDirectory(stagedCompanionPath);
      await fileSystem.writeBytes(stagedOutputPath, utf8.encode(content));
      await fileSystem.writeBytes(
        '$stagedCompanionPath/${_basename(face.assetPath)}',
        fontBytes,
      );
      await fileSystem.writeBytes('$stagedCompanionPath/OFL.txt', licenceBytes);

      if (await fileSystem.fileExists(outputPath)) {
        await fileSystem.renameFile(outputPath, backupOutputPath);
        outputBackedUp = true;
      }
      if (await fileSystem.directoryExists(companionPath)) {
        await fileSystem.renameDirectory(companionPath, backupCompanionPath);
        companionBackedUp = true;
      }

      await fileSystem.renameFile(stagedOutputPath, outputPath);
      outputInstalled = true;
      await fileSystem.renameDirectory(stagedCompanionPath, companionPath);
      companionInstalled = true;
    } catch (error, stackTrace) {
      await _rollback(
        outputPath: outputPath,
        companionPath: companionPath,
        backupOutputPath: backupOutputPath,
        backupCompanionPath: backupCompanionPath,
        outputBackedUp: outputBackedUp,
        companionBackedUp: companionBackedUp,
        outputInstalled: outputInstalled,
        companionInstalled: companionInstalled,
      );
      await _deleteFileIfPresent(stagedOutputPath);
      await _deleteDirectoryIfPresent(stagedCompanionPath);
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (outputBackedUp) {
      await fileSystem.deleteFile(backupOutputPath);
    }
    if (companionBackedUp) {
      await fileSystem.deleteDirectory(backupCompanionPath, recursive: true);
    }
  }

  Future<void> _rollback({
    required String outputPath,
    required String companionPath,
    required String backupOutputPath,
    required String backupCompanionPath,
    required bool outputBackedUp,
    required bool companionBackedUp,
    required bool outputInstalled,
    required bool companionInstalled,
  }) async {
    if (companionInstalled) {
      await _deleteDirectoryIfPresent(companionPath);
    }
    if (outputInstalled) {
      await _deleteFileIfPresent(outputPath);
    }
    if (outputBackedUp) {
      await fileSystem.renameFile(backupOutputPath, outputPath);
    }
    if (companionBackedUp) {
      await fileSystem.renameDirectory(backupCompanionPath, companionPath);
    }
  }

  Future<String> _uniqueToken(String outputPath, String companionPath) async {
    while (true) {
      final token =
          '${DateTime.now().microsecondsSinceEpoch}-${_uniqueSequence++}';
      final candidates = <String>[
        '$outputPath.ass-export-stage-$token',
        '$companionPath.ass-export-stage-$token',
        '$outputPath.ass-export-backup-$token',
        '$companionPath.ass-export-backup-$token',
      ];
      var collision = false;
      for (final path in candidates) {
        if (await fileSystem.fileExists(path) ||
            await fileSystem.directoryExists(path)) {
          collision = true;
          break;
        }
      }
      if (!collision) {
        return token;
      }
    }
  }

  Future<void> _deleteFileIfPresent(String path) async {
    if (await fileSystem.fileExists(path)) {
      await fileSystem.deleteFile(path);
    }
  }

  Future<void> _deleteDirectoryIfPresent(String path) async {
    if (await fileSystem.directoryExists(path)) {
      await fileSystem.deleteDirectory(path, recursive: true);
    }
  }

  static String _basename(String path) {
    final index = _lastSeparatorIndex(path);
    return path.substring(index + 1);
  }

  static String _parentOf(String path) {
    final index = _lastSeparatorIndex(path);
    if (index < 0) {
      return '.';
    }
    if (index == 0) {
      return path.substring(0, 1);
    }
    return path.substring(0, index);
  }

  static int _lastSeparatorIndex(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf(r'\');
    return slash > backslash ? slash : backslash;
  }
}

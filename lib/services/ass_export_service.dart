import 'dart:convert';
import 'dart:io';

import '../subtitle_fonts/subtitle_font_catalog.dart';
import 'asset_bytes_loader.dart';

abstract interface class AssExportFileSystem {
  Future<bool> fileExists(String path);

  Future<bool> directoryExists(String path);

  Future<void> createDirectory(String path, {bool recursive = false});

  Future<String> createTemporaryDirectory(String parentPath, String prefix);

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
  Future<String> createTemporaryDirectory(
    String parentPath,
    String prefix,
  ) async {
    final directory = await Directory(parentPath).createTemp(prefix);
    return directory.path;
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
    final transactionPath = await fileSystem.createTemporaryDirectory(
      parentPath,
      '.ass-export-txn-',
    );
    final stagedOutputPath = '$transactionPath/staged.ass';
    final stagedCompanionPath = '$transactionPath/staged_fonts';
    final backupOutputPath = '$transactionPath/backup.ass';
    final backupCompanionPath = '$transactionPath/backup_fonts';

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
        transactionPath: transactionPath,
        outputPath: outputPath,
        companionPath: companionPath,
        backupOutputPath: backupOutputPath,
        backupCompanionPath: backupCompanionPath,
        outputBackedUp: outputBackedUp,
        companionBackedUp: companionBackedUp,
        outputInstalled: outputInstalled,
        companionInstalled: companionInstalled,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }

    await _bestEffort(
      () => fileSystem.deleteDirectory(transactionPath, recursive: true),
    );
  }

  Future<void> _rollback({
    required String transactionPath,
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
      await _bestEffort(() => _deleteDirectoryIfPresent(companionPath));
    }
    if (outputInstalled) {
      await _bestEffort(() => _deleteFileIfPresent(outputPath));
    }
    if (outputBackedUp) {
      await _bestEffort(
        () => fileSystem.renameFile(backupOutputPath, outputPath),
      );
    }
    if (companionBackedUp) {
      await _bestEffort(
        () => fileSystem.renameDirectory(backupCompanionPath, companionPath),
      );
    }

    var hasRecoverableBackup = true;
    try {
      hasRecoverableBackup =
          await fileSystem.fileExists(backupOutputPath) ||
          await fileSystem.directoryExists(backupCompanionPath);
    } catch (_) {
      // Keep the transaction directory when backup ownership is uncertain.
    }
    if (!hasRecoverableBackup) {
      await _bestEffort(
        () => fileSystem.deleteDirectory(transactionPath, recursive: true),
      );
    }
  }

  static Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Continue so independent rollback steps still have a chance to run.
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

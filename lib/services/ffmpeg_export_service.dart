import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../karaoke/karaoke_models.dart';
import '../models/project.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';
import 'ass_codec.dart';
import 'asset_bytes_loader.dart';

enum SubtitleVideoMode { embedded, burnedIn }

class FfmpegExportException implements Exception {
  const FfmpegExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class FfmpegProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool kill(ProcessSignal signal);
}

typedef FfmpegProcessStarter =
    Future<FfmpegProcess> Function(String executable, List<String> arguments);

final class _SystemFfmpegProcess implements FfmpegProcess {
  const _SystemFfmpegProcess(this.process);

  final Process process;

  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  bool kill(ProcessSignal signal) => process.kill(signal);
}

Future<FfmpegProcess> _startSystemProcess(
  String executable,
  List<String> arguments,
) async => _SystemFfmpegProcess(await Process.start(executable, arguments));

class FfmpegExportService {
  FfmpegExportService({FfmpegProcessStarter? startProcess})
    : _startProcess = startProcess ?? _startSystemProcess;

  final FfmpegProcessStarter _startProcess;
  FfmpegProcess? _process;
  bool _active = false;
  bool _cancelRequested = false;

  bool get isRunning => _active;

  Future<bool> isAvailable() async {
    try {
      final result = await Process.run('ffmpeg', const ['-version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<void> export({
    required String inputPath,
    required String outputPath,
    required String subtitleContent,
    required SubtitleVideoMode mode,
    required int durationMs,
    required SubtitleFontFace subtitleFont,
    required double subtitleFontSize,
    required AssetBytesLoader loadAsset,
    required Project project,
    void Function(double progress)? onProgress,
  }) async {
    if (isRunning) {
      throw const FfmpegExportException('An FFmpeg export is already running.');
    }
    if (_samePath(inputPath, outputPath)) {
      throw const FfmpegExportException(
        'The output file cannot overwrite the source video.',
      );
    }

    _active = true;
    _cancelRequested = false;
    Directory? tempDirectory;
    final stderrTail = <String>[];
    try {
      tempDirectory = await Directory.systemTemp.createTemp('stmarker_ffmpeg_');
      _throwIfCancelled();
      final karaokeBurnedIn =
          mode == SubtitleVideoMode.burnedIn &&
          project.karaokeMode != KaraokeMode.standard;
      final subtitleFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}'
        'subtitles.${karaokeBurnedIn ? 'ass' : 'srt'}',
      );
      await subtitleFile.writeAsString(
        karaokeBurnedIn
            ? AssCodec.encodeProject(
                project,
                fontFamily: subtitleFont.familyName,
                fontSize: subtitleFontSize,
              )
            : subtitleContent,
      );
      _throwIfCancelled();
      if (mode == SubtitleVideoMode.burnedIn) {
        final fontBytes = await loadAsset(subtitleFont.assetPath);
        _throwIfCancelled();
        await File(
          '${tempDirectory.path}${Platform.pathSeparator}${_basename(subtitleFont.assetPath)}',
        ).writeAsBytes(fontBytes, flush: true);
        _throwIfCancelled();
        final licenceBytes = await loadAsset('assets/fonts/OFL.txt');
        _throwIfCancelled();
        await File(
          '${tempDirectory.path}${Platform.pathSeparator}OFL.txt',
        ).writeAsBytes(licenceBytes, flush: true);
        _throwIfCancelled();
      }
      final arguments = buildArguments(
        inputPath: inputPath,
        subtitlePath: subtitleFile.path,
        outputPath: outputPath,
        mode: mode,
        fontsDirectory: mode == SubtitleVideoMode.burnedIn
            ? tempDirectory.path
            : null,
        fontFamily: mode == SubtitleVideoMode.burnedIn
            ? subtitleFont.familyName
            : null,
        fontSize: mode == SubtitleVideoMode.burnedIn ? subtitleFontSize : null,
        assSubtitles: karaokeBurnedIn,
      );
      final process = await _startProcess('ffmpeg', arguments);
      _process = process;

      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderrTail.add(line);
            if (stderrTail.length > 12) stderrTail.removeAt(0);
            final positionMs = parseProgressMs(line);
            if (positionMs != null && durationMs > 0) {
              onProgress?.call((positionMs / durationMs).clamp(0.0, 1.0));
            }
          })
          .asFuture<void>();
      final stdoutDone = process.stdout.drain<void>();
      if (_cancelRequested) {
        process.kill(
          Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigint,
        );
      }
      await stdoutDone;
      final exitCode = await process.exitCode;
      await stderrDone;

      if (_cancelRequested) {
        throw const FfmpegExportException('Video export was cancelled.');
      }
      if (exitCode != 0) {
        final detail = stderrTail.isEmpty
            ? 'FFmpeg exited with code $exitCode.'
            : stderrTail.join('\n');
        throw FfmpegExportException(detail);
      }
      onProgress?.call(1.0);
    } on ProcessException catch (error) {
      throw FfmpegExportException('Unable to start FFmpeg: ${error.message}');
    } finally {
      _process = null;
      try {
        if (tempDirectory != null) {
          await tempDirectory.delete(recursive: true);
        }
      } finally {
        _active = false;
      }
    }
  }

  void cancel() {
    _cancelRequested = true;
    _process?.kill(
      Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigint,
    );
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const FfmpegExportException('Video export was cancelled.');
    }
  }

  static List<String> buildArguments({
    required String inputPath,
    required String subtitlePath,
    required String outputPath,
    required SubtitleVideoMode mode,
    String? fontsDirectory,
    String? fontFamily,
    double? fontSize,
    bool assSubtitles = false,
  }) {
    if (mode == SubtitleVideoMode.burnedIn) {
      if (fontsDirectory == null || fontFamily == null || fontSize == null) {
        throw ArgumentError(
          'Burned-in subtitles require a font directory, family, and size.',
        );
      }
      final style =
          'FontName=$fontFamily,FontSize=${_formatFontSize(fontSize)}';
      final filter = assSubtitles
          ? 'ass=${escapeFilterPath(subtitlePath)}'
                ':fontsdir=${escapeFilterValue(fontsDirectory)}'
          : 'subtitles=filename=${escapeFilterPath(subtitlePath)}'
                ':fontsdir=${escapeFilterValue(fontsDirectory)}'
                ':force_style=${escapeFilterValue(style)}';
      return [
        '-hide_banner',
        '-y',
        '-i',
        inputPath,
        '-vf',
        filter,
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-c:a',
        'copy',
        outputPath,
      ];
    }

    final extension = outputPath.toLowerCase().split('.').last;
    final subtitleCodec = {'mp4', 'm4v', 'mov'}.contains(extension)
        ? 'mov_text'
        : 'srt';
    return [
      '-hide_banner',
      '-y',
      '-i',
      inputPath,
      '-i',
      subtitlePath,
      '-map',
      '0:v?',
      '-map',
      '0:a?',
      '-map',
      '1:0',
      '-c:v',
      'copy',
      '-c:a',
      'copy',
      '-c:s',
      subtitleCodec,
      '-metadata:s:s:0',
      'language=eng',
      outputPath,
    ];
  }

  static String escapeFilterPath(String path) => escapeFilterValue(path);

  static String escapeFilterValue(String value) =>
      _escapeOnce(_escapeOnce(value));

  static String _escapeOnce(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll(',', r'\,')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');

  static String _formatFontSize(double size) =>
      size == size.roundToDouble() ? size.toInt().toString() : size.toString();

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  static int? parseProgressMs(String ffmpegLine) {
    final match = RegExp(
      r'time=(\d+):(\d{2}):(\d{2})(?:\.(\d+))?',
    ).firstMatch(ffmpegLine);
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final fraction = (match.group(4) ?? '').padRight(3, '0').substring(0, 3);
    return ((hours * 60 + minutes) * 60 + seconds) * 1000 +
        (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  static bool _samePath(String first, String second) =>
      File(first).absolute.path == File(second).absolute.path;
}

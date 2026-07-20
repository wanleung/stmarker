import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum SubtitleVideoMode { embedded, burnedIn }

class FfmpegExportException implements Exception {
  const FfmpegExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FfmpegExportService {
  Process? _process;
  bool _cancelRequested = false;

  bool get isRunning => _process != null;

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

    _cancelRequested = false;
    final tempDirectory = await Directory.systemTemp.createTemp(
      'stmarker_ffmpeg_',
    );
    final subtitleFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}subtitles.srt',
    );
    await subtitleFile.writeAsString(subtitleContent);

    final stderrTail = <String>[];
    try {
      final arguments = buildArguments(
        inputPath: inputPath,
        subtitlePath: subtitleFile.path,
        outputPath: outputPath,
        mode: mode,
      );
      final process = await Process.start('ffmpeg', arguments);
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
      await process.stdout.drain<void>();
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
      await tempDirectory.delete(recursive: true);
    }
  }

  void cancel() {
    _cancelRequested = true;
    _process?.kill(
      Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigint,
    );
  }

  static List<String> buildArguments({
    required String inputPath,
    required String subtitlePath,
    required String outputPath,
    required SubtitleVideoMode mode,
  }) {
    if (mode == SubtitleVideoMode.burnedIn) {
      return [
        '-hide_banner',
        '-y',
        '-i',
        inputPath,
        '-vf',
        "subtitles=filename='${escapeFilterPath(subtitlePath)}'",
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

  static String escapeFilterPath(String path) => path
      .replaceAll(r'\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll(',', r'\,')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');

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

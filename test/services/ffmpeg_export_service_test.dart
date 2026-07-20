import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/services/ffmpeg_export_service.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

const _face = SubtitleFontFace(
  id: 'test',
  label: 'Test',
  familyName: r"Test: Family, O'Brien\Bold",
  assetPath: 'assets/fonts/Test.otf',
);

void main() {
  test('embedded MP4 arguments remain unchanged', () {
    final arguments = FfmpegExportService.buildArguments(
      inputPath: '/videos/input file.mp4',
      subtitlePath: '/tmp/subtitles.srt',
      outputPath: '/videos/output file.mp4',
      mode: SubtitleVideoMode.embedded,
    );

    expect(arguments, [
      '-hide_banner',
      '-y',
      '-i',
      '/videos/input file.mp4',
      '-i',
      '/tmp/subtitles.srt',
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
      'mov_text',
      '-metadata:s:s:0',
      'language=eng',
      '/videos/output file.mp4',
    ]);
  });

  test('embedded MKV export uses an SRT subtitle stream', () {
    final arguments = FfmpegExportService.buildArguments(
      inputPath: 'input.mkv',
      subtitlePath: 'subtitles.srt',
      outputPath: 'output.mkv',
      mode: SubtitleVideoMode.embedded,
    );
    expect(arguments, containsAllInOrder(['-c:s', 'srt']));
  });

  test('burn-in filter safely escapes fontsdir and force style', () {
    final arguments = FfmpegExportService.buildArguments(
      inputPath: 'input.mp4',
      subtitlePath: r"C:\tmp,a'b\subtitles.srt",
      outputPath: 'output.mp4',
      mode: SubtitleVideoMode.burnedIn,
      fontsDirectory: r"C:\fonts,a'b",
      fontFamily: _face.familyName,
      fontSize: 31.5,
    );

    expect(
      arguments[arguments.indexOf('-vf') + 1],
      r"subtitles=filename=C\\\:\\\\tmp\\\,a\\\'b\\\\subtitles.srt:fontsdir=C\\\:\\\\fonts\\\,a\\\'b:force_style=FontName=Test\\\: Family\\\, O\\\'Brien\\\\Bold\\\,FontSize=31.5",
    );
  });

  test(
    'FFmpeg parses special subtitle path, fonts path, and font family',
    () async {
      final root = await Directory.systemTemp.createTemp('stmarker-parser-');
      try {
        final specialDirectory = Directory(
          '${root.path}${Platform.pathSeparator}fonts,a\'b\\c:dir',
        );
        await specialDirectory.create();
        final subtitleFile = File(
          '${root.path}${Platform.pathSeparator}sub,a\'b\\c:s.srt',
        );
        await subtitleFile.writeAsString(
          '1\n00:00:00,000 --> 00:00:00,500\nParser test\n',
        );
        final fontFile = File('assets/fonts/NotoSansCJKsc-Regular.otf');
        await fontFile.copy(
          '${specialDirectory.path}${Platform.pathSeparator}font.otf',
        );

        final arguments = FfmpegExportService.buildArguments(
          inputPath: 'unused',
          subtitlePath: subtitleFile.path,
          outputPath: 'unused',
          mode: SubtitleVideoMode.burnedIn,
          fontsDirectory: specialDirectory.path,
          fontFamily: r"Special: Family, O'Brien\Bold",
          fontSize: 24,
        );
        final filter = arguments[arguments.indexOf('-vf') + 1];
        final process = await Process.start('ffmpeg', [
          '-v',
          'debug',
          '-f',
          'lavfi',
          '-i',
          'color=size=32x32:duration=0.1',
          '-vf',
          filter,
          '-frames:v',
          '1',
          '-f',
          'null',
          '-',
        ]);
        final stderr = process.stderr
            .transform(const SystemEncoding().decoder)
            .join();
        final stdout = process.stdout.drain<void>();
        int exitCode;
        try {
          exitCode = await process.exitCode.timeout(
            const Duration(seconds: 10),
          );
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
          fail('FFmpeg parser integration test exceeded 10 seconds.');
        }
        await stdout;
        final stderrText = await stderr;
        expect(exitCode, 0, reason: '$stderrText\nFilter: $filter');
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: !_ffmpegAvailable,
  );

  test('embedded export never loads font bytes', () async {
    final process = _FakeProcess(exitCode: 0);
    var loads = 0;
    final service = FfmpegExportService(startProcess: (_, _) async => process);
    await service.export(
      inputPath: 'input.mp4',
      outputPath: 'output.mp4',
      subtitleContent: 'srt',
      mode: SubtitleVideoMode.embedded,
      durationMs: 1,
      subtitleFont: _face,
      subtitleFontSize: 30,
      loadAsset: (_) async {
        loads++;
        return Uint8List(0);
      },
    );
    expect(loads, 0);
  });

  for (final outcome in ['success', 'nonzero', 'start failure']) {
    test('burned-in temporary assets are removed after $outcome', () async {
      String? temporaryPath;
      final service = FfmpegExportService(
        startProcess: (_, arguments) async {
          final filter = arguments[arguments.indexOf('-vf') + 1];
          temporaryPath = _extractFontsDirectory(filter);
          expect(await File('$temporaryPath/Test.otf').readAsBytes(), [1, 2]);
          expect(await File('$temporaryPath/OFL.txt').readAsBytes(), [3]);
          if (outcome == 'start failure') {
            throw const ProcessException('ffmpeg', <String>[]);
          }
          return _FakeProcess(exitCode: outcome == 'success' ? 0 : 2);
        },
      );
      final future = service.export(
        inputPath: 'input.mp4',
        outputPath: 'output.mp4',
        subtitleContent: 'srt',
        mode: SubtitleVideoMode.burnedIn,
        durationMs: 1,
        subtitleFont: _face,
        subtitleFontSize: 30,
        loadAsset: (path) async =>
            Uint8List.fromList(path.endsWith('OFL.txt') ? [3] : [1, 2]),
      );
      if (outcome == 'success') {
        await future;
      } else {
        await expectLater(future, throwsA(isA<FfmpegExportException>()));
      }
      expect(temporaryPath, isNotNull);
      expect(await Directory(temporaryPath!).exists(), isFalse);
    });
  }

  test('burned-in temporary assets are removed after cancellation', () async {
    String? temporaryPath;
    final process = _FakeProcess.pending();
    final started = Completer<void>();
    final service = FfmpegExportService(
      startProcess: (_, arguments) async {
        final filter = arguments[arguments.indexOf('-vf') + 1];
        temporaryPath = _extractFontsDirectory(filter);
        started.complete();
        return process;
      },
    );
    final future = service.export(
      inputPath: 'input.mp4',
      outputPath: 'output.mp4',
      subtitleContent: 'srt',
      mode: SubtitleVideoMode.burnedIn,
      durationMs: 1,
      subtitleFont: _face,
      subtitleFontSize: 30,
      loadAsset: (_) async => Uint8List(0),
    );
    await started.future;
    await Future<void>.delayed(Duration.zero);
    expect(service.isRunning, isTrue);
    service.cancel();
    await expectLater(future, throwsA(isA<FfmpegExportException>()));
    expect(process.killed, isTrue);
    expect(await Directory(temporaryPath!).exists(), isFalse);
  });

  test('parses FFmpeg progress timestamps', () {
    expect(
      FfmpegExportService.parseProgressMs(
        'frame=123 fps=30 time=01:02:03.45 bitrate=1000kbits/s',
      ),
      3723450,
    );
    expect(FfmpegExportService.parseProgressMs('no timestamp here'), isNull);
  });
}

final bool _ffmpegAvailable = () {
  try {
    return Process.runSync('ffmpeg', const ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

String _unescape(String value) => value
    .replaceAll(r'\,', ',')
    .replaceAll(r"\'", "'")
    .replaceAll(r'\:', ':')
    .replaceAll(r'\\', r'\');

String _extractFontsDirectory(String filter) {
  final escaped = filter.split(':fontsdir=')[1].split(':force_style=')[0];
  return _unescape(_unescape(escaped));
}

final class _FakeProcess implements FfmpegProcess {
  _FakeProcess({required int exitCode})
    : _exitCodeCompleter = null,
      _exitCode = Future.value(exitCode);
  _FakeProcess.pending()
    : _exitCodeCompleter = Completer<int>(),
      _exitCode = null;

  final Future<int>? _exitCode;
  final Completer<int>? _exitCodeCompleter;
  bool killed = false;

  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Future<int> get exitCode => _exitCode ?? _exitCodeCompleter!.future;
  @override
  bool kill(ProcessSignal signal) {
    killed = true;
    _exitCodeCompleter?.complete(255);
    return true;
  }
}

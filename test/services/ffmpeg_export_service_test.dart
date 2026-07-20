import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/services/ffmpeg_export_service.dart';

void main() {
  test('embedded MP4 export copies media and uses mov_text subtitles', () {
    final arguments = FfmpegExportService.buildArguments(
      inputPath: '/videos/input file.mp4',
      subtitlePath: '/tmp/subtitles.srt',
      outputPath: '/videos/output file.mp4',
      mode: SubtitleVideoMode.embedded,
    );

    expect(arguments, containsAllInOrder(['-c:v', 'copy', '-c:a', 'copy']));
    expect(arguments, containsAllInOrder(['-c:s', 'mov_text']));
    expect(arguments, contains('/videos/input file.mp4'));
    expect(arguments, contains('/videos/output file.mp4'));
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

  test('burn-in export escapes filter-special path characters', () {
    final arguments = FfmpegExportService.buildArguments(
      inputPath: 'input.mp4',
      subtitlePath: "/tmp/a:b'subs.srt",
      outputPath: 'output.mp4',
      mode: SubtitleVideoMode.burnedIn,
    );

    expect(arguments, contains("subtitles=filename='/tmp/a\\:b\\'subs.srt'"));
    expect(arguments, containsAllInOrder(['-c:v', 'libx264']));
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

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  test('playbackRate defaults to 1.0', () {
    const project = Project(mediaPath: '/tmp/song.mp3', lines: []);
    expect(project.playbackRate, 1.0);
  });

  test('copyWith only overrides provided fields', () {
    const project = Project(mediaPath: '/tmp/a.mp3', playbackRate: 1.0, lines: []);
    final updated = project.copyWith(playbackRate: 0.75);
    expect(updated.mediaPath, '/tmp/a.mp3');
    expect(updated.playbackRate, 0.75);
  });

  test('toJson/fromJson round-trip', () {
    const project = Project(
      mediaPath: '/tmp/song.mp3',
      playbackRate: 0.75,
      lines: [
        SubtitleLine(index: 0, text: 'line one', startMs: 100, endMs: 900),
        SubtitleLine(index: 1, text: 'line two'),
      ],
    );
    final restored = Project.fromJson(project.toJson());
    expect(restored.mediaPath, project.mediaPath);
    expect(restored.playbackRate, project.playbackRate);
    expect(restored.lines, project.lines);
  });
}

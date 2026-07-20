import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/project_store.dart';

void main() {
  test('save then load restores an equivalent project', () async {
    final tempDir = await Directory.systemTemp.createTemp('stmarker_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final filePath = '${tempDir.path}/session.stmproj';

    const project = Project(
      mediaPath: '/home/user/song.mp3',
      playbackRate: 0.75,
      lines: [
        SubtitleLine(index: 0, text: 'line one', startMs: 100, endMs: 900),
        SubtitleLine(index: 1, text: 'line two'),
      ],
    );

    await ProjectStore.save(project, filePath);
    final restored = await ProjectStore.load(filePath);

    expect(restored.mediaPath, project.mediaPath);
    expect(restored.playbackRate, project.playbackRate);
    expect(restored.lines, project.lines);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

void main() {
  test('legacy project defaults to Standard karaoke with no pre-display', () {
    final project = Project.fromJson({
      'mediaPath': '/tmp/song.mp4',
      'lines': <Object?>[
        {'index': 0, 'text': 'hello', 'startMs': 1000, 'endMs': 2000},
      ],
    });
    expect(project.karaokeMode, KaraokeMode.standard);
    expect(project.karaokePreDisplay, KaraokePreDisplay.off);
    expect(project.lines.single.karaokeMarks, isEmpty);
  });

  test('karaoke configuration and marks survive JSON round trip', () {
    final project = Project(
      mediaPath: '/tmp/song.mp4',
      karaokeMode: KaraokeMode.karaokeAdvanced,
      karaokePreDisplay: KaraokePreDisplay.oneLineAhead,
      lines: [
        SubtitleLine.withKaraokeMarks(
          index: 0,
          text: 'hello world',
          startMs: 1000,
          endMs: 3000,
          karaokeMarks: [
            KaraokeMark(unitText: 'hello', startMs: 1000),
            KaraokeMark(unitText: 'world', startMs: 2100),
          ],
        ),
      ],
    );
    expect(Project.fromJson(project.toJson()).toJson(), project.toJson());
  });

  test('unknown karaoke enum names fall back to Standard and Off', () {
    final project = Project.fromJson({
      'mediaPath': '/tmp/song.mp4',
      'lines': <Object?>[],
      'karaokeMode': 'futureMode',
      'karaokePreDisplay': 'futureDisplay',
    });

    expect(project.karaokeMode, KaraokeMode.standard);
    expect(project.karaokePreDisplay, KaraokePreDisplay.off);
  });

  test('copyWith preserves and overrides karaoke configuration', () {
    const project = Project(
      mediaPath: '/tmp/song.mp4',
      karaokeMode: KaraokeMode.karaokeAdvanced,
      karaokePreDisplay: KaraokePreDisplay.seconds3,
      lines: [],
    );

    expect(project.copyWith().karaokeMode, KaraokeMode.karaokeAdvanced);
    expect(
      project
          .copyWith(karaokePreDisplay: KaraokePreDisplay.seconds5)
          .karaokePreDisplay,
      KaraokePreDisplay.seconds5,
    );
  });

  test('playbackRate defaults to 1.0', () {
    const project = Project(mediaPath: '/tmp/song.mp3', lines: []);
    expect(project.playbackRate, 1.0);
  });

  test('subtitle appearance defaults to the catalog default and 24', () {
    const project = Project(mediaPath: '/tmp/song.mp3', lines: []);

    expect(project.subtitleFontFamily, SubtitleFontCatalog.defaultFace.id);
    expect(project.subtitleFontSize, 24.0);
  });

  test('copyWith only overrides provided fields', () {
    const project = Project(
      mediaPath: '/tmp/a.mp3',
      playbackRate: 1.0,
      lines: [],
    );
    final updated = project.copyWith(playbackRate: 0.75);
    expect(updated.mediaPath, '/tmp/a.mp3');
    expect(updated.playbackRate, 0.75);
    expect(updated.subtitleFontFamily, SubtitleFontCatalog.defaultFace.id);
    expect(updated.subtitleFontSize, 24.0);
  });

  test('copyWith overrides both subtitle appearance fields', () {
    const project = Project(mediaPath: '/tmp/a.mp3', lines: []);

    final updated = project.copyWith(
      subtitleFontFamily: 'noto_serif_cjk',
      subtitleFontSize: 36.0,
    );

    expect(updated.subtitleFontFamily, 'noto_serif_cjk');
    expect(updated.subtitleFontSize, 36.0);
  });

  test('toJson/fromJson round-trip', () {
    final project = Project(
      mediaPath: '/tmp/song.mp3',
      playbackRate: 0.75,
      subtitleFontFamily: 'noto_serif_cjk',
      subtitleFontSize: 32.0,
      lines: [
        SubtitleLine(index: 0, text: 'line one', startMs: 100, endMs: 900),
        SubtitleLine(index: 1, text: 'line two'),
      ],
    );
    final restored = Project.fromJson(project.toJson());
    expect(restored.mediaPath, project.mediaPath);
    expect(restored.playbackRate, project.playbackRate);
    expect(restored.subtitleFontFamily, project.subtitleFontFamily);
    expect(restored.subtitleFontSize, project.subtitleFontSize);
    expect(restored.lines, project.lines);
  });

  test('old JSON defaults subtitle appearance', () {
    final restored = Project.fromJson({
      'mediaPath': '/tmp/song.mp3',
      'lines': <dynamic>[],
    });

    expect(restored.subtitleFontFamily, SubtitleFontCatalog.defaultFace.id);
    expect(restored.subtitleFontSize, 24.0);
  });

  test('unknown JSON font ID falls back to the catalog default', () {
    final restored = Project.fromJson({
      'mediaPath': '/tmp/song.mp3',
      'lines': <dynamic>[],
      'subtitleFontFamily': 'unknown',
    });

    expect(restored.subtitleFontFamily, SubtitleFontCatalog.defaultFace.id);
  });

  test('JSON subtitle size is clamped to the supported range', () {
    Map<String, dynamic> jsonWithSize(num size) => {
      'mediaPath': '/tmp/song.mp3',
      'lines': <dynamic>[],
      'subtitleFontSize': size,
    };

    expect(Project.fromJson(jsonWithSize(8)).subtitleFontSize, 16.0);
    expect(Project.fromJson(jsonWithSize(80)).subtitleFontSize, 64.0);
  });

  test('non-finite JSON subtitle size falls back to 24', () {
    Map<String, dynamic> jsonWithSize(double size) => {
      'mediaPath': '/tmp/song.mp3',
      'lines': <dynamic>[],
      'subtitleFontSize': size,
    };

    expect(Project.fromJson(jsonWithSize(double.nan)).subtitleFontSize, 24.0);
    expect(
      Project.fromJson(jsonWithSize(double.infinity)).subtitleFontSize,
      24.0,
    );
  });
}

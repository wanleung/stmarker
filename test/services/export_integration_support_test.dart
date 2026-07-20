import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/export_integration_support.dart';

void main() {
  test('warning analysis and wording are shared for export actions', () {
    final warning = exportWarnings(const [
      SubtitleLine(index: 0, text: 'Bad', startMs: 4, endMs: 3),
      SubtitleLine(index: 1, text: 'Missing'),
    ]);
    expect(warning.invalidCount, 1);
    expect(warning.incompleteCount, 1);
    expect(
      warning.message,
      '1 line(s) have invalid ranges. 1 incomplete line(s) will be skipped. Export anyway?',
    );
  });

  test('bundle loader preserves the exact ByteData slice', () async {
    final bytes = await bundleAssetLoader(_SlicedBundle())('font');
    expect(bytes, [20, 30, 40]);
  });

  test('video settings builder propagates selected face, size, and loader', () {
    final project = Project(
      mediaPath: '/tmp/video.mp4',
      lines: const [],
      subtitleFontFamily: 'noto_serif_cjk',
      subtitleFontSize: 42,
    );
    final loader = bundleAssetLoader(_SlicedBundle());
    final settings = buildVideoExportSettings(project, loader);
    expect(settings.subtitleFont.id, 'noto_serif_cjk');
    expect(settings.subtitleFontSize, 42);
    expect(settings.loadAsset, same(loader));
  });

  test('runExportAction reports labelled errors', () async {
    String? failure;
    await runExportAction(
      'Export ASS',
      () async => throw StateError('disk'),
      (message) => failure = message,
    );
    expect(failure, contains('Export ASS failed: Bad state: disk'));
  });
}

final class _SlicedBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final buffer = Uint8List.fromList([10, 20, 30, 40, 50]).buffer;
    return ByteData.view(buffer, 1, 3);
  }
}

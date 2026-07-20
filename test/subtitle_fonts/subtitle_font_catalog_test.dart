import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog exposes the three bundled subtitle font faces', () {
    expect(SubtitleFontCatalog.faces, hasLength(3));
    expect(SubtitleFontCatalog.faces.map((face) => face.id).toSet(), <String>{
      'noto_sans_cjk',
      'noto_serif_cjk',
      'noto_sans_mono_cjk',
    });
    expect(
      SubtitleFontCatalog.faces.map((face) => face.label).toList(),
      <String>['Sans', 'Serif', 'Monospace'],
    );
    expect(
      SubtitleFontCatalog.faces.map((face) => face.familyName).toList(),
      <String>[
        'Noto Sans CJK SC',
        'Noto Serif CJK SC',
        'Noto Sans Mono CJK SC',
      ],
    );
    expect(
      SubtitleFontCatalog.faces.map((face) => face.assetPath).toList(),
      <String>[
        'assets/fonts/NotoSansCJKsc-Regular.otf',
        'assets/fonts/NotoSerifCJKsc-Regular.otf',
        'assets/fonts/NotoSansMonoCJKsc-Regular.otf',
      ],
    );
  });

  test('catalog resolves the default and falls back for unknown IDs', () {
    expect(SubtitleFontCatalog.defaultFace.id, 'noto_sans_cjk');
    expect(SubtitleFontCatalog.byId('noto_serif_cjk').id, 'noto_serif_cjk');
    expect(
      SubtitleFontCatalog.byId(null),
      same(SubtitleFontCatalog.defaultFace),
    );
    expect(
      SubtitleFontCatalog.byId('not-a-font'),
      same(SubtitleFontCatalog.defaultFace),
    );
  });

  test('every catalog asset is available through rootBundle', () async {
    for (final face in SubtitleFontCatalog.faces) {
      final bytes = await rootBundle.load(face.assetPath);
      expect(bytes.lengthInBytes, greaterThan(0), reason: face.assetPath);
    }
  });
}

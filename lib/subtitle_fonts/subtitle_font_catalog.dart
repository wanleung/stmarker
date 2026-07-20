import 'package:flutter/foundation.dart';

@immutable
final class SubtitleFontFace {
  const SubtitleFontFace({
    required this.id,
    required this.label,
    required this.familyName,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String familyName;
  final String assetPath;
}

abstract final class SubtitleFontCatalog {
  static const SubtitleFontFace defaultFace = SubtitleFontFace(
    id: 'noto_sans_cjk',
    label: 'Sans',
    familyName: 'Noto Sans CJK SC',
    assetPath: 'assets/fonts/NotoSansCJKsc-Regular.otf',
  );

  static const List<SubtitleFontFace> faces = <SubtitleFontFace>[
    defaultFace,
    SubtitleFontFace(
      id: 'noto_serif_cjk',
      label: 'Serif',
      familyName: 'Noto Serif CJK SC',
      assetPath: 'assets/fonts/NotoSerifCJKsc-Regular.otf',
    ),
    SubtitleFontFace(
      id: 'noto_sans_mono_cjk',
      label: 'Monospace',
      familyName: 'Noto Sans Mono CJK SC',
      assetPath: 'assets/fonts/NotoSansMonoCJKsc-Regular.otf',
    ),
  ];

  static SubtitleFontFace byId(String? id) {
    for (final face in faces) {
      if (face.id == id) {
        return face;
      }
    }
    return defaultFace;
  }
}

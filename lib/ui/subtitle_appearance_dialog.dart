import 'package:flutter/material.dart';

import '../models/project.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';

@immutable
final class SubtitleAppearance {
  const SubtitleAppearance({required this.fontFamily, required this.fontSize});

  final String fontFamily;
  final double fontSize;
}

Future<SubtitleAppearance?> showSubtitleAppearanceDialog(
  BuildContext context, {
  required SubtitleAppearance initial,
  required String previewText,
}) => showDialog<SubtitleAppearance>(
  context: context,
  builder: (context) =>
      _SubtitleAppearanceDialog(initial: initial, previewText: previewText),
);

class _SubtitleAppearanceDialog extends StatefulWidget {
  const _SubtitleAppearanceDialog({
    required this.initial,
    required this.previewText,
  });

  final SubtitleAppearance initial;
  final String previewText;

  @override
  State<_SubtitleAppearanceDialog> createState() =>
      _SubtitleAppearanceDialogState();
}

class _SubtitleAppearanceDialogState extends State<_SubtitleAppearanceDialog> {
  late String _fontFamily = SubtitleFontCatalog.byId(
    widget.initial.fontFamily,
  ).id;
  late double _fontSize = widget.initial.fontSize.clamp(
    minimumSubtitleFontSize,
    maximumSubtitleFontSize,
  );

  void _reset() {
    setState(() {
      _fontFamily = SubtitleFontCatalog.defaultFace.id;
      _fontSize = defaultSubtitleFontSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final face = SubtitleFontCatalog.byId(_fontFamily);
    return AlertDialog(
      title: const Text('Subtitle appearance'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('subtitle-appearance-font'),
              initialValue: _fontFamily,
              decoration: const InputDecoration(labelText: 'Font'),
              items: [
                for (final face in SubtitleFontCatalog.faces)
                  DropdownMenuItem(value: face.id, child: Text(face.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _fontFamily = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const ValueKey('subtitle-appearance-size'),
                    min: minimumSubtitleFontSize,
                    max: maximumSubtitleFontSize,
                    divisions:
                        (maximumSubtitleFontSize - minimumSubtitleFontSize)
                            .toInt(),
                    value: _fontSize,
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    _fontSize.round().toString(),
                    key: const ValueKey('subtitle-appearance-size-value'),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.inverseSurface,
              alignment: Alignment.center,
              child: Text(
                widget.previewText,
                key: const ValueKey('subtitle-appearance-preview'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontFamily: face.familyName,
                  fontSize: _fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('subtitle-appearance-reset'),
          onPressed: _reset,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('subtitle-appearance-save'),
          onPressed: () => Navigator.pop(
            context,
            SubtitleAppearance(fontFamily: _fontFamily, fontSize: _fontSize),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

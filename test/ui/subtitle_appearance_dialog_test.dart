import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/subtitle_fonts/subtitle_font_catalog.dart';
import 'package:stmarker/ui/subtitle_appearance_dialog.dart';

void main() {
  testWidgets('dialog exposes catalog faces and updates its live preview', (
    tester,
  ) async {
    await tester.pumpWidget(const _DialogHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subtitle-appearance-font')));
    await tester.pumpAndSettle();
    for (final face in SubtitleFontCatalog.faces) {
      expect(find.text(face.label), findsWidgets);
    }
    expect(
      tester
          .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>),
          )
          .map((item) => item.value)
          .toSet(),
      containsAll(SubtitleFontCatalog.faces.map((face) => face.id)),
    );
    await tester.tap(find.text('Serif').last);
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('subtitle-appearance-size')),
    );
    expect(slider.min, 16);
    expect(slider.max, 64);
    slider.onChanged!(40);
    await tester.pump();

    expect(find.text('40'), findsOneWidget);
    final preview = tester.widget<Text>(
      find.byKey(const ValueKey('subtitle-appearance-preview')),
    );
    expect(preview.data, 'Preview 字幕');
    expect(preview.style?.fontFamily, 'Noto Serif CJK SC');
    expect(preview.style?.fontSize, 40);
  });

  testWidgets('reset is local, cancel returns null, and save returns values', (
    tester,
  ) async {
    await tester.pumpWidget(const _DialogHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('subtitle-appearance-size')),
    );
    slider.onChanged!(48);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('subtitle-appearance-reset')));
    await tester.pump();
    expect(find.text('24'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Result: null'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subtitle-appearance-font')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monospace').last);
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const ValueKey('subtitle-appearance-size')))
        .onChanged!(32);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('subtitle-appearance-save')));
    await tester.pumpAndSettle();

    expect(find.text('Result: noto_sans_mono_cjk/32'), findsOneWidget);
  });
}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness();

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  String _result = 'unopened';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () async {
                  final result = await showSubtitleAppearanceDialog(
                    context,
                    initial: const SubtitleAppearance(
                      fontFamily: 'noto_serif_cjk',
                      fontSize: 36,
                    ),
                    previewText: 'Preview 字幕',
                  );
                  if (mounted) {
                    setState(() {
                      _result = result == null
                          ? 'null'
                          : '${result.fontFamily}/${result.fontSize.toInt()}';
                    });
                  }
                },
                child: const Text('Open'),
              ),
              Text('Result: $_result'),
            ],
          ),
        ),
      ),
    );
  }
}

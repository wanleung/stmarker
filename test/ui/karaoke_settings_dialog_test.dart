import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';
import 'package:stmarker/ui/karaoke_settings_dialog.dart';

void main() {
  testWidgets('shows every mode and pre-display choice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showKaraokeSettingsDialog(
                context,
                initial: const KaraokeSettings(
                  mode: KaraokeMode.karaokeEasy,
                  preDisplay: KaraokePreDisplay.seconds4,
                ),
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    for (final label in ['Standard', 'Karaoke Easy', 'Karaoke Advanced']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in [
      'Off',
      '3 seconds',
      '4 seconds',
      '5 seconds',
      'One line ahead',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester
          .widget<RadioGroup<KaraokeMode>>(
            find.byKey(const ValueKey('karaoke-mode')),
          )
          .groupValue,
      KaraokeMode.karaokeEasy,
    );
    expect(
      tester
          .widget<RadioGroup<KaraokePreDisplay>>(
            find.byKey(const ValueKey('karaoke-pre-display')),
          )
          .groupValue,
      KaraokePreDisplay.seconds4,
    );
  });

  testWidgets(
    'Standard disables pre-display but preserves selection and Cancel returns null',
    (tester) async {
      KaraokeSettings? result = const KaraokeSettings(
        mode: KaraokeMode.karaokeEasy,
        preDisplay: KaraokePreDisplay.seconds5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showKaraokeSettingsDialog(
                context,
                initial: result!,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard'));
      await tester.pump();
      final group = tester.widget<RadioGroup<KaraokePreDisplay>>(
        find.byKey(const ValueKey('karaoke-pre-display')),
      );
      expect(group.groupValue, KaraokePreDisplay.seconds5);
      expect(
        tester
            .widgetList<RadioListTile<KaraokePreDisplay>>(
              find.byType(RadioListTile<KaraokePreDisplay>),
            )
            .every((tile) {
              // ignore: deprecated_member_use
              return tile.enabled == false && tile.onChanged == null;
            }),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('karaoke-pre-display-disabled')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );

  testWidgets('Save returns the selected pair', (tester) async {
    KaraokeSettings? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showKaraokeSettingsDialog(
              context,
              initial: const KaraokeSettings(
                mode: KaraokeMode.standard,
                preDisplay: KaraokePreDisplay.off,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karaoke Advanced'));
    tester
        .widget<RadioGroup<KaraokePreDisplay>>(
          find.byKey(const ValueKey('karaoke-pre-display')),
        )
        .onChanged(KaraokePreDisplay.oneLineAhead);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('karaoke-settings-save')));
    await tester.pumpAndSettle();
    expect(result?.mode, KaraokeMode.karaokeAdvanced);
    expect(result?.preDisplay, KaraokePreDisplay.oneLineAhead);
  });
}

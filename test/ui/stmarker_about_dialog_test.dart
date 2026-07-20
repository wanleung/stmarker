import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/ui/stmarker_about_dialog.dart';

void main() {
  testWidgets('shows application details and license information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStmarkerAboutDialog(context),
            child: const Text('About'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('stmarker'), findsOneWidget);
    expect(find.text(stmarkerVersion), findsOneWidget);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
    expect(find.textContaining('creating subtitled videos'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/ui/stmarker_about_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> pumpAbout(
  WidgetTester tester, {
  required UrlLauncher launcher,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showStmarkerAboutDialog(context, launcher: launcher),
            child: const Text('About'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('About'));
  await tester.pumpAndSettle();
}

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

    expect(find.text('Subtitle Marker'), findsOneWidget);
    expect(find.text(stmarkerVersion), findsOneWidget);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
    expect(find.textContaining('creating subtitled videos'), findsOneWidget);
    expect(find.textContaining('Noto fonts'), findsOneWidget);
    expect(find.textContaining('SIL Open Font License'), findsOneWidget);
  });

  testWidgets('shows author and opens the GitHub repository', (tester) async {
    Uri? launchedUri;
    LaunchMode? launchedMode;
    await pumpAbout(
      tester,
      launcher: (uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        launchedMode = mode;
        return true;
      },
    );
    expect(find.text('Author: Wan Leung Wong'), findsOneWidget);
    expect(find.text('github.com/wanleung/stmarker'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.text('github.com/wanleung/stmarker'));
    await tester.pumpAndSettle();
    expect(launchedUri, Uri.parse('https://github.com/wanleung/stmarker'));
    expect(launchedMode, LaunchMode.externalApplication);
  });

  testWidgets('reports when the GitHub repository cannot be opened', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
    );
    await tester.tap(find.text('github.com/wanleung/stmarker'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the GitHub repository.'), findsOneWidget);
    expect(find.text('Subtitle Marker'), findsOneWidget);
  });
}

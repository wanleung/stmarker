# About Author and GitHub Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show Wan Leung Wong and a clickable GitHub repository link in the About dialog without exposing an email address.

**Architecture:** Keep the author and repository metadata in `stmarker_about_dialog.dart`. Add `url_launcher` for opening the HTTPS repository externally, and inject the launch callback into the dialog function so widget tests remain deterministic. Report launch rejection with a SnackBar while leaving the dialog open.

**Tech Stack:** Flutter Material, `url_launcher`, `flutter_test`

## Global Constraints

- Display the author exactly as `Wan Leung Wong`.
- Use `https://github.com/wanleung/stmarker` as the only contact route.
- Do not display or store an email address in the About dialog.
- Preserve all existing About-dialog application, version, GPL, technology, and Noto licence content.
- Open the repository in the system's default browser.
- A rejected or failed launch must not close the dialog or crash the application.

---

### Task 1: Specify About dialog author and link behaviour

**Files:**
- Modify: `test/ui/stmarker_about_dialog_test.dart`

**Interfaces:**
- Consumes: existing `showStmarkerAboutDialog(BuildContext context)` and `stmarkerVersion`
- Produces: widget expectations for author copy, absence of email, repository URI, and launch failure feedback

- [ ] **Step 1: Add failing author and successful-launch widget tests**

Import the About dialog API, provide a recording launcher callback, open the
dialog, and assert the required content and navigation:

```dart
Future<void> pumpAbout(
  WidgetTester tester, {
  required UrlLauncher launcher,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showStmarkerAboutDialog(
            context,
            launcher: launcher,
          ),
          child: const Text('About'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('About'));
  await tester.pumpAndSettle();
}

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
```

- [ ] **Step 2: Add a failing launch-rejection widget test**

```dart
testWidgets('reports when the GitHub repository cannot be opened',
    (tester) async {
  await pumpAbout(
    tester,
    launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
  );
  await tester.tap(find.text('github.com/wanleung/stmarker'));
  await tester.pumpAndSettle();
  expect(find.text('Could not open the GitHub repository.'), findsOneWidget);
  expect(find.text('Subtitle Marker'), findsOneWidget);
});
```

- [ ] **Step 3: Run the focused test and confirm the new API is missing**

Run: `flutter test test/ui/stmarker_about_dialog_test.dart`

Expected: FAIL because `LaunchMode`/`url_launcher` and the named `launcher`
argument have not been added.

---

### Task 2: Implement the author and external GitHub link

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/ui/stmarker_about_dialog.dart`
- Test: `test/ui/stmarker_about_dialog_test.dart`

**Interfaces:**
- Consumes: `url_launcher`'s `LaunchMode` and `launchUrl`
- Produces: `typedef UrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});`, `stmarkerRepositoryUri`, and `showStmarkerAboutDialog(BuildContext context, {UrlLauncher launcher = launchUrl})`

- [ ] **Step 1: Add the URL-launching dependency**

Run: `flutter pub add url_launcher`

Expected: `pubspec.yaml` declares `url_launcher` and dependency resolution
updates `pubspec.lock` successfully.

- [ ] **Step 2: Add repository metadata and injectable launching**

Update `lib/ui/stmarker_about_dialog.dart` with the following public boundary:

```dart
import 'package:url_launcher/url_launcher.dart';

const stmarkerRepositoryUri = 'https://github.com/wanleung/stmarker';
typedef UrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

void showStmarkerAboutDialog(
  BuildContext context, {
  UrlLauncher launcher = launchUrl,
}) {
  showAboutDialog(
    context: context,
    applicationName: 'Subtitle Marker',
    applicationVersion: stmarkerVersion,
    applicationIcon: const Icon(Icons.subtitles, size: 48),
    applicationLegalese:
        'Copyright © 2026 Subtitle Marker contributors\nGPL-3.0-or-later',
    children: [
      const SizedBox(height: 16),
      const Text(
        'A local desktop tool for timing subtitles and lyrics against video '
        'or audio, exporting SRT files, and creating subtitled videos with '
        'FFmpeg.',
      ),
      const SizedBox(height: 12),
      const Text('Author: Wan Leung Wong'),
      Tooltip(
        message: 'Open the Subtitle Marker repository on GitHub',
        child: TextButton(
          onPressed: () async {
            try {
              final opened = await launcher(
                Uri.parse(stmarkerRepositoryUri),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                _showRepositoryLaunchError(context);
              }
            } on Exception {
              if (context.mounted) _showRepositoryLaunchError(context);
            }
          },
          child: const Text('github.com/wanleung/stmarker'),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Built with Flutter, media_kit, libmpv, and FFmpeg.'),
      const SizedBox(height: 12),
      const Text(
        'Bundled Noto fonts are copyright their respective authors and are '
        'provided under the SIL Open Font License 1.1.',
      ),
    ],
  );
}

void _showRepositoryLaunchError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the GitHub repository.')),
  );
}
```

Add `Author: Wan Leung Wong` and a tooltip-wrapped `TextButton` labelled
`github.com/wanleung/stmarker`. Its asynchronous callback must call:

```dart
final opened = await launcher(
  Uri.parse(stmarkerRepositoryUri),
  mode: LaunchMode.externalApplication,
);
if (!opened && context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the GitHub repository.')),
  );
}
```

The callback catches launcher exceptions and shows the same SnackBar while the
About dialog remains open.

- [ ] **Step 3: Run the focused tests**

Run: `flutter test test/ui/stmarker_about_dialog_test.dart`

Expected: all About-dialog tests PASS, including existing licence assertions,
the successful external launch, no email text, and failure feedback.

- [ ] **Step 4: Format and inspect the implementation diff**

Run: `dart format lib/ui/stmarker_about_dialog.dart test/ui/stmarker_about_dialog_test.dart && git diff --check && git diff -- lib/ui/stmarker_about_dialog.dart test/ui/stmarker_about_dialog_test.dart pubspec.yaml pubspec.lock`

Expected: formatting completes, `git diff --check` produces no output, and the
diff contains only the approved About-dialog feature and dependency metadata.

- [ ] **Step 5: Commit the implementation**

```bash
git add pubspec.yaml pubspec.lock lib/ui/stmarker_about_dialog.dart test/ui/stmarker_about_dialog_test.dart
git commit -m "Add author and GitHub link to About dialog"
```

---

### Task 3: Verify the complete application

**Files:**
- Verify: `lib/`
- Verify: `test/`

**Interfaces:**
- Consumes: the completed About-dialog implementation
- Produces: fresh evidence that the repository remains releasable

- [ ] **Step 1: Run static and automated verification**

Run: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test`

Expected: formatting reports no changes, analysis reports no issues, and all
tests pass.

- [ ] **Step 2: Build the Linux application**

Run: `flutter build linux`

Expected: exit code 0 and a completed Linux bundle under `build/linux/`.

- [ ] **Step 3: Confirm repository scope**

Run: `git status --short && git log -2 --oneline`

Expected: only the pre-existing untracked `.superpowers/` directory remains;
the design/plan and implementation commits are the latest commits.

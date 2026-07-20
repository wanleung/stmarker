# Review Subtitle Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display the selected review line in a focused, high-contrast panel directly beneath the video.

**Architecture:** Keep review selection owned by `MarkingScaffold` and derive the panel text from `MarkingSession.lines`; no persistent state or model changes are needed. Add a small private presentation widget inside the scaffold file, and make the existing review-index access safe when the line list is empty or replaced.

**Tech Stack:** Flutter Material, Provider/ChangeNotifier, flutter_test

## Global Constraints

- Show the panel only while review mode is active and at least one line exists.
- Place it between the video and the existing player controls.
- Keep the selected text visible during both playback and pause.
- Center the text, use a high-contrast surface, and limit it to three wrapped lines.
- Do not alter project serialization, marking shortcuts, review playback, or redo behavior.

---

### Task 1: Review subtitle panel behavior

**Files:**
- Modify: `test/ui/marking_scaffold_test.dart`
- Modify: `lib/ui/marking_scaffold.dart`

**Interfaces:**
- Consumes: `MarkingScaffold.reviewMode`, `_reviewIndex`, and `MarkingSession.lines`
- Produces: private `_ReviewSubtitlePanel({required String text})` widget identified by `ValueKey('review-subtitle-panel')`

- [ ] **Step 1: Write failing visibility tests**

Add these widget tests to `test/ui/marking_scaffold_test.dart`:

```dart
testWidgets('review shows the selected line beneath the video', (tester) async {
  final controls = FakePlaybackControls();
  final session = MarkingSession(
    const Project(
      mediaPath: '/x.mp3',
      lines: [
        SubtitleLine(index: 0, text: 'focused review text', startMs: 500, endMs: 900),
      ],
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(
          body: MarkingScaffold(
            controls: controls,
            reviewMode: true,
            videoArea: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('review-subtitle-panel')), findsOneWidget);
  expect(find.text('focused review text'), findsOneWidget);
});

testWidgets('normal marking mode does not show the review subtitle panel', (tester) async {
  final controls = FakePlaybackControls();
  final session = MarkingSession(
    const Project(
      mediaPath: '/x.mp3',
      lines: [SubtitleLine(index: 0, text: 'not over video')],
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls)),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('review-subtitle-panel')), findsNothing);
});
```

- [ ] **Step 2: Run the tests and verify the new assertion fails**

Run:

```bash
flutter test test/ui/marking_scaffold_test.dart --plain-name "review shows the selected line beneath the video"
```

Expected: FAIL because no widget has the key `review-subtitle-panel`.

- [ ] **Step 3: Add the minimal review panel**

In `lib/ui/marking_scaffold.dart`, add a private widget:

```dart
class _ReviewSubtitlePanel extends StatelessWidget {
  const _ReviewSubtitlePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review-subtitle-panel'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Theme.of(context).colorScheme.inverseSurface,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}
```

In `_MarkingScaffoldState.build`, derive a safe review index and insert the panel immediately after the optional video:

```dart
final reviewIndex = session.lines.isEmpty
    ? null
    : _reviewIndex.clamp(0, session.lines.length - 1);
```

```dart
if (widget.reviewMode && reviewIndex != null)
  _ReviewSubtitlePanel(text: session.lines[reviewIndex].text),
```

Use `reviewIndex` for `LineListView.selectedIndex` so an externally replaced line list cannot leave an invalid selection highlighted.

- [ ] **Step 4: Run both visibility tests**

Run:

```bash
flutter test test/ui/marking_scaffold_test.dart
```

Expected: all marking scaffold tests PASS.

- [ ] **Step 5: Commit the visibility behavior**

```bash
git add lib/ui/marking_scaffold.dart test/ui/marking_scaffold_test.dart
git commit -m "Add focused subtitle panel to review mode"
```

### Task 2: Selection synchronization and empty-list safety

**Files:**
- Modify: `test/ui/marking_scaffold_test.dart`
- Modify: `lib/ui/marking_scaffold.dart`

**Interfaces:**
- Consumes: `_selectReviewLine(MarkingSession session, int index, {bool play = false})`
- Produces: safe review controls for zero lines and synchronized panel text for navigation and row selection

- [ ] **Step 1: Write failing synchronization and empty-list tests**

Add these two tests:

```dart
testWidgets('review panel updates with navigation and row selection', (tester) async {
  final controls = FakePlaybackControls();
  final session = MarkingSession(
    const Project(
      mediaPath: '/x.mp3',
      lines: [
        SubtitleLine(index: 0, text: 'first', startMs: 500, endMs: 900),
        SubtitleLine(index: 1, text: 'second', startMs: 1200, endMs: 1800),
      ],
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls, reviewMode: true)),
      ),
    ),
  );

  final panel = find.byKey(const ValueKey('review-subtitle-panel'));
  await tester.tap(find.byKey(const ValueKey('review-next')));
  await tester.pump();
  expect(find.descendant(of: panel, matching: find.text('second')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('line-row-0')));
  await tester.pump();
  expect(find.descendant(of: panel, matching: find.text('first')), findsOneWidget);
});

testWidgets('empty review hides the panel and disables playback', (tester) async {
  final controls = FakePlaybackControls();
  final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: []));
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls, reviewMode: true)),
      ),
    ),
  );

  expect(tester.takeException(), isNull);
  expect(find.byKey(const ValueKey('review-subtitle-panel')), findsNothing);
  expect(
    tester.widget<IconButton>(find.byKey(const ValueKey('review-play'))).onPressed,
    isNull,
  );
});
```

- [ ] **Step 2: Run the synchronization and empty-list tests**

Run:

```bash
flutter test test/ui/marking_scaffold_test.dart --plain-name "review panel updates"
flutter test test/ui/marking_scaffold_test.dart --plain-name "empty review"
```

Expected: the synchronization test passes once Task 1 is present; the empty-list test exposes any unsafe index access or enabled review action.

- [ ] **Step 3: Clamp review state consistently**

Add a helper to `_MarkingScaffoldState` and use it in the panel, controls label, selected row, flag action, and finish logic:

```dart
int? _safeReviewIndex(MarkingSession session) {
  if (session.lines.isEmpty) return null;
  return _reviewIndex.clamp(0, session.lines.length - 1);
}
```

Disable previous, play, next, and flag controls when the helper returns null. Keep **Finish review** enabled so the user can leave review mode safely. `_toggleReviewFlag` must return without mutation when there is no valid index.

- [ ] **Step 4: Run the focused widget test file**

Run:

```bash
flutter test test/ui/marking_scaffold_test.dart
```

Expected: all marking scaffold tests PASS.

- [ ] **Step 5: Run full verification**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Expected: formatting reports zero changes, analyzer reports no issues, all tests pass, and `git diff --check` produces no output.

- [ ] **Step 6: Commit safety coverage**

```bash
git add lib/ui/marking_scaffold.dart test/ui/marking_scaffold_test.dart
git commit -m "Harden review panel selection handling"
```

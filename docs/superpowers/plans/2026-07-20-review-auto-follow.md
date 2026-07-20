# Review Auto-Follow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically display and highlight the marked subtitle interval containing the live playhead during review playback.

**Architecture:** Add a pure interval lookup helper in a focused UI utility file, then have `MarkingScaffold` maintain an optional transient follow index from playback notifications. Keep manual review selection separate so gaps can blank the fixed-height panel while pausing preserves the last active selection.

**Tech Stack:** Dart, Flutter Material, Provider/ChangeNotifier, flutter_test

## Global Constraints

- Auto-follow runs only while review mode is active and `PlaybackControls.isPlaying` is true.
- A line matches when `startMs <= positionMs < endMs`; the first matching fully marked line wins.
- Playback gaps show an empty, size-preserving subtitle panel.
- Pausing preserves the last active or manually selected line.
- Manual navigation, flagging, exact **Play this line** playback, operation-generation guards, and playback ownership must remain intact.

---

### Task 1: Subtitle interval lookup

**Files:**
- Create: `lib/ui/review_active_line.dart`
- Create: `test/ui/review_active_line_test.dart`

**Interfaces:**
- Consumes: `List<SubtitleLine>` and an integer playhead position
- Produces: `int? findActiveReviewLine(List<SubtitleLine> lines, int positionMs)`

- [ ] **Step 1: Write failing lookup tests**

Create `test/ui/review_active_line_test.dart` with tests asserting that the
helper returns the matching index inside an interval, returns null in gaps,
includes the start boundary, excludes the end boundary, skips incomplete
lines, and returns the first list-order match for overlaps.

```dart
expect(findActiveReviewLine(lines, 100), 0);
expect(findActiveReviewLine(lines, 199), 0);
expect(findActiveReviewLine(lines, 200), isNull);
expect(findActiveReviewLine(lines, 250), isNull);
```

Use overlapping marked fixtures and assert the earlier list index wins. Use a
start-only fixture and assert it never matches.

- [ ] **Step 2: Verify the tests fail for the missing helper**

Run:

```bash
flutter test test/ui/review_active_line_test.dart
```

Expected: compilation fails because `review_active_line.dart` and
`findActiveReviewLine` do not exist.

- [ ] **Step 3: Implement the pure helper**

Create `lib/ui/review_active_line.dart`:

```dart
import '../models/subtitle_line.dart';

int? findActiveReviewLine(List<SubtitleLine> lines, int positionMs) {
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final startMs = line.startMs;
    final endMs = line.endMs;
    if (startMs != null &&
        endMs != null &&
        startMs <= positionMs &&
        positionMs < endMs) {
      return index;
    }
  }
  return null;
}
```

- [ ] **Step 4: Run the lookup tests**

Run `flutter test test/ui/review_active_line_test.dart`.

Expected: all lookup tests pass.

- [ ] **Step 5: Commit the helper**

```bash
git add lib/ui/review_active_line.dart test/ui/review_active_line_test.dart
git commit -m "Add review subtitle interval lookup"
```

### Task 2: Live review auto-follow

**Files:**
- Modify: `lib/ui/marking_scaffold.dart`
- Modify: `test/ui/marking_scaffold_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: `findActiveReviewLine`, `PlaybackControls.positionMs`, and `PlaybackControls.isPlaying`
- Produces: transient `_reviewFollowIndex`; nullable panel text while playing through gaps

- [ ] **Step 1: Write failing playback-follow widget tests**

Add tests to `test/ui/marking_scaffold_test.dart` using
`FakePlaybackControls`. Each test first pumps a review session with two marked
lines separated by a gap, calls `controls.play()`, moves the fake position with
`seekTestPosition`, and pumps.

Assert these behaviors:

```dart
// Entering the second interval follows it.
controls.seekTestPosition(1250);
await tester.pump();
expect(find.descendant(of: panel, matching: find.text('second')), findsOneWidget);
expect(tester.widget<Material>(rowMaterialFinder).color,
    Theme.of(tester.element(rowMaterialFinder)).colorScheme.primaryContainer);

// A gap keeps the panel but removes subtitle text.
controls.seekTestPosition(1000);
await tester.pump();
expect(panel, findsOneWidget);
expect(find.descendant(of: panel, matching: find.text('first')), findsNothing);
expect(find.descendant(of: panel, matching: find.text('second')), findsNothing);

// Pausing in the gap restores the last active selection.
await controls.pause();
await tester.pump();
expect(find.descendant(of: panel, matching: find.text('second')), findsOneWidget);
```

Also verify seeking from the first interval directly into the second updates
immediately, and that manual row selection while paused still updates the
panel. Keep the existing exact interval test unchanged and passing.

- [ ] **Step 2: Verify the new widget tests fail**

Run:

```bash
flutter test test/ui/marking_scaffold_test.dart --plain-name "review auto-follow"
```

Expected: failures show the panel and selected row remain on the manual review
index or fail to blank during a gap.

- [ ] **Step 3: Implement transient follow state**

In `lib/ui/marking_scaffold.dart` import `review_active_line.dart` and add:

```dart
int? _reviewFollowIndex;
bool _reviewFollowingPlayback = false;
```

In `_handleControlsChanged`, after rate synchronization and exact-stop
handling, update follow state only during active review playback:

```dart
if (widget.reviewMode && widget.controls.isPlaying) {
  final activeIndex = findActiveReviewLine(
    session.lines,
    widget.controls.positionMs,
  );
  if (!_reviewFollowingPlayback || activeIndex != _reviewFollowIndex) {
    setState(() {
      _reviewFollowingPlayback = true;
      _reviewFollowIndex = activeIndex;
      if (activeIndex != null) _reviewIndex = activeIndex;
    });
  }
} else if (_reviewFollowingPlayback) {
  setState(() {
    _reviewFollowingPlayback = false;
    _reviewFollowIndex = null;
  });
}
```

Avoid `setState` after exact-stop pause is launched if the synchronous control
notification has already changed `isPlaying`; derive state again from the
current controls value. Clear follow state when review enters/exits, controls
or lines are replaced, review finishes, and the widget disposes.

- [ ] **Step 4: Render nullable playback text without layout shift**

Derive the display index from playback follow state while playing, otherwise
from `_safeReviewIndex`. During a gap, pass an empty string to the existing
panel instead of removing it:

```dart
final manualReviewIndex = _safeReviewIndex(session);
final displayReviewIndex = _reviewFollowingPlayback
    ? _reviewFollowIndex
    : manualReviewIndex;
final reviewText = displayReviewIndex == null
    ? ''
    : session.lines[displayReviewIndex].text;
```

Keep the panel mounted whenever review mode has nonempty lines. Use
`displayReviewIndex` for the row highlight, but continue using the safe manual
index for review controls and flagging. Since every non-null active index also
updates `_reviewIndex`, pause and flag actions resume from the followed line.

- [ ] **Step 5: Update workflow documentation**

In the README review step, state that continuous playback automatically shows
and highlights the subtitle at the playhead, while gaps display no subtitle.

- [ ] **Step 6: Run focused verification**

```bash
flutter test test/ui/review_active_line_test.dart test/ui/marking_scaffold_test.dart
```

Expected: lookup and scaffold tests pass, including existing exact playback,
async ownership, exit, and line-replacement regressions.

- [ ] **Step 7: Run full verification**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Expected: formatting reports zero changes, analyzer reports no issues, all
tests pass, and the diff check is clean.

- [ ] **Step 8: Commit auto-follow**

```bash
git add lib/ui/marking_scaffold.dart test/ui/marking_scaffold_test.dart README.md
git commit -m "Auto-follow subtitles during review playback"
```

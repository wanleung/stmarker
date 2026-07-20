# Karaoke Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Standard, Karaoke Easy, and Karaoke Advanced workflows with live word/character highlighting, timed or one-line-ahead pre-display, ASS export, and matching burned-in video.

**Architecture:** Extend project and subtitle-line persistence with explicit karaoke configuration and Advanced marks. Put deterministic tokenization, timing resolution, validation, and ASS event generation in pure services; keep live Advanced marking in `MarkingSession` and playback coordination in `MarkingScaffold`. Preview and every karaoke-capable export consume the same resolved segments so editor and output remain consistent.

**Tech Stack:** Flutter/Dart, Provider, media_kit playback abstraction, ASS/FFmpeg, flutter_test

## Global Constraints

- Existing projects without karaoke fields load as Standard mode.
- Standard marking, review, SRT, ASS, and video export behavior remains unchanged.
- Easy mode divides each valid whole-line interval evenly across deterministic units.
- Advanced mode starts playback two seconds before the existing line start and records one Space press per unit; the first press atomically replaces the line singing start.
- Space-separated text uses words, unspaced Chinese/Japanese uses grapheme characters, punctuation attaches to an adjacent unit, and whitespace is preserved but not separately timed.
- Upcoming text is white and completed text is gold.
- Pre-display choices are Off, 3 seconds, 4 seconds, 5 seconds, and One line ahead.
- One-line-ahead preview and ASS events alternate between two fixed rows.
- SRT and selectable subtitle tracks retain whole-line timing and warn that karaoke presentation is omitted.
- Karaoke ASS and burned-in export reject incomplete or invalid Advanced timing rather than silently substituting Easy timing.
- Existing selected Noto font and size apply to preview, ASS, and burned-in video.
- Importing ASS karaoke tags is outside scope.

---

### Task 1: Persist karaoke configuration and Advanced marks

**Files:**
- Create: `lib/karaoke/karaoke_models.dart`
- Create: `test/karaoke/karaoke_models_test.dart`
- Modify: `lib/models/project.dart`
- Modify: `lib/models/subtitle_line.dart`
- Modify: `test/models/project_test.dart`
- Modify: `test/models/subtitle_line_test.dart`

**Interfaces:**
- Produces: `KaraokeMode`, `KaraokePreDisplay`, `KaraokeMark`, `Project.karaokeMode`, `Project.karaokePreDisplay`, and `SubtitleLine.karaokeMarks`
- Preserves: all existing constructor defaults and JSON compatibility

- [ ] **Step 1: Add failing model and JSON tests**

Add exact round-trip and legacy assertions:

```dart
test('legacy project defaults to Standard karaoke with no pre-display', () {
  final project = Project.fromJson({
    'mediaPath': '/tmp/song.mp4',
    'lines': <Object?>[
      {'index': 0, 'text': 'hello', 'startMs': 1000, 'endMs': 2000},
    ],
  });
  expect(project.karaokeMode, KaraokeMode.standard);
  expect(project.karaokePreDisplay, KaraokePreDisplay.off);
  expect(project.lines.single.karaokeMarks, isEmpty);
});

test('karaoke configuration and marks survive JSON round trip', () {
  final project = Project(
    mediaPath: '/tmp/song.mp4',
    karaokeMode: KaraokeMode.karaokeAdvanced,
    karaokePreDisplay: KaraokePreDisplay.oneLineAhead,
    lines: const [
      SubtitleLine(
        index: 0,
        text: 'hello world',
        startMs: 1000,
        endMs: 3000,
        karaokeMarks: [
          KaraokeMark(unitText: 'hello', startMs: 1000),
          KaraokeMark(unitText: 'world', startMs: 2100),
        ],
      ),
    ],
  );
  expect(Project.fromJson(project.toJson()).toJson(), project.toJson());
});
```

Also assert unknown enum strings fall back to Standard/Off, malformed marks are
ignored, equality includes marks, ordinary `copyWith` preserves marks, and
`withExactTimestamps`/`clearTimestamps` clear marks when timing changes.

- [ ] **Step 2: Run model tests and verify RED**

Run: `flutter test test/karaoke/karaoke_models_test.dart test/models/project_test.dart test/models/subtitle_line_test.dart`

Expected: FAIL because karaoke types and persisted fields do not exist.

- [ ] **Step 3: Implement immutable karaoke model types**

Define these exact types in `lib/karaoke/karaoke_models.dart`:

```dart
enum KaraokeMode { standard, karaokeEasy, karaokeAdvanced }

enum KaraokePreDisplay { off, seconds3, seconds4, seconds5, oneLineAhead }

extension KaraokePreDisplayDuration on KaraokePreDisplay {
  int? get leadMs => switch (this) {
    KaraokePreDisplay.seconds3 => 3000,
    KaraokePreDisplay.seconds4 => 4000,
    KaraokePreDisplay.seconds5 => 5000,
    KaraokePreDisplay.off || KaraokePreDisplay.oneLineAhead => null,
  };
}

final class KaraokeMark {
  const KaraokeMark({required this.unitText, required this.startMs});
  final String unitText;
  final int startMs;
  Map<String, Object> toJson() => {'unitText': unitText, 'startMs': startMs};
  factory KaraokeMark.fromJson(Map<String, dynamic> json) => KaraokeMark(
    unitText: json['unitText'] as String,
    startMs: json['startMs'] as int,
  );
}
```

Implement value equality/hash codes and safe name parsers for both enums.

- [ ] **Step 4: Extend Project and SubtitleLine atomically**

Add project defaults, copy/JSON fields, and line marks. Add an explicit
`withAdvancedKaraoke({required int startMs, required List<KaraokeMark> marks})`
method that changes the singing start and marks in one object replacement.
Timestamp edits and clearing must return a line with `karaokeMarks: const []`;
unchanged timestamp copies preserve marks.

- [ ] **Step 5: Run model tests and commit**

Run: `dart format lib/karaoke lib/models test/karaoke test/models && flutter test test/karaoke/karaoke_models_test.dart test/models/project_test.dart test/models/subtitle_line_test.dart`

Expected: PASS.

```bash
git add lib/karaoke/karaoke_models.dart lib/models/project.dart lib/models/subtitle_line.dart test/karaoke/karaoke_models_test.dart test/models/project_test.dart test/models/subtitle_line_test.dart
git commit -m "Persist karaoke project timing"
```

---

### Task 2: Tokenize text and resolve Easy/Advanced timing

**Files:**
- Create: `lib/karaoke/karaoke_timing.dart`
- Create: `test/karaoke/karaoke_timing_test.dart`

**Interfaces:**
- Consumes: `SubtitleLine`, `KaraokeMode`, `KaraokeMark`
- Produces: `KaraokeToken`, `KaraokeSegment`, `tokenizeKaraokeText`, `resolveKaraokeSegments`, and `karaokeTimingIssue`

- [ ] **Step 1: Add failing tokenizer tests**

Cover exact reconstruction and unit selection:

```dart
expect(tokenizeKaraokeText('Hello,  world!').map((e) => e.text),
    ['Hello,', '  world!']);
expect(tokenizeKaraokeText('你好世界').map((e) => e.text),
    ['你', '好', '世', '界']);
expect(tokenizeKaraokeText('「你好！」').map((e) => e.text),
    ['「你', '好！」']);
expect(tokenizeKaraokeText('!!!').map((e) => e.text), ['!!!']);
expect(tokenizeKaraokeText('').map((e) => e.text), ['']);
```

Each token's `text` includes preserved adjacent whitespace/punctuation so
`tokens.map((e) => e.text).join()` equals the source exactly.

- [ ] **Step 2: Add failing timing and validation tests**

```dart
final line = SubtitleLine(
  index: 0,
  text: 'one two three',
  startMs: 1000,
  endMs: 2000,
);
expect(
  resolveKaraokeSegments(line, KaraokeMode.karaokeEasy)
      .map((segment) => (segment.startMs, segment.endMs)),
  [(1000, 1333), (1333, 1666), (1666, 2000)],
);
```

Add Advanced cases for missing, stale, duplicate, decreasing, out-of-range,
and zero-duration marks, plus a valid exact sequence.

- [ ] **Step 3: Run timing tests and verify RED**

Run: `flutter test test/karaoke/karaoke_timing_test.dart`

Expected: FAIL because the timing service is absent.

- [ ] **Step 4: Implement the pure timing service**

Use these public values:

```dart
final class KaraokeToken {
  const KaraokeToken({required this.text, required this.identity});
  final String text;
  final String identity;
}

final class KaraokeSegment {
  const KaraokeSegment({required this.text, required this.startMs, required this.endMs});
  final String text;
  final int startMs;
  final int endMs;
}

enum KaraokeTimingIssue {
  invalidLineRange,
  missingMarks,
  staleMarks,
  nonIncreasingMarks,
  markOutsideLine,
  nonPositiveUnitDuration,
}
```

Tokenize by Unicode grapheme clusters, identify CJK graphemes, attach trailing
punctuation backward and leading punctuation forward, and retain whitespace in
the following token. Easy boundary `i` is
`startMs + ((endMs - startMs) * i ~/ unitCount)`; force the last end to
`endMs`. Advanced resolution must return no segments when validation reports an
issue.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/karaoke test/karaoke && flutter test test/karaoke`

Expected: PASS.

```bash
git add lib/karaoke/karaoke_timing.dart test/karaoke/karaoke_timing_test.dart
git commit -m "Add karaoke tokenization and timing"
```

---

### Task 3: Add session state for mode selection and Advanced marking

**Files:**
- Modify: `lib/state/marking_session.dart`
- Modify: `test/state/marking_session_test.dart`

**Interfaces:**
- Consumes: Task 1 model types and Task 2 tokenizer/validator
- Produces: `setKaraokeSettings`, `beginAdvancedMarking`, `recordKaraokeUnitStart`, `undoKaraokeUnitStart`, `restartAdvancedMarking`, `cancelAdvancedMarking`, and `AdvancedMarkingState`

- [ ] **Step 1: Add failing session tests**

Test that settings notify once, Easy needs no transient pass, and Advanced:

```dart
expect(session.beginAdvancedMarking(0), 3000); // existing start 5000 - 2000
expect(session.advancedMarking!.nextUnitIndex, 0);
expect(session.recordKaraokeUnitStart(5100), isTrue);
expect(session.lines[0].startMs, 5100);
expect(session.recordKaraokeUnitStart(6200), isTrue);
expect(session.undoKaraokeUnitStart(), 6200);
```

Add cases for media-zero clamping, invalid/out-of-order/after-end rejection,
completion, restart, cancellation, switching modes, line imports, direct
timestamp edits, and loading another project.

- [ ] **Step 2: Run the session suite and verify RED**

Run: `flutter test test/state/marking_session_test.dart`

Expected: FAIL because Advanced session APIs are absent.

- [ ] **Step 3: Implement transactional Advanced state**

Define:

```dart
@immutable
final class AdvancedMarkingState {
  const AdvancedMarkingState({
    required this.lineIndex,
    required this.tokens,
    required this.originalStartMs,
    required this.recordedStarts,
  });
  final int lineIndex;
  final List<KaraokeToken> tokens;
  final int originalStartMs;
  final List<int> recordedStarts;
  int get nextUnitIndex => recordedStarts.length;
  bool get isComplete => recordedStarts.length == tokens.length;
}
```

Persist accepted marks after every press so project saves and the line-list
`2/4` status preserve partial work. The first valid press atomically stores the
new line start and first mark with `SubtitleLine.withAdvancedKaraoke`; later
presses replace the ordered mark list. Cancellation keeps accepted marks but
ignores late playback results. Backspace returns the removed position for
seeking; removing the first mark restores `originalStartMs`, leaves `endMs`
unchanged, and clears the persisted mark list.

- [ ] **Step 4: Run tests and commit**

Run: `dart format lib/state test/state && flutter test test/state/marking_session_test.dart test/models/project_test.dart`

Expected: PASS.

```bash
git add lib/state/marking_session.dart test/state/marking_session_test.dart
git commit -m "Add advanced karaoke marking state"
```

---

### Task 4: Add Karaoke settings and Advanced keyboard workflow

**Files:**
- Create: `lib/ui/karaoke_settings_dialog.dart`
- Create: `test/ui/karaoke_settings_dialog_test.dart`
- Modify: `lib/keyboard/marking_key_handler.dart`
- Modify: `test/keyboard/marking_key_handler_test.dart`
- Modify: `lib/ui/marking_scaffold.dart`
- Modify: `test/ui/marking_scaffold_test.dart`

**Interfaces:**
- Consumes: Task 3 session APIs and `PlaybackControls`
- Produces: mode/pre-display dialog, line-level **Mark words**, Advanced Space/Backspace handling, Restart/Cancel controls

- [ ] **Step 1: Add failing settings-dialog tests**

Assert all three modes and five pre-display choices render, initial values are
selected, Cancel returns null, Save returns the selected pair, and Standard
mode disables pre-display without deleting its stored selection.

- [ ] **Step 2: Add failing Advanced keyboard and scaffold tests**

Test this event contract:

```dart
await tester.tap(find.text('Mark words'));
expect(fake.seekCalls.last, 3000);
expect(find.text('Press Space: one'), findsOneWidget);
fake.positionMs = 5100;
await tester.sendKeyEvent(LogicalKeyboardKey.space);
expect(find.text('Press Space: two'), findsOneWidget);
```

Use separate `KeyDownEvent` handling in Advanced mode so KeyUp does not create
a second mark. Verify Backspace undo/seek, Restart, Cancel, completing the last
unit, mode switching, review-mode isolation, and stale play/seek completion
after cancel or project replacement.

- [ ] **Step 3: Run focused UI/keyboard tests and verify RED**

Run: `flutter test test/ui/karaoke_settings_dialog_test.dart test/keyboard/marking_key_handler_test.dart test/ui/marking_scaffold_test.dart`

Expected: FAIL because settings and Advanced workflow UI are absent.

- [ ] **Step 4: Implement settings and playback coordination**

Add a Karaoke settings button beside Subtitle appearance in the review/actions
area. Show **Mark words** only for completed valid lines in Advanced mode.
Starting a pass must pause, seek to `max(0, startMs - 2000)`, confirm the
operation token is still current, then play. Advanced Space-down calls
`recordKaraokeUnitStart(controls.positionMs)`; Backspace calls undo and seeks to
the returned position or the two-second pre-roll. Completion pauses playback.

Use the existing review operation-generation pattern for every awaited
pause/seek/play call. Cancel the pass on mode change, line replacement, project
load, review exit, or widget disposal.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/ui lib/keyboard test/ui test/keyboard && flutter test test/ui/karaoke_settings_dialog_test.dart test/keyboard/marking_key_handler_test.dart test/ui/marking_scaffold_test.dart`

Expected: PASS.

```bash
git add lib/ui/karaoke_settings_dialog.dart lib/ui/marking_scaffold.dart lib/keyboard/marking_key_handler.dart test/ui/karaoke_settings_dialog_test.dart test/ui/marking_scaffold_test.dart test/keyboard/marking_key_handler_test.dart
git commit -m "Add karaoke marking workflow"
```

---

### Task 5: Render live karaoke preview and line status

**Files:**
- Create: `lib/ui/karaoke_preview.dart`
- Create: `test/ui/karaoke_preview_test.dart`
- Modify: `lib/ui/marking_scaffold.dart`
- Modify: `lib/ui/widgets/line_list_view.dart`
- Modify: `test/ui/marking_scaffold_test.dart`
- Modify: `test/ui/widgets/line_list_view_test.dart`

**Interfaces:**
- Consumes: resolved `KaraokeSegment` lists, playback position, project pre-display setting, selected font/size
- Produces: `KaraokePreview` with white/gold partial spans and deterministic alternating rows

- [ ] **Step 1: Add failing pure preview/widget tests**

At positions before singing, inside each segment, at exact boundaries, in
gaps, and after line end, assert the white/gold spans. For one-line-ahead,
assert line index parity selects a stable row and the next completed line is
white on the other row. Assert timed lead-in clamps to zero.

- [ ] **Step 2: Add failing line-list state tests**

Assert labels: `Karaoke ready`, `Word timing 2/4`, `Needs word timing`, and
`Invalid karaoke timing`; Standard mode must render no karaoke status.

- [ ] **Step 3: Run preview tests and verify RED**

Run: `flutter test test/ui/karaoke_preview_test.dart test/ui/widgets/line_list_view_test.dart test/ui/marking_scaffold_test.dart`

Expected: FAIL because karaoke preview/status widgets are absent.

- [ ] **Step 4: Implement preview from resolved segments**

`KaraokePreview` accepts `current`, optional `next`, `positionMs`, `fontFamily`,
and `fontSize`. Split the active token at grapheme proportion
`(positionMs - startMs) / (endMs - startMs)` for a left-to-right sweep; render
completed substrings gold (`Color(0xFFFFD700)`) and future substrings white.
Timed lead-in renders all-white text. Standard review continues using the
existing single-colour panel.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/ui test/ui && flutter test test/ui/karaoke_preview_test.dart test/ui/widgets/line_list_view_test.dart test/ui/marking_scaffold_test.dart`

Expected: PASS.

```bash
git add lib/ui/karaoke_preview.dart lib/ui/marking_scaffold.dart lib/ui/widgets/line_list_view.dart test/ui/karaoke_preview_test.dart test/ui/marking_scaffold_test.dart test/ui/widgets/line_list_view_test.dart
git commit -m "Add live karaoke preview"
```

---

### Task 6: Encode karaoke ASS with pre-display and alternating rows

**Files:**
- Modify: `lib/services/ass_codec.dart`
- Modify: `test/services/ass_codec_test.dart`
- Modify: `lib/services/ass_export_coordinator.dart`
- Modify: `test/services/ass_export_coordinator_test.dart`

**Interfaces:**
- Consumes: `Project` karaoke settings and resolved segments
- Produces: Standard-compatible `AssCodec.encodeProject(Project project, {required String fontFamily, required double fontSize})`

- [ ] **Step 1: Add failing ASS tests**

Assert Standard output remains byte-for-byte equal to existing fixtures. Add
Easy/Advanced expectations for gold primary `&H0000D7FF`, white secondary
`&H00FFFFFF`, `\kf` centisecond durations, a leading empty karaoke delay for
3/4/5-second pre-display, zero-clamped event start, and alternating Top/Bottom
styles/events for one-line-ahead.

- [ ] **Step 2: Add failing invalid-Advanced export tests**

The coordinator must return affected line numbers and write nothing when
Advanced timing is missing, stale, or invalid.

- [ ] **Step 3: Run ASS tests and verify RED**

Run: `flutter test test/services/ass_codec_test.dart test/services/ass_export_coordinator_test.dart`

Expected: FAIL because ASS encoding accepts only plain lines.

- [ ] **Step 4: Implement project-aware ASS encoding**

Keep the existing `encode` entry point with its lines, font-family, and
font-size parameters as the Standard compatibility API. Add project-aware
encoding that creates `Default`, `KaraokeTop`,
and `KaraokeBottom` styles. Convert millisecond segment boundaries to a sequence
of integer centisecond durations whose sum equals the rounded event duration;
assign rounding remainder to the final unit. Escape user text outside override
tags and never escape generated `\kf` tags.

For one-line-ahead, emit a white preview event for line `n + 1` beginning at
line `n`'s singing start on the row assigned to `n + 1`, plus the active
karaoke event for each line. Avoid duplicate visible text by ending each preview
exactly when its line's active event begins.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/services test/services && flutter test test/services/ass_codec_test.dart test/services/ass_export_coordinator_test.dart`

Expected: PASS.

```bash
git add lib/services/ass_codec.dart lib/services/ass_export_coordinator.dart test/services/ass_codec_test.dart test/services/ass_export_coordinator_test.dart
git commit -m "Export karaoke ASS subtitles"
```

---

### Task 7: Integrate karaoke warnings and FFmpeg burned-in export

**Files:**
- Modify: `lib/services/export_integration_support.dart`
- Modify: `test/services/export_integration_support_test.dart`
- Modify: `lib/services/ffmpeg_export_service.dart`
- Modify: `test/services/ffmpeg_export_service_test.dart`
- Modify: `lib/ui/home_screen.dart`
- Modify: `test/ui/marking_scaffold_test.dart`

**Interfaces:**
- Consumes: project-aware ASS encoder and karaoke validation
- Produces: omission warnings for SRT/selectable tracks and ASS-backed burned-in export

- [ ] **Step 1: Add failing warning tests**

Extend `ExportWarnings` with `karaokeOmitted` and affected Advanced line
numbers. Assert Standard wording is unchanged; karaoke SRT/selectable export
adds `Karaoke animation and pre-display will be omitted.` exactly once.

- [ ] **Step 2: Add failing FFmpeg tests**

Assert burned-in Karaoke writes a temporary `.ass` file containing `\kf`, uses
the existing escaped `ass=<subtitle-path>:fontsdir=<font-dir>` filter, and cleans it on success,
failure, and cancellation. Standard burned-in export must retain its current
behavior. Selectable export continues using SRT/mov_text and triggers omission
confirmation before starting FFmpeg.

- [ ] **Step 3: Run integration tests and verify RED**

Run: `flutter test test/services/export_integration_support_test.dart test/services/ffmpeg_export_service_test.dart test/ui/marking_scaffold_test.dart`

Expected: FAIL because export integration is not project-aware.

- [ ] **Step 4: Implement export routing**

Pass the full Project to export settings. In Standard mode, keep the existing
temporary SRT path. In Karaoke modes, burned-in export writes project-aware ASS
and passes it to FFmpeg with the bundled font directory. Reuse existing process
ownership, cancellation, output draining, and cleanup guarantees without
introducing a second process lifecycle.

HomeScreen must show karaoke-validation errors before file selection and show
the omission confirmation for SRT/selectable output. A declined warning starts
no write and no process.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/services lib/ui test/services test/ui && flutter test test/services/export_integration_support_test.dart test/services/ffmpeg_export_service_test.dart test/ui/marking_scaffold_test.dart`

Expected: PASS.

```bash
git add lib/services/export_integration_support.dart lib/services/ffmpeg_export_service.dart lib/ui/home_screen.dart test/services/export_integration_support_test.dart test/services/ffmpeg_export_service_test.dart test/ui/marking_scaffold_test.dart
git commit -m "Integrate karaoke video export"
```

---

### Task 8: Document karaoke workflow and verify the application

**Files:**
- Modify: `README.md`
- Modify: `lib/ui/stmarker_about_dialog.dart`
- Modify: `test/ui/stmarker_about_dialog_test.dart`

**Interfaces:**
- Consumes: completed user-visible feature
- Produces: user instructions, format limitations, and current About summary

- [ ] **Step 1: Update README and About copy**

Document Standard/Easy/Advanced workflows, the two-second Advanced pre-roll,
all pre-display choices, white-to-gold animation, CJK behavior, ASS/burned-in
support, and SRT/selectable limitations. Add `word-by-word karaoke timing` to
the About feature description while preserving author, GitHub, version, GPL,
and Noto licence content.

- [ ] **Step 2: Update About tests**

Assert the dialog contains `word-by-word karaoke timing` and all existing
application, author, GitHub, GPL, and font-licence assertions still pass.

- [ ] **Step 3: Run documentation/UI tests**

Run: `dart format lib/ui/stmarker_about_dialog.dart test/ui/stmarker_about_dialog_test.dart && flutter test test/ui/stmarker_about_dialog_test.dart && git diff --check`

Expected: PASS with no whitespace errors.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md lib/ui/stmarker_about_dialog.dart test/ui/stmarker_about_dialog_test.dart
git commit -m "Document karaoke mode"
```

- [ ] **Step 5: Run complete verification**

Run: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test && flutter build linux && git diff --check`

Expected: formatting changes zero files, analysis finds no issues, every test
passes, Linux release build exits zero, and diff check produces no output.

- [ ] **Step 6: Review scope**

Run: `git status --short && git log --oneline --decorate -10`

Expected: only the pre-existing `.superpowers/` scratch directory may remain
untracked; commits correspond to the eight tasks above with no unrelated files.

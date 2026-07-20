# Subtitle Typography and ASS Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent bundled-font appearance controls, portable styled ASS export, and matching FFmpeg burn-in typography.

**Architecture:** A single immutable font catalog owns IDs, labels, internal family names, and asset paths. Project/session state persists only the catalog ID and size; codecs remain pure; file packaging and Flutter asset loading sit behind injectable functions; the review UI consumes saved appearance directly.

**Tech Stack:** Dart 3.11, Flutter Material, Provider/ChangeNotifier, FFmpeg/libass, Noto CJK under SIL OFL 1.1, flutter_test

## Global Constraints

- Font size range is 16.0–64.0; default is 24.0.
- Default face ID is `noto_sans_cjk`; unknown IDs fall back to it.
- SRT and selectable-track export remain unstyled.
- ASS uses UTF-8, `PlayResX: 1280`, `PlayResY: 720`, centisecond timestamps, marked valid lines only, and explicit `\\N` line breaks.
- Burned-in export uses the selected bundled asset via `fontsdir`, `FontName`, and `FontSize` and cleans every temporary asset.
- Noto font binaries remain unmodified and are redistributed with `OFL.txt`.
- Existing review auto-follow and asynchronous playback ownership behavior must not change.

---

### Task 1: Pinned font assets and catalog

**Files:**
- Create: `assets/fonts/NotoSansCJKsc-Regular.otf`
- Create: `assets/fonts/NotoSerifCJKsc-Regular.otf`
- Create: `assets/fonts/NotoSansMonoCJKsc-Regular.otf`
- Create: `assets/fonts/OFL.txt`
- Create: `lib/subtitle_fonts/subtitle_font_catalog.dart`
- Create: `test/subtitle_fonts/subtitle_font_catalog_test.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `SubtitleFontFace`, `SubtitleFontCatalog.defaultFace`, `SubtitleFontCatalog.faces`, and `SubtitleFontCatalog.byId(String?)`

- [ ] **Step 1: Write failing catalog tests**

Test exactly three unique IDs, labels, family names, asset paths, default
resolution, unknown-ID fallback, and asset availability through `rootBundle`.
Expected family names are `Noto Sans CJK SC`, `Noto Serif CJK SC`, and
`Noto Sans Mono CJK SC`.

- [ ] **Step 2: Verify RED**

Run `flutter test test/subtitle_fonts/subtitle_font_catalog_test.dart`.
Expected: compilation failure because the catalog is missing.

- [ ] **Step 3: Download pinned official assets**

Download from Noto CJK commit
`f8d157532fbfaeda587e826d4cd5b21a49186f7c` using these raw repository paths:

```text
Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf
Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf
Sans/Mono/NotoSansMonoCJKsc-Regular.otf
Sans/LICENSE
```

Save the licence as `assets/fonts/OFL.txt`. Verify SHA-256:

```text
2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b  NotoSansCJKsc-Regular.otf
2a2eae2628df83556c54018c41e20fa532c1b862c5256ae8b3f23feb918d12ca  NotoSerifCJKsc-Regular.otf
ec04cc376b34887cedbdf84074e2e226ed2761eeabdcb9173fc1dd7bfd153ef7  NotoSansMonoCJKsc-Regular.otf
6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2  OFL.txt
```

- [ ] **Step 4: Implement catalog and pubspec declarations**

Use an immutable `SubtitleFontFace` with `id`, `label`, `familyName`, and
`assetPath`. Declare the three Flutter font families and `assets/fonts/OFL.txt`
in `pubspec.yaml`.

- [ ] **Step 5: Verify GREEN and commit**

Run the focused test and `flutter pub get`, then commit:

```bash
git add assets/fonts lib/subtitle_fonts pubspec.yaml pubspec.lock test/subtitle_fonts
git commit -m "Bundle Noto subtitle fonts"
```

### Task 2: Persistent subtitle appearance state

**Files:**
- Modify: `lib/models/project.dart`
- Modify: `lib/state/marking_session.dart`
- Modify: `test/models/project_test.dart`
- Modify: `test/state/marking_session_test.dart`
- Modify: `test/services/project_store_test.dart`

**Interfaces:**
- Produces: `Project.subtitleFontFamily`, `Project.subtitleFontSize`, and `MarkingSession.setSubtitleAppearance({required String fontFamily, required double fontSize})`
- Consumes: `SubtitleFontCatalog.byId`

- [ ] **Step 1: Write failing model/session tests**

Cover defaults, copyWith preservation/override, JSON round-trip, old JSON
defaults, unknown JSON ID fallback, JSON sizes below/above range clamped to
16/64, and a single session notification for updating both values.

- [ ] **Step 2: Verify RED**

Run the three focused test files. Expected: missing members and method.

- [ ] **Step 3: Implement validated persistence**

Add constants `defaultSubtitleFontSize = 24.0`, `minimumSubtitleFontSize =
16.0`, and `maximumSubtitleFontSize = 64.0`. Preserve the existing `const`
constructor and `copyWith`; validate external data in `fromJson` and the
session setter. Non-finite JSON sizes fall back to 24.0. Include both fields in
`toJson`.

- [ ] **Step 4: Implement atomic session update**

`setSubtitleAppearance` replaces the project once and calls listeners once.

- [ ] **Step 5: Verify and commit**

Run focused tests and commit the five files with message
`Persist subtitle appearance settings`.

### Task 3: Pure ASS codec

**Files:**
- Create: `lib/services/ass_codec.dart`
- Create: `test/services/ass_codec_test.dart`

**Interfaces:**
- Produces: `AssCodec.encode(List<SubtitleLine> lines, {required String fontFamily, required double fontSize}) -> String`

- [ ] **Step 1: Write failing codec tests**

Assert the exact script-info and V4+ style headers, `PlayResX/Y`, font name and
trimmed size formatting, list order, incomplete/invalid-line skipping,
centisecond timestamp rounding, preservation of commas in the final Text field,
brace and backslash escaping, and converting source newlines to `\\N`.

- [ ] **Step 2: Verify RED**

Run `flutter test test/services/ass_codec_test.dart`; expect missing codec.

- [ ] **Step 3: Implement encoder**

Use format sections `[Script Info]`, `[V4+ Styles]`, and `[Events]`. Use one
style named `Default`, alignment 2, margins 20, and UTF-8 string output.
Convert milliseconds to ASS `H:MM:SS.cc` by integer centisecond rounding.
Escape `\\` and `{`/`}` to prevent override-tag injection. Preserve commas:
ASS defines Text as the final event field, so later commas belong to the text
and do not change the fixed leading fields.

- [ ] **Step 4: Verify and commit**

Run codec tests and commit with `Add styled ASS encoder`.

### Task 4: Atomic ASS package export

**Files:**
- Create: `lib/services/asset_bytes_loader.dart`
- Create: `lib/services/ass_export_service.dart`
- Create: `test/services/ass_export_service_test.dart`

**Interfaces:**
- Produces: `typedef AssetBytesLoader = Future<Uint8List> Function(String assetPath)`
- Produces: `AssExportService.export({required String outputPath, required String content, required SubtitleFontFace face, required AssetBytesLoader loadAsset})`
- Produces: `AssExportService.companionDirectoryFor(String outputPath)`

- [ ] **Step 1: Write failing package tests**

Use real temporary directories and an in-memory loader. Verify `name.ass`,
`name_fonts/<font filename>`, and `name_fonts/OFL.txt`; verify byte identity;
verify companion-path derivation; simulate loader/write failure and assert old
destination package remains intact and temporary siblings are removed.

- [ ] **Step 2: Verify RED**

Run the new test file; expect missing service.

- [ ] **Step 3: Implement staged replacement**

Write ASS and companions beneath unique temporary sibling names. If prior
destinations exist, rename them to unique backups, rename staged outputs into
place, then delete backups. On failure, delete staged output and restore
backups. Expose `wouldReplaceCompanions(outputPath)` for the UI confirmation.

- [ ] **Step 4: Verify and commit**

Run focused tests and commit with `Add portable ASS package export`.

### Task 5: FFmpeg burned-in font integration

**Files:**
- Modify: `lib/services/ffmpeg_export_service.dart`
- Modify: `test/services/ffmpeg_export_service_test.dart`

**Interfaces:**
- Extends `export` with required `SubtitleFontFace subtitleFont`, `double subtitleFontSize`, and `AssetBytesLoader loadAsset`
- Extends `buildArguments` with nullable burned-in `fontsDirectory`, `fontFamily`, and `fontSize`

- [ ] **Step 1: Write failing argument and cleanup tests**

Assert burned-in filter contains escaped `fontsdir` plus
`force_style='FontName=...,FontSize=...'`; assert quotes, colons, commas, and
backslashes are escaped. Assert embedded mode arguments remain byte-for-byte
unchanged and does not request font bytes. Introduce an injectable process
starter test double so success, nonzero exit, start failure, and cancellation
all prove the temporary directory is removed.

- [ ] **Step 2: Verify RED**

Run FFmpeg service tests; expect new parameters/filter assertions to fail.

- [ ] **Step 3: Materialize burned assets only**

For burned-in mode, load the selected font and OFL bytes into the existing
temporary directory before starting FFmpeg. Pass that directory and validated
catalog family/size to `buildArguments`. Embedded mode writes only the SRT.
Keep cleanup in `finally` and preserve progress/cancellation behavior.

- [ ] **Step 4: Verify and commit**

Run FFmpeg tests and commit with `Apply subtitle fonts to burned video export`.

### Task 6: Appearance dialog and review panel

**Files:**
- Create: `lib/ui/subtitle_appearance_dialog.dart`
- Create: `test/ui/subtitle_appearance_dialog_test.dart`
- Modify: `lib/ui/marking_scaffold.dart`
- Modify: `test/ui/marking_scaffold_test.dart`

**Interfaces:**
- Produces: `Future<SubtitleAppearance?> showSubtitleAppearanceDialog(BuildContext context, {required SubtitleAppearance initial, required String previewText})`
- Consumes: session appearance update and font catalog

- [ ] **Step 1: Write failing dialog/panel tests**

Test dropdown choices, 16–64 slider, numeric value, live preview font/size,
reset, Cancel returning null, Save returning values, review-bar action opening
the dialog, and the panel applying saved family/size without disturbing blank
auto-follow gaps.

- [ ] **Step 2: Verify RED**

Run both focused widget files; expect missing dialog/action behavior.

- [ ] **Step 3: Implement isolated dialog state**

Use local `StatefulWidget` values. Reset changes only local state. Save returns
a small immutable `SubtitleAppearance`; caller invokes the single session
method. Use stable ValueKeys for dropdown, slider, preview, reset, and save.

- [ ] **Step 4: Wire review action and styled panel**

Add an appearance icon/button to the review bar. Use the current selected line
as preview text, falling back to `Subtitle preview 字幕 미리보기`. Apply the
saved catalog Flutter family and size to `_ReviewSubtitlePanel`.

- [ ] **Step 5: Verify and commit**

Run focused tests and existing auto-follow/race tests, then commit with
`Add subtitle appearance controls`.

### Task 7: HomeScreen ASS export and final integration

**Files:**
- Modify: `lib/ui/home_screen.dart`
- Modify: `README.md`
- Modify: `test/services/project_store_test.dart` if integration fixtures need appearance assertions

**Interfaces:**
- Consumes: `AssCodec`, `AssExportService`, `SubtitleFontCatalog`, and `rootBundle`

- [ ] **Step 1: Extract testable export coordination if required**

Keep file-picker UI thin. If HomeScreen cannot be widget-tested without the
real media backend, extract a pure/package coordinator accepting chosen path,
confirmation callback, and asset loader; test that instead of initializing
media_kit.

- [ ] **Step 2: Add failing integration tests**

Verify warning confirmation parity with SRT, companion replacement prompt,
selected font/style passed to the codec/package service, cancellation without
writes, success message paths, and burned-video call receives the same font
settings and root-bundle loader.

- [ ] **Step 3: Add Export ASS action**

Add an AppBar action with tooltip `Export ASS`. Choose `export.ass`, confirm
warnings, confirm companion replacement when needed, encode, and export using
`rootBundle.load(...).buffer.asUint8List()`. Update video export to pass the
same loader/font/size.

- [ ] **Step 4: Update documentation and licence attribution**

Document appearance settings, SRT limitations, ASS-plus-font export, font
installation/attachment note, burned-in styling, ~57 MB size impact, and Noto
OFL attribution in README/About as appropriate.

- [ ] **Step 5: Full verification**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux
git diff --check
```

Expected: no formatting changes, no analyzer issues, all tests pass, Linux
release build succeeds with font assets present, and diff check is empty.

- [ ] **Step 6: Commit integration**

```bash
git add lib test README.md
git commit -m "Add ASS export with portable fonts"
```

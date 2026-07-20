# Subtitle Marker (Desktop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working Flutter desktop app (Linux/Windows/macOS) that lets a user load a video/audio file, load line-by-line lyrics/subtitle text, hand-time each line by holding Space while it plays, and export the result as a standard `.srt` file.

**Architecture:** A pure-Dart core (models, SRT/LRC codecs, project persistence, sequential marking-pointer state machine, keyboard-to-session mapping) that is fully unit/widget-tested without any media dependency, plus a thin Flutter UI layer wired to a `media_kit`-backed player for real playback. The marking screen's layout and keyboard wiring (`MarkingScaffold`) is decoupled from the concrete player behind a `PlaybackControls` interface, so the core interaction loop is testable with a fake; only the composition root (`HomeScreen`, `main.dart`) touches real `media_kit`/`file_picker`.

**Tech Stack:** Flutter (stable channel, currently 3.41.6 / Dart 3.11.4 on this machine), `media_kit` + `media_kit_video` + `media_kit_libs_video` (libmpv-backed desktop playback), `provider` (state), `file_picker` (open/save dialogs).

## Global Constraints

- Repo root and Flutter project root are the same directory: `/home/wanleung/Projects/stmaker`. The **directory is named `stmaker`** (no "r") but the **pub package / app name is `stmarker`** (matching the GitHub repo `wanleung/stmarker`) — this is intentional, not a typo to "fix".
- This plan targets **desktop only** (Linux, Windows, macOS) via `media_kit`. Flutter Web is explicitly out of scope here — `media_kit` doesn't run on web, so a browser `<video>`-backed implementation of `PlaybackControls` is a separate future plan.
- Pin these dependency versions in `pubspec.yaml` (latest as of 2026-07-20): `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7`, `provider: ^6.1.5+1`, `file_picker: ^11.0.2`.
- **Sandbox note for whoever executes this plan:** the current execution environment has no display server (`$DISPLAY` is unset) and `sudo` requires an interactive password that isn't available non-interactively. This means `flutter run -d linux` / `flutter build linux` and any GUI smoke test **cannot be completed by an automated executor here**. `flutter analyze` and `flutter test` (unit + widget tests) do **not** need the Linux embedder toolchain or a display and run fine headless — treat those as the automated verification path for every task. Tasks that can only be verified with a real display/media file are explicitly marked **Manual verification** and should be handed to the user to run on their own machine, with the exact steps given.
- License is already GPL-3.0-or-later at the repo root (`LICENSE`, committed) — no per-file header is required.
- Commit after every task using the repo's existing `master` branch (already initialized, already has `LICENSE`, `README.md`, `docs/`).

---

### Task 1: Flutter project scaffolding & dependencies

**Files:**
- Create: `pubspec.yaml` (via `flutter create`, then edited)
- Create: `lib/main.dart` (via `flutter create`, then replaced)
- Create: `.gitignore` (via `flutter create`)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a Flutter project that `flutter analyze` and `flutter test` run against cleanly; `flutter pub get` resolves `media_kit`, `media_kit_video`, `media_kit_libs_video`, `provider`, `file_picker`.

- [ ] **Step 1: Install the Linux desktop build toolchain (manual — needs interactive sudo)**

This machine already has `cmake`. It is missing `clang++`, `ninja`, GTK3 dev headers, and (for `file_picker`'s Linux file dialogs) `zenity`. Because `sudo` here requires an interactive password, run this yourself in a terminal on this machine (not something the plan executor can run non-interactively):

```bash
sudo apt-get update
sudo apt-get install -y clang ninja-build libgtk-3-dev pkg-config zenity
```

Then confirm:

```bash
flutter doctor
```

Expected: the "Linux toolchain" line shows `[✓]`. If you're executing this plan as an automated agent and this step isn't done yet, skip ahead — Steps 2–7 below (`flutter create`, adding dependencies, `flutter pub get`, `flutter analyze`) do not require the Linux toolchain or a display, only actually compiling/running the native Linux binary does.

- [ ] **Step 2: Scaffold the Flutter project in the existing repo root**

```bash
cd /home/wanleung/Projects/stmaker
flutter create --platforms=linux,windows,macos --project-name=stmarker --org=com.github.wanleung --overwrite .
```

Expected: creates `lib/`, `linux/`, `windows/`, `macos/`, `pubspec.yaml`, `analysis_options.yaml`, `test/widget_test.dart`, `.gitignore`, without touching `LICENSE`, `README.md`, or `docs/`.

- [ ] **Step 3: Remove the generated placeholder widget test**

```bash
rm test/widget_test.dart
```

(It tests the default counter app, which we're about to replace.)

- [ ] **Step 4: Add dependencies to `pubspec.yaml`**

Open `pubspec.yaml` and add these four lines under the existing `dependencies:` key (alongside `flutter:` and `cupertino_icons:`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
  provider: ^6.1.5+1
  file_picker: ^11.0.2
```

- [ ] **Step 5: Fetch dependencies**

```bash
flutter pub get
```

Expected: exits 0 and lists the resolved packages including `media_kit`, `provider`, `file_picker`.

- [ ] **Step 6: Replace `lib/main.dart` with a minimal placeholder**

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const StmarkerApp());
}

class StmarkerApp extends StatelessWidget {
  const StmarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stmarker',
      home: Scaffold(
        appBar: AppBar(title: const Text('stmarker')),
        body: const Center(child: Text('stmarker')),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify the project analyzes cleanly**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Scaffold Flutter desktop project with media_kit/provider/file_picker"
```

---

### Task 2: `SubtitleLine` model

**Files:**
- Create: `lib/models/subtitle_line.dart`
- Test: `test/models/subtitle_line_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class SubtitleLine { final int index; final String text; final int? startMs; final int? endMs; bool get isFullyMarked; SubtitleLine copyWith({int? startMs, int? endMs}); SubtitleLine withExactTimestamps({int? startMs, int? endMs}); SubtitleLine clearTimestamps(); Map<String,dynamic> toJson(); factory SubtitleLine.fromJson(Map<String,dynamic>); }` with value equality (`==`/`hashCode`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/subtitle_line_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  test('isFullyMarked is false when either timestamp is missing', () {
    const line = SubtitleLine(index: 0, text: 'hello');
    expect(line.isFullyMarked, isFalse);
  });

  test('isFullyMarked is true when both timestamps are set', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    expect(line.isFullyMarked, isTrue);
  });

  test('copyWith only overrides provided fields', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100);
    final updated = line.copyWith(endMs: 200);
    expect(updated, const SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200));
  });

  test('withExactTimestamps replaces both fields even with null', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    final updated = line.withExactTimestamps(startMs: 50);
    expect(updated, const SubtitleLine(index: 0, text: 'hello', startMs: 50));
  });

  test('clearTimestamps resets both to null', () {
    const line = SubtitleLine(index: 0, text: 'hello', startMs: 100, endMs: 200);
    expect(line.clearTimestamps(), const SubtitleLine(index: 0, text: 'hello'));
  });

  test('toJson/fromJson round-trip with timestamps set', () {
    const line = SubtitleLine(index: 3, text: 'hi there', startMs: 1000, endMs: 2500);
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });

  test('toJson/fromJson round-trip with null timestamps', () {
    const line = SubtitleLine(index: 3, text: 'hi there');
    final restored = SubtitleLine.fromJson(line.toJson());
    expect(restored, line);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

```bash
flutter test test/models/subtitle_line_test.dart
```

Expected: FAIL — `Error: Not found: 'package:stmarker/models/subtitle_line.dart'` (file doesn't exist yet).

- [ ] **Step 3: Implement `SubtitleLine`**

```dart
// lib/models/subtitle_line.dart
class SubtitleLine {
  const SubtitleLine({
    required this.index,
    required this.text,
    this.startMs,
    this.endMs,
  });

  final int index;
  final String text;
  final int? startMs;
  final int? endMs;

  bool get isFullyMarked => startMs != null && endMs != null;

  /// Overrides only the fields provided; omitted fields keep their value.
  SubtitleLine copyWith({int? startMs, int? endMs}) {
    return SubtitleLine(
      index: index,
      text: text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  /// Replaces both timestamps outright, including with null — unlike
  /// [copyWith], which can't be used to clear a single field back to null.
  SubtitleLine withExactTimestamps({int? startMs, int? endMs}) {
    return SubtitleLine(index: index, text: text, startMs: startMs, endMs: endMs);
  }

  SubtitleLine clearTimestamps() {
    return SubtitleLine(index: index, text: text);
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory SubtitleLine.fromJson(Map<String, dynamic> json) => SubtitleLine(
        index: json['index'] as int,
        text: json['text'] as String,
        startMs: json['startMs'] as int?,
        endMs: json['endMs'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is SubtitleLine &&
      other.index == index &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(index, text, startMs, endMs);
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

```bash
flutter test test/models/subtitle_line_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/subtitle_line.dart test/models/subtitle_line_test.dart
git commit -m "Add SubtitleLine model"
```

---

### Task 3: `Project` model

**Files:**
- Create: `lib/models/project.dart`
- Test: `test/models/project_test.dart`

**Interfaces:**
- Consumes: `SubtitleLine` (Task 2) — its `toJson`/`fromJson`.
- Produces: `class Project { final String mediaPath; final double playbackRate; final List<SubtitleLine> lines; Project copyWith({String? mediaPath, double? playbackRate, List<SubtitleLine>? lines}); Map<String,dynamic> toJson(); factory Project.fromJson(Map<String,dynamic>); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/project_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';

void main() {
  test('playbackRate defaults to 1.0', () {
    const project = Project(mediaPath: '/tmp/song.mp3', lines: []);
    expect(project.playbackRate, 1.0);
  });

  test('copyWith only overrides provided fields', () {
    const project = Project(mediaPath: '/tmp/a.mp3', playbackRate: 1.0, lines: []);
    final updated = project.copyWith(playbackRate: 0.75);
    expect(updated.mediaPath, '/tmp/a.mp3');
    expect(updated.playbackRate, 0.75);
  });

  test('toJson/fromJson round-trip', () {
    const project = Project(
      mediaPath: '/tmp/song.mp3',
      playbackRate: 0.75,
      lines: [
        SubtitleLine(index: 0, text: 'line one', startMs: 100, endMs: 900),
        SubtitleLine(index: 1, text: 'line two'),
      ],
    );
    final restored = Project.fromJson(project.toJson());
    expect(restored.mediaPath, project.mediaPath);
    expect(restored.playbackRate, project.playbackRate);
    expect(restored.lines, project.lines);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/models/project_test.dart
```

Expected: FAIL — `Project` doesn't exist yet.

- [ ] **Step 3: Implement `Project`**

```dart
// lib/models/project.dart
import 'subtitle_line.dart';

class Project {
  const Project({
    required this.mediaPath,
    this.playbackRate = 1.0,
    required this.lines,
  });

  final String mediaPath;
  final double playbackRate;
  final List<SubtitleLine> lines;

  Project copyWith({String? mediaPath, double? playbackRate, List<SubtitleLine>? lines}) {
    return Project(
      mediaPath: mediaPath ?? this.mediaPath,
      playbackRate: playbackRate ?? this.playbackRate,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaPath': mediaPath,
        'playbackRate': playbackRate,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        mediaPath: json['mediaPath'] as String,
        playbackRate: (json['playbackRate'] as num?)?.toDouble() ?? 1.0,
        lines: (json['lines'] as List<dynamic>)
            .map((raw) => SubtitleLine.fromJson(raw as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/models/project_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/project.dart test/models/project_test.dart
git commit -m "Add Project model"
```

---

### Task 4: SRT codec (encode + decode)

**Files:**
- Create: `lib/services/srt_codec.dart`
- Test: `test/services/srt_codec_test.dart`

**Interfaces:**
- Consumes: `SubtitleLine` (Task 2).
- Produces: `class SrtCodec { static String encode(List<SubtitleLine> lines); static List<SubtitleLine> decode(String content); }`. `encode` skips lines where `isFullyMarked` is false and renumbers 1..N in the output. `decode` assigns fresh `index` values 0..N-1 to whatever it parses.

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/srt_codec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/srt_codec.dart';

void main() {
  test('encode formats a single fully-marked line correctly', () {
    const lines = [
      SubtitleLine(index: 0, text: "it's been a while", startMs: 92100, endMs: 94800),
    ];
    expect(SrtCodec.encode(lines), "1\n00:01:32,100 --> 00:01:34,800\nit's been a while\n");
  });

  test('encode skips lines missing a start or end, renumbering what remains', () {
    const lines = [
      SubtitleLine(index: 0, text: 'no timing'),
      SubtitleLine(index: 1, text: 'only start', startMs: 1000),
      SubtitleLine(index: 2, text: 'complete', startMs: 2000, endMs: 3000),
    ];
    expect(SrtCodec.encode(lines), "1\n00:00:02,000 --> 00:00:03,000\ncomplete\n");
  });

  test('decode parses a two-entry SRT file', () {
    const content = '1\n'
        '00:01:32,100 --> 00:01:34,800\n'
        "it's been a while\n"
        '\n'
        '2\n'
        '00:01:35,000 --> 00:01:37,200\n'
        "since I've seen your face\n";
    expect(SrtCodec.decode(content), const [
      SubtitleLine(index: 0, text: "it's been a while", startMs: 92100, endMs: 94800),
      SubtitleLine(index: 1, text: "since I've seen your face", startMs: 95000, endMs: 97200),
    ]);
  });

  test('decode ignores malformed blocks without a valid time line', () {
    const content = '1\nnot a timestamp\nsome text\n';
    expect(SrtCodec.decode(content), isEmpty);
  });

  test('encode then decode round-trips timestamps and text', () {
    const original = [
      SubtitleLine(index: 0, text: 'line one', startMs: 500, endMs: 1500),
      SubtitleLine(index: 1, text: 'line two', startMs: 1600, endMs: 3000),
    ];
    expect(SrtCodec.decode(SrtCodec.encode(original)), original);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/services/srt_codec_test.dart
```

Expected: FAIL — `SrtCodec` doesn't exist yet.

- [ ] **Step 3: Implement `SrtCodec`**

```dart
// lib/services/srt_codec.dart
import '../models/subtitle_line.dart';

class SrtCodec {
  const SrtCodec._();

  static final RegExp _timeLine = RegExp(
    r'^(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})',
  );

  static String encode(List<SubtitleLine> lines) {
    final marked = lines.where((line) => line.isFullyMarked).toList();
    final buffer = StringBuffer();
    for (var i = 0; i < marked.length; i++) {
      final line = marked[i];
      buffer.writeln(i + 1);
      buffer.writeln('${_formatTimestamp(line.startMs!)} --> ${_formatTimestamp(line.endMs!)}');
      buffer.writeln(line.text);
      if (i != marked.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  static List<SubtitleLine> decode(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return [];
    final blocks = normalized.split(RegExp(r'\n{2,}'));
    final result = <SubtitleLine>[];
    for (final rawBlock in blocks) {
      final blockLines = rawBlock.trim().split('\n');
      if (blockLines.length < 2) continue;
      final match = _timeLine.firstMatch(blockLines[1].trim());
      if (match == null) continue;
      final startMs = _msFromGroups(match, 1);
      final endMs = _msFromGroups(match, 5);
      final text = blockLines.sublist(2).join('\n');
      result.add(SubtitleLine(index: result.length, text: text, startMs: startMs, endMs: endMs));
    }
    return result;
  }

  static int _msFromGroups(RegExpMatch match, int startGroup) {
    final hours = int.parse(match.group(startGroup)!);
    final minutes = int.parse(match.group(startGroup + 1)!);
    final seconds = int.parse(match.group(startGroup + 2)!);
    final millis = int.parse(match.group(startGroup + 3)!);
    return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
  }

  static String _formatTimestamp(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    String pad2(int n) => n.toString().padLeft(2, '0');
    String pad3(int n) => n.toString().padLeft(3, '0');
    return '${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)},${pad3(millis)}';
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/services/srt_codec_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/srt_codec.dart test/services/srt_codec_test.dart
git commit -m "Add SRT encode/decode codec"
```

---

### Task 5: LRC codec (decode)

**Files:**
- Create: `lib/services/lrc_codec.dart`
- Test: `test/services/lrc_codec_test.dart`

**Interfaces:**
- Consumes: `SubtitleLine` (Task 2).
- Produces: `class LrcCodec { static List<SubtitleLine> decode(String content); }`. Parses `[mm:ss.xx]` or `[mm:ss.xxx]` tagged lines into `SubtitleLine`s with `startMs` set and `endMs` left `null` (LRC has no end times); non-timestamp lines (metadata tags like `[ar:...]`, blank lines) are skipped.

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/lrc_codec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/lrc_codec.dart';

void main() {
  test('decode parses centisecond timestamps into startMs, leaving endMs null', () {
    const content = "[ar:Someone]\n[01:32.10]it's been a while\n[01:35.00]since I've seen your face\n";
    expect(LrcCodec.decode(content), const [
      SubtitleLine(index: 0, text: "it's been a while", startMs: 92100),
      SubtitleLine(index: 1, text: "since I've seen your face", startMs: 95000),
    ]);
  });

  test('decode supports millisecond-precision tags', () {
    const content = '[00:02.500]precise line';
    expect(LrcCodec.decode(content), const [SubtitleLine(index: 0, text: 'precise line', startMs: 2500)]);
  });

  test('decode ignores lines with no valid time tag', () {
    const content = '[00:01.00]kept\nnot a tag at all\n';
    expect(LrcCodec.decode(content), const [SubtitleLine(index: 0, text: 'kept', startMs: 1000)]);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/services/lrc_codec_test.dart
```

Expected: FAIL — `LrcCodec` doesn't exist yet.

- [ ] **Step 3: Implement `LrcCodec`**

```dart
// lib/services/lrc_codec.dart
import '../models/subtitle_line.dart';

class LrcCodec {
  const LrcCodec._();

  static final RegExp _tag = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

  static List<SubtitleLine> decode(String content) {
    final result = <SubtitleLine>[];
    final rawLines = content.replaceAll('\r\n', '\n').split('\n');
    for (final rawLine in rawLines) {
      final match = _tag.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3)!;
      final millis = fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;
      final startMs = (minutes * 60 + seconds) * 1000 + millis;
      result.add(SubtitleLine(index: result.length, text: text, startMs: startMs));
    }
    return result;
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/services/lrc_codec_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/lrc_codec.dart test/services/lrc_codec_test.dart
git commit -m "Add LRC decode codec"
```

---

### Task 6: `ProjectStore` (save/load project JSON)

**Files:**
- Create: `lib/services/project_store.dart`
- Test: `test/services/project_store_test.dart`

**Interfaces:**
- Consumes: `Project` (Task 3).
- Produces: `class ProjectStore { static Future<void> save(Project project, String filePath); static Future<Project> load(String filePath); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/project_store_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/services/project_store.dart';

void main() {
  test('save then load restores an equivalent project', () async {
    final tempDir = await Directory.systemTemp.createTemp('stmarker_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final filePath = '${tempDir.path}/session.stmproj';

    const project = Project(
      mediaPath: '/home/user/song.mp3',
      playbackRate: 0.75,
      lines: [
        SubtitleLine(index: 0, text: 'line one', startMs: 100, endMs: 900),
        SubtitleLine(index: 1, text: 'line two'),
      ],
    );

    await ProjectStore.save(project, filePath);
    final restored = await ProjectStore.load(filePath);

    expect(restored.mediaPath, project.mediaPath);
    expect(restored.playbackRate, project.playbackRate);
    expect(restored.lines, project.lines);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/services/project_store_test.dart
```

Expected: FAIL — `ProjectStore` doesn't exist yet.

- [ ] **Step 3: Implement `ProjectStore`**

```dart
// lib/services/project_store.dart
import 'dart:convert';
import 'dart:io';

import '../models/project.dart';

class ProjectStore {
  const ProjectStore._();

  static Future<void> save(Project project, String filePath) async {
    final file = File(filePath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(project.toJson()));
  }

  static Future<Project> load(String filePath) async {
    final content = await File(filePath).readAsString();
    return Project.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/services/project_store_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/project_store.dart test/services/project_store_test.dart
git commit -m "Add ProjectStore save/load"
```

---

### Task 7: `MarkingSession` (sequential marking state machine)

**Files:**
- Create: `lib/state/marking_session.dart`
- Test: `test/state/marking_session_test.dart`

**Interfaces:**
- Consumes: `Project`, `SubtitleLine` (Tasks 2–3).
- Produces:
  ```dart
  class MarkingSession extends ChangeNotifier {
    MarkingSession(Project project);
    Project get project;
    List<SubtitleLine> get lines;
    int? get currentIndex; // first not-fully-marked line, or null if all marked
    void markStart(int positionMs);
    void markEnd(int positionMs);
    int? redoCurrentLine(); // returns seek target (previous startMs) or null
    void setLineTimestamps(int index, {int? startMs, int? endMs});
    void importLines(List<SubtitleLine> newLines);
    void setMediaPath(String path);
    void setPlaybackRate(double rate);
    void loadProject(Project project);
  }
  ```
  This is the exact API `MarkingKeyHandler` (Task 8), `LineListView` (Task 10), and the UI layer (Tasks 12–13) call.

- [ ] **Step 1: Write the failing tests**

```dart
// test/state/marking_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';

Project _project(List<SubtitleLine> lines) => Project(mediaPath: '/tmp/x.mp3', lines: lines);

void main() {
  test('currentIndex starts at the first unmarked line', () {
    final session = MarkingSession(_project(const [
      SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100),
      SubtitleLine(index: 1, text: 'b'),
    ]));
    expect(session.currentIndex, 1);
  });

  test('markStart sets startMs on the current line only', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a')]));
    session.markStart(500);
    expect(session.lines[0].startMs, 500);
    expect(session.lines[0].endMs, isNull);
    expect(session.currentIndex, 0);
  });

  test('markStart is a no-op if start is already set', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a', startMs: 500)]));
    session.markStart(999);
    expect(session.lines[0].startMs, 500);
  });

  test('markEnd sets endMs and advances currentIndex to the next line', () {
    final session = MarkingSession(_project(const [
      SubtitleLine(index: 0, text: 'a', startMs: 100),
      SubtitleLine(index: 1, text: 'b'),
    ]));
    session.markEnd(700);
    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a', startMs: 100, endMs: 700));
    expect(session.currentIndex, 1);
  });

  test('markEnd on an import-provided start-only line still advances', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a', startMs: 200)]));
    expect(session.currentIndex, 0);
    session.markEnd(900);
    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a', startMs: 200, endMs: 900));
    expect(session.currentIndex, isNull);
  });

  test('currentIndex is null once every line is fully marked', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100)]));
    expect(session.currentIndex, isNull);
  });

  test('redoCurrentLine clears timestamps and returns the previous start as seek target', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a', startMs: 300, endMs: 900)]));
    final seekTarget = session.redoCurrentLine();
    expect(seekTarget, 300);
    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
    expect(session.currentIndex, 0);
  });

  test('redoCurrentLine returns null seek target when nothing was marked yet', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a')]));
    expect(session.redoCurrentLine(), isNull);
  });

  test('setLineTimestamps edits an arbitrary row without disturbing the sequential pointer', () {
    final session = MarkingSession(_project(const [
      SubtitleLine(index: 0, text: 'a'),
      SubtitleLine(index: 1, text: 'b', startMs: 100, endMs: 200),
    ]));
    expect(session.currentIndex, 0);
    session.setLineTimestamps(1, startMs: 150, endMs: 250);
    expect(session.lines[1], const SubtitleLine(index: 1, text: 'b', startMs: 150, endMs: 250));
    expect(session.currentIndex, 0);
  });

  test('importLines replaces all lines and resets the pointer', () {
    final session = MarkingSession(_project(const [SubtitleLine(index: 0, text: 'a', startMs: 0, endMs: 100)]));
    session.importLines(const [
      SubtitleLine(index: 0, text: 'new a'),
      SubtitleLine(index: 1, text: 'new b'),
    ]);
    expect(session.lines.map((l) => l.text), ['new a', 'new b']);
    expect(session.currentIndex, 0);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/state/marking_session_test.dart
```

Expected: FAIL — `MarkingSession` doesn't exist yet.

- [ ] **Step 3: Implement `MarkingSession`**

```dart
// lib/state/marking_session.dart
import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../models/subtitle_line.dart';

class MarkingSession extends ChangeNotifier {
  MarkingSession(this._project) : _currentIndex = _firstUnmarkedIndex(_project.lines);

  Project _project;
  int _currentIndex;

  Project get project => _project;
  List<SubtitleLine> get lines => _project.lines;

  /// Index of the line space-down/space-up currently act on, or null once
  /// every line is fully marked.
  int? get currentIndex => _currentIndex < _project.lines.length ? _currentIndex : null;

  static int _firstUnmarkedIndex(List<SubtitleLine> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].isFullyMarked) return i;
    }
    return lines.length;
  }

  void markStart(int positionMs) {
    final idx = currentIndex;
    if (idx == null) return;
    final line = _project.lines[idx];
    if (line.startMs != null) return;
    _replaceLine(idx, line.copyWith(startMs: positionMs));
  }

  void markEnd(int positionMs) {
    final idx = currentIndex;
    if (idx == null) return;
    final line = _project.lines[idx];
    _replaceLine(idx, line.copyWith(endMs: positionMs));
  }

  /// Clears the current line's timestamps so it can be re-marked. Returns
  /// where the player should seek back to: the line's previous start time,
  /// or null if nothing had been marked yet (caller picks a fallback).
  int? redoCurrentLine() {
    final idx = currentIndex;
    if (idx == null) return null;
    final line = _project.lines[idx];
    final seekTarget = line.startMs;
    _replaceLine(idx, line.clearTimestamps());
    return seekTarget;
  }

  /// Directly sets a line's timestamps from the review/edit table,
  /// independent of the sequential current-line pointer.
  void setLineTimestamps(int index, {int? startMs, int? endMs}) {
    final line = _project.lines[index];
    _replaceLine(index, line.withExactTimestamps(startMs: startMs, endMs: endMs));
  }

  void importLines(List<SubtitleLine> newLines) {
    _project = _project.copyWith(lines: newLines);
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }

  void setMediaPath(String path) {
    _project = _project.copyWith(mediaPath: path);
    notifyListeners();
  }

  void setPlaybackRate(double rate) {
    _project = _project.copyWith(playbackRate: rate);
    notifyListeners();
  }

  void loadProject(Project project) {
    _project = project;
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }

  void _replaceLine(int index, SubtitleLine newLine) {
    final updated = List<SubtitleLine>.from(_project.lines);
    updated[index] = newLine;
    _project = _project.copyWith(lines: updated);
    _currentIndex = _firstUnmarkedIndex(_project.lines);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/state/marking_session_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/state/marking_session.dart test/state/marking_session_test.dart
git commit -m "Add MarkingSession sequential marking state machine"
```

---

### Task 8: `MarkingKeyHandler` (space/backspace → session mapping)

**Files:**
- Create: `lib/keyboard/marking_key_handler.dart`
- Test: `test/keyboard/marking_key_handler_test.dart`

**Interfaces:**
- Consumes: `MarkingSession` (Task 7).
- Produces:
  ```dart
  class MarkingKeyHandler {
    MarkingKeyHandler({
      required MarkingSession session,
      required int Function() getPositionMs,
      required void Function(int positionMs) seekTo,
      int redoFallbackOffsetMs = 1500,
    });
    bool handleKeyEvent(KeyEvent event); // true if it consumed the key
  }
  ```

- [ ] **Step 1: Write the failing tests**

```dart
// test/keyboard/marking_key_handler_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/keyboard/marking_key_handler.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';

KeyDownEvent _spaceDown() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: LogicalKeyboardKey.space,
      timeStamp: Duration.zero,
    );

KeyUpEvent _spaceUp() => const KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: LogicalKeyboardKey.space,
      timeStamp: Duration.zero,
    );

KeyDownEvent _backspaceDown() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.backspace,
      logicalKey: LogicalKeyboardKey.backspace,
      timeStamp: Duration.zero,
    );

void main() {
  test('space down marks the current line start at the live position', () {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [SubtitleLine(index: 0, text: 'a')]));
    var position = 0;
    final handler = MarkingKeyHandler(session: session, getPositionMs: () => position, seekTo: (_) {});

    position = 1200;
    final handled = handler.handleKeyEvent(_spaceDown());

    expect(handled, isTrue);
    expect(session.lines[0].startMs, 1200);
  });

  test('space up marks the current line end and advances', () {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'a'),
      SubtitleLine(index: 1, text: 'b'),
    ]));
    var position = 0;
    final handler = MarkingKeyHandler(session: session, getPositionMs: () => position, seekTo: (_) {});

    handler.handleKeyEvent(_spaceDown());
    position = 3400;
    handler.handleKeyEvent(_spaceUp());

    expect(session.lines[0].endMs, 3400);
    expect(session.currentIndex, 1);
  });

  test('backspace clears the current line and seeks to its previous start', () {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'a', startMs: 500, endMs: 900),
    ]));
    int? seekedTo;
    final handler = MarkingKeyHandler(session: session, getPositionMs: () => 900, seekTo: (ms) => seekedTo = ms);

    handler.handleKeyEvent(_backspaceDown());

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'a'));
    expect(seekedTo, 500);
  });

  test('backspace with nothing marked yet seeks back by the fallback offset', () {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [SubtitleLine(index: 0, text: 'a')]));
    int? seekedTo;
    final handler = MarkingKeyHandler(
      session: session,
      getPositionMs: () => 2000,
      seekTo: (ms) => seekedTo = ms,
      redoFallbackOffsetMs: 1500,
    );

    handler.handleKeyEvent(_backspaceDown());

    expect(seekedTo, 500);
  });

  test('unrelated keys are not handled', () {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [SubtitleLine(index: 0, text: 'a')]));
    final handler = MarkingKeyHandler(session: session, getPositionMs: () => 0, seekTo: (_) {});
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );
    expect(handler.handleKeyEvent(event), isFalse);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/keyboard/marking_key_handler_test.dart
```

Expected: FAIL — `MarkingKeyHandler` doesn't exist yet.

- [ ] **Step 3: Implement `MarkingKeyHandler`**

```dart
// lib/keyboard/marking_key_handler.dart
import 'package:flutter/services.dart';

import '../state/marking_session.dart';

class MarkingKeyHandler {
  MarkingKeyHandler({
    required this.session,
    required this.getPositionMs,
    required this.seekTo,
    this.redoFallbackOffsetMs = 1500,
  });

  final MarkingSession session;
  final int Function() getPositionMs;
  final void Function(int positionMs) seekTo;
  final int redoFallbackOffsetMs;

  bool handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        session.markStart(getPositionMs());
        return true;
      }
      if (event is KeyUpEvent) {
        session.markEnd(getPositionMs());
        return true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.backspace && event is KeyDownEvent) {
      final seekTarget = session.redoCurrentLine();
      final fallback = getPositionMs() - redoFallbackOffsetMs;
      seekTo(seekTarget ?? (fallback < 0 ? 0 : fallback));
      return true;
    }
    return false;
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/keyboard/marking_key_handler_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/keyboard/marking_key_handler.dart test/keyboard/marking_key_handler_test.dart
git commit -m "Add MarkingKeyHandler for space/backspace timing"
```

---

### Task 9: `PlaybackControls` interface + `MediaPlayerController` (media_kit)

**Files:**
- Create: `lib/player/playback_controls.dart`
- Create: `lib/player/media_player_controller.dart`

**Interfaces:**
- Consumes: `media_kit`'s `Player`/`Media` classes.
- Produces:
  ```dart
  abstract class PlaybackControls extends ChangeNotifier {
    int get positionMs;
    int get durationMs;
    bool get isPlaying;
    double get playbackRate;
    Future<void> play();
    Future<void> pause();
    Future<void> seek(int ms);
    Future<void> setRate(double rate);
  }

  class MediaPlayerController extends PlaybackControls {
    MediaPlayerController();
    Player get player; // the underlying media_kit Player, for VideoController
    Future<void> open(String path);
    // + all PlaybackControls members
  }
  ```
  `PlayerControlsBar` (Task 11) and `MarkingScaffold` (Task 12) depend only on `PlaybackControls`, so tests can substitute a fake instead of a real `Player`.

**No automated test for this task.** `MediaPlayerController` wraps `media_kit`'s `Player()`, which needs the native `libmpv` library loadable on the host — not available in a headless test run, and not something `flutter test` exercises anyway. Verify this task by proceeding to Task 13's manual checklist, which loads a real file into a running app.

- [ ] **Step 1: Implement `PlaybackControls`**

```dart
// lib/player/playback_controls.dart
import 'package:flutter/foundation.dart';

/// Minimal playback surface the UI needs. Implemented for real by
/// [MediaPlayerController]; test code implements a fake instead so
/// [PlayerControlsBar] and [MarkingScaffold] can be tested without a real
/// media backend.
abstract class PlaybackControls extends ChangeNotifier {
  int get positionMs;
  int get durationMs;
  bool get isPlaying;
  double get playbackRate;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(int ms);
  Future<void> setRate(double rate);
}
```

- [ ] **Step 2: Implement `MediaPlayerController`**

```dart
// lib/player/media_player_controller.dart
import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'playback_controls.dart';

class MediaPlayerController extends PlaybackControls {
  MediaPlayerController() : player = Player() {
    _positionSub = player.stream.position.listen((d) {
      _positionMs = d.inMilliseconds;
      notifyListeners();
    });
    _durationSub = player.stream.duration.listen((d) {
      _durationMs = d.inMilliseconds;
      notifyListeners();
    });
    _playingSub = player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _rateSub = player.stream.rate.listen((rate) {
      _playbackRate = rate;
      notifyListeners();
    });
  }

  final Player player;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<double> _rateSub;

  int _positionMs = 0;
  int _durationMs = 0;
  bool _isPlaying = false;
  double _playbackRate = 1.0;

  @override
  int get positionMs => _positionMs;
  @override
  int get durationMs => _durationMs;
  @override
  bool get isPlaying => _isPlaying;
  @override
  double get playbackRate => _playbackRate;

  Future<void> open(String path) => player.open(Media(path));
  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(int ms) => player.seek(Duration(milliseconds: ms));
  @override
  Future<void> setRate(double rate) => player.setRate(rate);

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _rateSub.cancel();
    player.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Confirm the project still analyzes cleanly**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/player/playback_controls.dart lib/player/media_player_controller.dart
git commit -m "Add PlaybackControls interface and media_kit-backed MediaPlayerController"
```

---

### Task 10: `LineListView` widget

**Files:**
- Create: `lib/ui/widgets/line_list_view.dart`
- Test: `test/ui/widgets/line_list_view_test.dart`

**Interfaces:**
- Consumes: `MarkingSession` (Task 7) via `provider`'s `context.watch`.
- Produces: `class LineListView extends StatefulWidget { const LineListView({Key? key, required void Function(int index) onRowTap}); }`. Each row has key `ValueKey('line-row-$index')`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/widgets/line_list_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/ui/widgets/line_list_view.dart';

Widget _wrap(MarkingSession session, void Function(int) onRowTap) {
  return MaterialApp(
    home: ChangeNotifierProvider.value(
      value: session,
      child: Scaffold(body: LineListView(onRowTap: onRowTap)),
    ),
  );
}

void main() {
  testWidgets('renders every line with its text and formatted timestamps', (tester) async {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line', startMs: 1000, endMs: 2500),
      SubtitleLine(index: 1, text: 'second line'),
    ]));

    await tester.pumpWidget(_wrap(session, (_) {}));

    expect(find.text('first line'), findsOneWidget);
    expect(find.text('00:01.000 → 00:02.500'), findsOneWidget);
    expect(find.text('second line'), findsOneWidget);
    expect(find.text('— → —'), findsOneWidget);
  });

  testWidgets("tapping a row calls onRowTap with that row's index", (tester) async {
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line'),
      SubtitleLine(index: 1, text: 'second line'),
    ]));
    int? tapped;

    await tester.pumpWidget(_wrap(session, (index) => tapped = index));
    await tester.tap(find.byKey(const ValueKey('line-row-1')));

    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/ui/widgets/line_list_view_test.dart
```

Expected: FAIL — `LineListView` doesn't exist yet.

- [ ] **Step 3: Implement `LineListView`**

```dart
// lib/ui/widgets/line_list_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/marking_session.dart';

class LineListView extends StatefulWidget {
  const LineListView({super.key, required this.onRowTap});

  /// Called with the tapped row's index so the caller can jump the player
  /// there and offer that row for manual editing.
  final void Function(int index) onRowTap;

  @override
  State<LineListView> createState() => _LineListViewState();
}

class _LineListViewState extends State<LineListView> {
  final _scrollController = ScrollController();
  static const _rowHeight = 48.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatMs(int? ms) {
    if (ms == null) return '—';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    final lines = session.lines;
    final currentIndex = session.currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null && _scrollController.hasClients) {
        _scrollController.animateTo(
          currentIndex * _rowHeight,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: lines.length,
      itemExtent: _rowHeight,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isCurrent = index == currentIndex;
        return Material(
          color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            key: ValueKey('line-row-$index'),
            dense: true,
            onTap: () => widget.onRowTap(index),
            leading: SizedBox(width: 40, child: Text('${index + 1}', textAlign: TextAlign.right)),
            title: Text(line.text, overflow: TextOverflow.ellipsis),
            subtitle: Text('${_formatMs(line.startMs)} → ${_formatMs(line.endMs)}'),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/ui/widgets/line_list_view_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/line_list_view.dart test/ui/widgets/line_list_view_test.dart
git commit -m "Add LineListView with live timestamps and click-to-jump"
```

---

### Task 11: `PlayerControlsBar` widget + shared test fake

**Files:**
- Create: `lib/ui/widgets/player_controls_bar.dart`
- Create: `test/support/fake_playback_controls.dart`
- Test: `test/ui/widgets/player_controls_bar_test.dart`

**Interfaces:**
- Consumes: `PlaybackControls` (Task 9).
- Produces: `class PlayerControlsBar extends StatelessWidget { const PlayerControlsBar({Key? key, required PlaybackControls controls}); }` with keys `play-pause-button`, `scrubber`, `rate-dropdown`. Also `class FakePlaybackControls extends PlaybackControls` in `test/support/`, reused by Task 12's tests too.

- [ ] **Step 1: Write the shared test fake**

```dart
// test/support/fake_playback_controls.dart
import 'package:stmarker/player/playback_controls.dart';

/// Test double for [PlaybackControls]. [seekTestPosition] simulates the
/// media clock advancing on its own (e.g. during playback); [seek] is the
/// override that records what a caller *requested*, in [lastSeek].
class FakePlaybackControls extends PlaybackControls {
  int _positionMs = 0;
  int durationMsValue = 10000;
  bool playingValue = false;
  double rateValue = 1.0;
  int? lastSeek;
  double? lastRate;

  void seekTestPosition(int ms) {
    _positionMs = ms;
    notifyListeners();
  }

  @override
  int get positionMs => _positionMs;
  @override
  int get durationMs => durationMsValue;
  @override
  bool get isPlaying => playingValue;
  @override
  double get playbackRate => rateValue;

  @override
  Future<void> play() async {
    playingValue = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playingValue = false;
    notifyListeners();
  }

  @override
  Future<void> seek(int ms) async {
    lastSeek = ms;
    _positionMs = ms;
    notifyListeners();
  }

  @override
  Future<void> setRate(double rate) async {
    lastRate = rate;
    rateValue = rate;
    notifyListeners();
  }
}
```

- [ ] **Step 2: Write the failing widget tests**

```dart
// test/ui/widgets/player_controls_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/ui/widgets/player_controls_bar.dart';

import '../../support/fake_playback_controls.dart';

void main() {
  testWidgets('tapping play/pause toggles playback', (tester) async {
    final controls = FakePlaybackControls();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayerControlsBar(controls: controls))));

    await tester.tap(find.byKey(const ValueKey('play-pause-button')));
    await tester.pump();
    expect(controls.playingValue, isTrue);

    await tester.tap(find.byKey(const ValueKey('play-pause-button')));
    await tester.pump();
    expect(controls.playingValue, isFalse);
  });

  testWidgets('selecting a rate calls setRate', (tester) async {
    final controls = FakePlaybackControls();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayerControlsBar(controls: controls))));

    await tester.tap(find.byKey(const ValueKey('rate-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();

    expect(controls.lastRate, 1.5);
  });
}
```

- [ ] **Step 3: Run and confirm failure**

```bash
flutter test test/ui/widgets/player_controls_bar_test.dart
```

Expected: FAIL — `PlayerControlsBar` doesn't exist yet.

- [ ] **Step 4: Implement `PlayerControlsBar`**

```dart
// lib/ui/widgets/player_controls_bar.dart
import 'package:flutter/material.dart';

import '../../player/playback_controls.dart';

class PlayerControlsBar extends StatelessWidget {
  const PlayerControlsBar({super.key, required this.controls});

  final PlaybackControls controls;

  String _format(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controls,
      builder: (context, _) {
        final duration = controls.durationMs;
        final maxValue = duration > 0 ? duration.toDouble() : 1.0;
        final position = controls.positionMs.clamp(0, duration > 0 ? duration : 1).toDouble();
        return Row(
          children: [
            IconButton(
              key: const ValueKey('play-pause-button'),
              icon: Icon(controls.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => controls.isPlaying ? controls.pause() : controls.play(),
            ),
            Text(_format(position.round())),
            Expanded(
              child: Slider(
                key: const ValueKey('scrubber'),
                min: 0,
                max: maxValue,
                value: position,
                onChanged: (value) => controls.seek(value.round()),
              ),
            ),
            Text(_format(duration)),
            DropdownButton<double>(
              key: const ValueKey('rate-dropdown'),
              value: controls.playbackRate,
              items: const [0.5, 0.75, 1.0, 1.25, 1.5]
                  .map((rate) => DropdownMenuItem(value: rate, child: Text('${rate}x')))
                  .toList(),
              onChanged: (rate) {
                if (rate != null) controls.setRate(rate);
              },
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run and confirm pass**

```bash
flutter test test/ui/widgets/player_controls_bar_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/widgets/player_controls_bar.dart test/support/fake_playback_controls.dart test/ui/widgets/player_controls_bar_test.dart
git commit -m "Add PlayerControlsBar with play/pause, scrubber, rate control"
```

---

### Task 12: `MarkingScaffold` (layout + keyboard wiring, media-agnostic)

**Files:**
- Create: `lib/ui/marking_scaffold.dart`
- Test: `test/ui/marking_scaffold_test.dart`

**Interfaces:**
- Consumes: `PlaybackControls` (Task 9), `MarkingKeyHandler` (Task 8), `MarkingSession` (Task 7, via provider), `LineListView` (Task 10), `PlayerControlsBar` (Task 11), `FakePlaybackControls` (Task 11, test-only).
- Produces: `class MarkingScaffold extends StatefulWidget { const MarkingScaffold({Key? key, required PlaybackControls controls, Widget? videoArea}); }` — this is what `HomeScreen` (Task 13) embeds as its `Scaffold.body`.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/ui/marking_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stmarker/models/project.dart';
import 'package:stmarker/models/subtitle_line.dart';
import 'package:stmarker/state/marking_session.dart';
import 'package:stmarker/ui/marking_scaffold.dart';

import '../support/fake_playback_controls.dart';

void main() {
  testWidgets('space down/up marks the current line using the live fake position', (tester) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line'),
      SubtitleLine(index: 1, text: 'second line'),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls)),
      ),
    ));
    await tester.pump();

    controls.seekTestPosition(1200);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    controls.seekTestPosition(3400);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'first line', startMs: 1200, endMs: 3400));
    expect(session.currentIndex, 1);
  });

  testWidgets('backspace redoes the current line and seeks back', (tester) async {
    final controls = FakePlaybackControls();
    final session = MarkingSession(const Project(mediaPath: '/x.mp3', lines: [
      SubtitleLine(index: 0, text: 'first line', startMs: 500, endMs: 900),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(body: MarkingScaffold(controls: controls)),
      ),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(session.lines[0], const SubtitleLine(index: 0, text: 'first line'));
    expect(controls.lastSeek, 500);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/ui/marking_scaffold_test.dart
```

Expected: FAIL — `MarkingScaffold` doesn't exist yet.

- [ ] **Step 3: Implement `MarkingScaffold`**

```dart
// lib/ui/marking_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../keyboard/marking_key_handler.dart';
import '../player/playback_controls.dart';
import '../state/marking_session.dart';
import 'widgets/line_list_view.dart';
import 'widgets/player_controls_bar.dart';

/// The marking screen's layout and keyboard wiring, decoupled from any real
/// media backend so it can be exercised in tests with a fake
/// [PlaybackControls]. [HomeScreen] is the composition root that supplies a
/// real media_kit-backed controller.
class MarkingScaffold extends StatefulWidget {
  const MarkingScaffold({super.key, required this.controls, this.videoArea});

  final PlaybackControls controls;

  /// Optional widget (e.g. a media_kit `Video`) shown above the controls bar.
  final Widget? videoArea;

  @override
  State<MarkingScaffold> createState() => _MarkingScaffoldState();
}

class _MarkingScaffoldState extends State<MarkingScaffold> {
  final _focusNode = FocusNode();
  MarkingKeyHandler? _keyHandler;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    _keyHandler ??= MarkingKeyHandler(
      session: session,
      getPositionMs: () => widget.controls.positionMs,
      seekTo: (ms) => widget.controls.seek(ms),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) =>
          (_keyHandler?.handleKeyEvent(event) ?? false) ? KeyEventResult.handled : KeyEventResult.ignored,
      child: Column(
        children: [
          if (widget.videoArea != null) SizedBox(height: 240, child: widget.videoArea),
          PlayerControlsBar(controls: widget.controls),
          Expanded(
            child: LineListView(
              onRowTap: (index) {
                final line = session.lines[index];
                if (line.startMs != null) widget.controls.seek(line.startMs!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run and confirm pass**

```bash
flutter test test/ui/marking_scaffold_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/ui/marking_scaffold.dart test/ui/marking_scaffold_test.dart
git commit -m "Add MarkingScaffold wiring keyboard, list, and controls"
```

---

### Task 13: `HomeScreen` composition root + `main.dart` + manual E2E verification

**Files:**
- Create: `lib/ui/home_screen.dart`
- Modify: `lib/main.dart` (replace Task 1's placeholder)

**Interfaces:**
- Consumes: `MarkingScaffold` (Task 12), `MediaPlayerController` (Task 9), `ProjectStore` (Task 6), `SrtCodec` (Task 4), `LrcCodec` (Task 5), `MarkingSession` (Task 7).
- Produces: the runnable app.

**No automated test for this task** — it's the composition root touching real `file_picker` dialogs and a real `media_kit` player, both of which need a display and (for `file_picker` on Linux) `zenity`/a desktop file-dialog backend. Verify with the manual checklist in Step 3.

- [ ] **Step 1: Implement `HomeScreen`**

```dart
// lib/ui/home_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/subtitle_line.dart';
import '../player/media_player_controller.dart';
import '../services/lrc_codec.dart';
import '../services/project_store.dart';
import '../services/srt_codec.dart';
import '../state/marking_session.dart';
import 'marking_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MediaPlayerController _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    _player = MediaPlayerController();
    _videoController = VideoController(_player.player);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pasteLinesDialog(MarkingSession session) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste lines (one per line)'),
        content: TextField(controller: controller, maxLines: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final rawLines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    session.importLines([
      for (var i = 0; i < rawLines.length; i++) SubtitleLine(index: i, text: rawLines[i].trim()),
    ]);
  }

  Future<void> _importSubtitleFile(MarkingSession session) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'lrc']);
    final path = result?.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final lines = path.toLowerCase().endsWith('.lrc') ? LrcCodec.decode(content) : SrtCodec.decode(content);
    session.importLines(lines);
  }

  Future<void> _loadMedia(MarkingSession session) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    final path = result?.files.single.path;
    if (path == null) return;
    session.setMediaPath(path);
    await _player.open(path);
  }

  Future<void> _saveProject(MarkingSession session) async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Save project', fileName: 'project.stmproj');
    if (path == null) return;
    await ProjectStore.save(session.project, path);
  }

  Future<void> _openProject(MarkingSession session) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['stmproj']);
    final path = result?.files.single.path;
    if (path == null) return;
    final project = await ProjectStore.load(path);
    session.loadProject(project);
    await _player.open(project.mediaPath);
  }

  Future<void> _exportSrt(MarkingSession session) async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Export SRT', fileName: 'export.srt');
    if (path == null) return;
    await File(path).writeAsString(SrtCodec.encode(session.lines));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('stmarker'),
        actions: [
          IconButton(
            tooltip: 'Paste lines',
            icon: const Icon(Icons.text_snippet),
            onPressed: () => _pasteLinesDialog(session),
          ),
          IconButton(
            tooltip: 'Import SRT/LRC',
            icon: const Icon(Icons.subtitles),
            onPressed: () => _importSubtitleFile(session),
          ),
          IconButton(
            tooltip: 'Load video/audio',
            icon: const Icon(Icons.folder_open),
            onPressed: () => _loadMedia(session),
          ),
          IconButton(
            tooltip: 'Open project',
            icon: const Icon(Icons.file_open),
            onPressed: () => _openProject(session),
          ),
          IconButton(
            tooltip: 'Save project',
            icon: const Icon(Icons.save),
            onPressed: () => _saveProject(session),
          ),
          IconButton(
            tooltip: 'Export SRT',
            icon: const Icon(Icons.download),
            onPressed: () => _exportSrt(session),
          ),
        ],
      ),
      body: MarkingScaffold(
        controls: _player,
        videoArea: Video(controller: _videoController),
      ),
    );
  }
}
```

- [ ] **Step 2: Replace `lib/main.dart`**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'models/project.dart';
import 'state/marking_session.dart';
import 'ui/home_screen.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const StmarkerApp());
}

class StmarkerApp extends StatelessWidget {
  const StmarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarkingSession(const Project(mediaPath: '', lines: [])),
      child: MaterialApp(
        title: 'stmarker',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const HomeScreen(),
      ),
    );
  }
}
```

- [ ] **Step 3: Automated check**

```bash
flutter analyze
flutter test
```

Expected: `No issues found!` and every test from Tasks 2–12 passes.

- [ ] **Step 4: Manual verification (user runs this on their own machine with a display)**

Prerequisite: Step 1 of Task 1 (`apt-get install clang ninja-build libgtk-3-dev pkg-config zenity`) has been run.

1. `flutter run -d linux`
2. Click the paste-lines icon, type 3 short lines, click Import — the (empty) list area should now show 3 rows with `— → —`.
3. Click the folder icon, choose a local `.mp3` or `.mp4` file.
4. Click play; hold Space down at the moment line 1 should start, release at the moment it should end — row 1 should fill in with real timestamps and the list should auto-scroll to highlight row 2 as current.
5. Press Backspace while a line is in progress — its timestamps should clear and the player should jump back to where you started marking it.
6. Once at least one row is complete, click that row — the player should seek to its start time.
7. Click Save, pick a location, quit and relaunch the app, click Open, select the saved file — the lines, timestamps, and media should all restore.
8. Click Export, save as `test.srt`, then open `test.srt` in a text editor and confirm it matches the format:
   ```
   1
   00:01:32,100 --> 00:01:34,800
   it's been a while
   ```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/home_screen.dart lib/main.dart
git commit -m "Wire HomeScreen composition root: import, load media, save/open, export SRT"
```

---

## Self-Review Notes

- **Spec coverage:** import (plain text + SRT/LRC) → Task 13; media load + adjustable rate → Tasks 9, 11, 13; sequential marking with space down/up → Tasks 7–8, 12; backspace redo → Tasks 7–8, 12; review/edit table via the same list → Tasks 10, 12; save/resume project → Tasks 3, 6, 13; SRT export → Tasks 4, 13; error handling (missing media, invalid timestamps, import replace) → covered by `ProjectStore`/`FilePicker` returning null on cancel and `importLines` wholesale replacement (Task 7); moved-media relocate-prompt is a UI nicety not yet wired — left as a follow-up since `_openProject` will simply throw a `PathNotFoundException` today if the media file moved, which surfaces as an uncaught error dialog rather than a friendly prompt.
- **Type consistency:** `MarkingSession`, `PlaybackControls`, and `MarkingKeyHandler` signatures match across every task that consumes them (checked Tasks 7, 8, 9, 10, 11, 12, 13 against each other).
- **Known gap flagged above:** the "media file missing/moved" friendly prompt from the design spec's Error Handling section isn't implemented as its own task — it's small enough to fold into a follow-up rather than block this plan, since it doesn't block the core happy path this plan delivers.

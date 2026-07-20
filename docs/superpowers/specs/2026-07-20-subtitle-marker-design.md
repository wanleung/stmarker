# Subtitle Marker — Design

## Purpose

A tool for hand-timing subtitles/lyrics against a video or audio file. The user
already has the line-by-line text; they play the media and, for each line,
hold the space bar down when the line starts and release it when the line
ends. The tool records those timestamps per line and exports a standard SRT
file at the end.

## Platform & Stack

- **Flutter**, single codebase targeting desktop (Linux, Windows, macOS).
  Flutter Web is not currently supported; browser-native media playback is a
  possible future extension behind the existing playback abstraction.
- **Media playback**: `media_kit` (libmpv-backed) for broad desktop
  codec/format support.
- **State management**: a single `MarkingSession` model exposed via a
  `ChangeNotifier` (or Provider). No backend/server — the app is fully local
  and file-based.

## Data Model

```
Project
  mediaPath: String       // absolute path to the video/audio file
  playbackRate: double     // default 1.0
  lines: List<SubtitleLine>

SubtitleLine
  index: int
  text: String
  startMs: int?            // null = not yet marked
  endMs: int?              // null = not yet marked
```

A project is serialized to a single JSON file (e.g. `.stmproj`), saved
wherever the user chooses via Save/Save As. The media file is referenced by
absolute path (not copied into the project) — if the file moves, the app
prompts the user to relocate it on load.

## Core Marking Workflow

1. **Import lines** — either:
   - Paste/type plain text, one subtitle line per text line, or
   - Import an existing `.srt`/`.lrc` file, which parses out text (and any
     existing timings, used as a starting point for re-timing).
2. **Load media** — file picker for video/audio. `media_kit` initializes a
   player with scrubber, play/pause, and an adjustable playback rate
   (~0.5x–1.5x) to make fast-paced lines easier to catch accurately.
3. **Marking loop**, while media plays:
   - The **current line** is always the first line in sequential order that
     is not fully marked (`startMs == null`, or `startMs` set but
     `endMs == null`).
   - **Space down** → if the current line has no `startMs`, set it to the
     live playhead position.
   - **Space up** → set `endMs` on that same line to the live playhead
     position, then advance the current-line pointer to the next line.
   - **Backspace** → clears the current line's `startMs`/`endMs` and seeks
     the playhead back to the line's just-cleared `startMs` (or, if nothing
     was marked yet on this attempt, back by a small fixed offset — ~1–2s —
     so the user can re-approach the line). This is the quick "redo this
     line" path.
   - If the user pauses or manually scrubs while space is still held down,
     the eventual space-up still uses the live playhead position at release
     time — an unbroken play-through is not required.
4. **List view** (main screen layout): every line is shown with its
   timestamps filling in live as marking proceeds; the current line is
   highlighted and the list auto-scrolls to keep it in view. This list
   doubles as the **review/edit table** — clicking any row jumps the
   playhead there and allows direct inline editing of that row's start/end,
   independent of the sequential pointer used for still-unmarked lines.

## Save / Resume

- **Save** writes the project JSON (media path, playback rate, lines +
  timestamps) to the active project location. **Save As** chooses a new path.
- **Resume** loads the JSON, restores all lines/timestamps, and reloads the
  media from its stored absolute path, prompting to relocate it if missing.

## Export

- Once lines are marked, **Export SRT** produces a standard `.srt`:

  ```
  1
  00:01:32,100 --> 00:01:34,800
  it's been a while

  2
  00:01:35,000 --> 00:01:37,200
  since I've seen your face
  ```

- Export numbering is always 1-indexed sequential, independent of any
  original numbering in imported text.
- Export is allowed even with some lines still unmarked — those are skipped
  or flagged, at the user's choice, rather than blocking export outright.
- **Export Video** invokes a locally installed FFmpeg executable and offers
  either a selectable subtitle track (stream-copying the original audio and
  video) or burned-in subtitles (re-encoding the video). The source file is
  never used as the output path, progress is shown, and an active export can
  be cancelled.

## Error Handling & Edge Cases

- **Media file missing/moved** on resume → prompt to browse and relocate;
  update the stored path.
- **Invalid/overlapping timestamps** (e.g. an edited row's end ≤ start, or a
  start earlier than the previous line's end) → flagged visually in the list
  (e.g. red border) but non-blocking during editing; only surfaced as a hard
  warning at export time if a line's end ≤ start.
- **Import mismatch** — re-importing plain text after an `.srt` import (or
  vice versa) replaces the entire line list wholesale; no partial merge is
  attempted.

## Testing

- Unit tests: SRT parser/writer round-trip, project JSON
  serialize/deserialize, sequential-pointer state transitions (space
  down/up/backspace), timestamp validation.
- Widget/integration test for the marking screen: simulate key events at
  fake playhead positions and assert resulting `SubtitleLine` timestamps.
- `media_kit` playback itself is trusted (not under test); testing focuses on
  the state logic built around it.

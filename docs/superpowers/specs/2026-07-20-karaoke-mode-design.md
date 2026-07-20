# Karaoke Mode Design

## Goal

Add optional word-by-word karaoke timing and highlighting while preserving the
existing whole-line subtitle workflow as Standard mode. Karaoke offers an Easy
mode with evenly distributed timing and an Advanced mode recorded live with
Space presses.

## Modes

Each project has one of three mutually exclusive modes:

- `standard`: current whole-line marking, review, and export behavior remains
  unchanged.
- `karaokeEasy`: karaoke units are timed evenly across each completed line.
- `karaokeAdvanced`: karaoke unit starts are recorded during a separate live
  marking pass.

Projects created before this feature have no mode field and load as
`standard`. Switching to Standard does not delete stored karaoke data, so the
user can return to Karaoke without losing work. Switching between Easy and
Advanced preserves valid Advanced marks but only uses them in Advanced mode.

## Karaoke units

Karaoke timing applies to ordered text units while preserving the exact source
text for normal display and SRT export.

- Text containing word spaces is divided into words.
- Runs of Chinese or Japanese text without word spaces are divided into
  individual characters.
- Whitespace is preserved between units for rendering but is not timed as its
  own unit.
- Punctuation attaches to the preceding word or character. Leading punctuation
  attaches to the next unit.
- An empty or punctuation-only line is treated as one unit.

The tokenizer is deterministic. Reopening a project or exporting it again
must produce the same units for unchanged text.

## Data model

The project stores:

- the project mode;
- the pre-display mode;
- per-line Advanced karaoke marks when present.

Each Advanced mark identifies its karaoke unit and stores an absolute media
start time in milliseconds. Unit text does not replace `SubtitleLine.text`;
it is derived and retained only as identity data needed to detect stale marks.

The existing `SubtitleLine.startMs` remains the singing start of the line and
`endMs` remains the end of the final unit. The visual display start is derived
from the selected pre-display mode and is not stored as a replacement line
timestamp.

If a line's text, start, or end is edited outside an Advanced marking
transaction, its Advanced marks are cleared. The UI explains that the word
timing must be recorded again. The first Space press updates the line start and
first unit mark atomically, so that intentional retiming does not invalidate
the pass in progress. Easy timing is derived, so it is recalculated immediately
instead of being invalidated.

## Easy timing

For a completed valid line, Easy mode divides the interval from `startMs` to
`endMs` evenly across all karaoke units. Integer rounding is deterministic:
unit boundaries are calculated from the line duration and unit index, and the
last unit always ends exactly at `endMs`.

Easy mode requires no additional marking pass. Its calculated timing is used
by live preview, ASS export, and burned-in video export.

## Advanced marking

Advanced mode adds a **Mark words** action for a completed line.

1. Playback seeks to two seconds before the line's existing `startMs`, clamped
   to media time zero.
2. The target line and current karaoke unit are visibly focused beneath the
   video.
3. Playback starts. The user presses Space once at the start of every unit,
   including the first.
4. The first press becomes the line's new `startMs` and the first unit's start.
   Later presses record the remaining unit starts.
5. The existing line `endMs` remains fixed and closes the final unit.
6. Backspace removes the most recent unit mark and returns focus to that unit.
7. Restart clears the line's unit marks and repeats the two-second pre-roll.
8. Redo clears only that line's Advanced marks, not its text or line end.

A press at or after `endMs`, or a press not later than the preceding unit, is
rejected with concise feedback. Completion requires one valid start per unit.
If updating the first start would make the line overlap the previous subtitle,
the existing overlap warning and export acknowledgement behavior applies.

## Pre-display

Karaoke settings provide these project-level choices:

- `off`
- `3 seconds`
- `4 seconds`
- `5 seconds`
- `one line ahead`

### Timed pre-display

For 3, 4, or 5 seconds, a karaoke line becomes visible in white that many
seconds before its singing start. Highlighting does not begin until the first
unit starts. A derived display start before media time zero is clamped to zero;
the singing and unit timing is not shifted.

### One line ahead

The current and next completed karaoke lines use two fixed rows. The current
line highlights on its assigned row while the next line is pre-displayed in
white on the other row. On progression, active lines alternate rows instead of
moving between rows. The newly free row shows the following line.

The first completed line appears when its singing starts because no prior line
can introduce it. The next-line preview begins when the current line begins and
ends when that preview line becomes active. Gaps between singing lines keep the
next line visible. The final line has no additional preview after it.

## Appearance and preview

Karaoke uses a classic two-colour sweep:

- upcoming text is white;
- completed portions turn gold from left to right.

The existing selected Noto font face and subtitle size apply. Karaoke preview
uses the focused subtitle panel beneath the video during Easy preview,
Advanced marking, and review playback. One-line-ahead preview renders the two
alternating rows in that panel. The line list reports whether each line is
ready, incomplete, invalid, or needs its Advanced timing redone.

## Export behavior

### ASS

ASS export preserves karaoke using karaoke timing tags. The ASS style defines
white upcoming text and gold completed text. Timed pre-display introduces an
unhighlighted delay before the first timed unit. One-line-ahead export creates
overlapping events on alternating rows so the next line remains visible while
the current line highlights.

All timing is converted to ASS centiseconds with deterministic rounding. Any
rounding remainder is assigned so the final karaoke unit still reaches the
line end.

### Burned-in video

Burned-in export renders the same generated ASS through FFmpeg. It therefore
matches the live karaoke mode in font, size, colours, timing, lead-in, and row
alternation.

### SRT and selectable subtitle tracks

SRT and container-selectable subtitle tracks retain normal whole-line text and
timing. Before export, the app warns that karaoke animation and pre-display are
not supported and will be omitted. Existing incomplete-line, invalid-range,
and overlap warnings continue to apply.

### Import

SRT and LRC import continues to create line-level timing only. In Easy mode,
karaoke timing is immediately derived for completed lines. In Advanced mode,
imported completed lines are ready for a word-marking pass. Importing ASS
karaoke tags is outside this version's scope.

## Validation and error handling

A karaoke line is invalid for karaoke export when:

- its whole-line range is missing or invalid;
- it has no renderable karaoke unit;
- Advanced mode lacks one start per unit;
- Advanced starts are not strictly increasing;
- a unit has zero or negative duration; or
- a unit start lies outside the whole-line range.

Karaoke ASS and burned-in export identify affected line numbers and do not
silently substitute Easy timing for incomplete Advanced timing. Standard SRT
fallback remains available from the valid whole-line timestamps after its
karaoke-omission warning.

Media operations use the existing stale-operation and mounted-context guards.
Leaving Advanced marking, replacing lines, opening another project, or
disposing the screen cancels the active word-marking pass without applying a
late playback result.

## Testing

Automated coverage includes:

- whitespace, CJK, mixed-script, punctuation, and empty-line tokenization;
- exact Easy distribution and integer rounding;
- Advanced first-word retiming, subsequent marks, undo, restart, invalid
  presses, cancellation, and stale async completions;
- project JSON backward compatibility and karaoke round trips;
- invalidation after text or whole-line timestamp edits;
- live white-to-gold progress and alternating two-row preview;
- ASS karaoke tags, timed lead-in, centisecond rounding, and row alternation;
- SRT/selectable-track omission warnings and unchanged line-level output;
- burned-in FFmpeg use of the generated karaoke ASS and bundled font; and
- regression coverage proving Standard mode behavior remains unchanged.

Before completion, run formatting, Flutter analysis, the full test suite, and
a Linux release build.

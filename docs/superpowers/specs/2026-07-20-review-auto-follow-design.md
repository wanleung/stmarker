# Review Auto-Follow — Design

## Purpose

Keep review focused during continuous playback by automatically displaying and
highlighting the subtitle whose marked interval contains the live playhead.

## Behaviour

- Auto-follow operates only while review mode is active and media is playing.
- A line is active when `startMs <= positionMs < endMs`.
- The active line becomes the selected and highlighted review row, and its
  text appears in the subtitle panel beneath the video.
- If the playhead is not inside any marked interval, the panel is blank. It
  stays blank until playback enters the next interval.
- Seeking while playing recalculates the active line immediately.
- When playback pauses, the last active or manually selected line remains
  selected and visible for inspection and redo flagging.
- Previous, Next, and row selection remain available. **Play this line** keeps
  its existing exact-interval playback and stops at the selected line's end.

## Interval Resolution

`MarkingScaffold` derives the active index from the session lines whenever its
playback-controls listener receives a position or playing-state update. A
small pure helper searches for a fully marked line containing the current
position. The end boundary is exclusive so adjacent lines switch cleanly at a
shared timestamp.

If invalid or overlapping timings exist, the first matching line in list order
wins. This is deterministic and matches the line list's sequential reading
order; existing validation continues to warn about the underlying timing
problem.

## State and Rendering

The scaffold keeps an optional playback-follow index separate from the manual
review index. While playing, the follow index controls the panel and row
highlight; a null follow index renders an empty panel during a gap. When an
active interval is found, the manual review index is updated as well so pause,
flag, and navigation continue from that line.

Starting a new review playback operation, replacing lines or controls, leaving
review mode, and disposing the widget clear the transient follow state. The
existing operation-generation and playback-ownership safeguards remain in
force.

## Presentation

The existing high-contrast panel remains in place during review. During a
playback gap it preserves its size but contains no text, preventing the video,
controls, and line list from jumping vertically at subtitle boundaries.

## Testing

Widget and unit-level helper coverage verifies:

- automatic selection and panel updates as the playhead enters an interval;
- a blank, size-preserving panel during gaps;
- immediate updates after seeking during playback;
- the exclusive end boundary and deterministic first match for overlaps;
- the last active line remains visible after pause;
- manual selection still works while paused; and
- exact **Play this line** stop behavior is unchanged.


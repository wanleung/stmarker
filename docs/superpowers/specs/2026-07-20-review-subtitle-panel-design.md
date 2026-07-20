# Review Subtitle Panel — Design

## Purpose

Make subtitle review more focused by showing the currently selected line close
to the video, without covering the picture.

## Behaviour

- The panel appears directly beneath the video only while review mode is
  active.
- It displays the text of the currently selected review line.
- Its contents update immediately when the user selects a row or moves with
  the previous and next controls.
- The text remains visible while playback is paused and while the selected
  interval is playing.
- Leaving review mode removes the panel. The normal marking layout and
  keyboard workflow remain unchanged.

## Presentation

The panel uses a high-contrast surface and centered text. It has enough
horizontal padding to separate the subtitle from the video edges and enough
vertical space for up to three wrapped lines. It grows only as needed within
that limit, preventing unusually long text from consuming the line list.

## Architecture

`MarkingScaffold` already owns the selected review index, so it also derives
the displayed text from the current `MarkingSession`. A small private subtitle
panel widget renders that text between the video and the existing player
controls. No new application state or project-file data is required.

If the line list changes unexpectedly while review mode is active, the
selected index is clamped to the available range. An empty list produces no
panel rather than attempting to access a missing line.

## Testing

Widget tests verify that the panel:

- shows the initially selected line in review mode;
- updates after next/previous navigation and row selection;
- is absent during normal marking mode; and
- handles an empty line list safely.


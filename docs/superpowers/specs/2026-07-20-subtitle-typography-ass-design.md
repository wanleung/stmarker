# Subtitle Typography and ASS Export — Design

## Purpose

Let users choose a readable subtitle font face and size, preview it during
review, carry it into burned-in video export, and export a portable styled ASS
subtitle package.

## Bundled Fonts and Licensing

The application bundles regular-weight CJK-capable releases from the official
Noto project:

- Noto Sans CJK;
- Noto Serif CJK; and
- Noto Sans Mono CJK.

The exact asset filenames and internal family names are recorded in one font
catalog in code rather than repeated across UI and export services. Font files
come from an official Noto CJK release and remain unmodified.

Noto CJK uses the SIL Open Font License 1.1. The application includes the
upstream copyright notice and complete OFL text with its bundled assets. When
an ASS package is exported, the selected font and the same licence file are
copied beside the ASS file. Fonts are not sold separately or relicensed.

Bundling CJK fonts will noticeably increase desktop and AppImage sizes. The
regular weight only is included to limit that increase.

## Project Model

`Project` gains two backward-compatible fields:

- `subtitleFontFamily`, defaulting to the Noto Sans CJK catalog identifier;
- `subtitleFontSize`, defaulting to `24.0` logical pixels.

Font size is restricted to 16–64. JSON loading accepts missing fields from old
projects, rejects unknown font identifiers by falling back to the default, and
clamps numeric sizes to the supported range. Save, Save As, and project reopen
preserve both values.

`MarkingSession` exposes one method that updates the two appearance values in a
single notification.

## Appearance Dialog

A **Subtitle appearance** action is available in the review controls. It opens
a modal dialog containing:

- a dropdown listing the three bundled faces;
- a 16–64 font-size slider with the current numeric value;
- a high-contrast live preview using the current review line, or sample text
  when no line is available;
- **Reset to default**, **Cancel**, and **Save** actions.

Changes remain local to the dialog until Save. Cancel leaves the project
unchanged. Reset changes the dialog preview to Noto Sans CJK at 24 without
saving until Save is selected.

The review subtitle panel reads the saved project values and updates
immediately after Save. Auto-follow, gap blanking, row selection, flagging, and
exact interval playback are unaffected.

## SRT and Selectable Tracks

Existing SRT export stays standards-compliant and contains no typography.
Selectable subtitle tracks continue to use player-controlled appearance.
There is no attempt to place non-standard font metadata in SRT.

## ASS Export

A new **Export ASS** toolbar action asks for an `.ass` destination and writes a
UTF-8 Advanced SubStation Alpha file. It includes:

- script metadata with `PlayResX: 1280` and `PlayResY: 720`;
- one default style containing the selected Noto family and font size;
- marked, valid subtitle lines as dialogue events;
- ASS-safe escaped text, including explicit `\N` line breaks; and
- ASS centisecond timestamps without cumulative rounding drift.

Export uses the same warning flow as SRT: incomplete lines are skipped and
invalid ranges require confirmation. Alongside `name.ass`, the app creates a
folder named `name_fonts` containing the selected font file and `OFL.txt`.
If the companion folder or its target files already exist, the app asks before
replacing them. It writes package contents to temporary sibling paths first and
only replaces the destination after every output is ready. On failure it
reports the error, removes temporary output, and preserves the previous ASS
package.

The ASS file references the font by its internal family name. Copying the font
beside it makes the dependency explicit, but players generally require the
user to install the font or attach it to a compatible container such as MKV.

## Burned-In Video Export

Burned-in FFmpeg export applies the saved face and size through libass:

- the selected bundled font asset is materialized into the export service's
  temporary directory;
- the subtitle filter receives that directory through `fontsdir`;
- `force_style` specifies the catalog's internal `FontName` and saved
  `FontSize`;
- filter-path and style values use FFmpeg-safe escaping; and
- all temporary subtitle, font, and licence files are removed on success,
  failure, or cancellation.

Embedded/selectable export remains unchanged. The appearance preview is an
approximation: libass and Flutter can differ slightly in metrics and scaling.

## Asset Access and Packaging

Font access is hidden behind an injectable asset loader. The production loader
uses Flutter's asset bundle; tests use in-memory bytes. This keeps codecs and
export services independent from widget bindings.

Font assets and the OFL file are declared in `pubspec.yaml`, included by normal
desktop builds, and therefore carried into the existing AppImage packaging
without special copy commands.

## Testing

Tests cover:

- project JSON defaults, validation, round-trip, and copy behavior;
- one-notification appearance updates;
- font catalog identifiers, family names, paths, and defaults;
- dialog preview, reset, cancel, and save behavior;
- review panel font face and size application;
- ASS headers, style, escaping, timings, skipped lines, and deterministic
  ordering;
- ASS package font/licence copying and partial-failure cleanup;
- FFmpeg burned-in arguments for `fontsdir`, `FontName`, and `FontSize`;
- FFmpeg temporary asset cleanup on success, failure, and cancellation;
- unchanged SRT and selectable-track behavior; and
- desktop asset availability in a Flutter test.

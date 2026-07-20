# Subtitle Marker

Subtitle Marker is a local desktop application for timing subtitles or lyrics
against video and audio. Import or paste one line at a time, play the media,
then hold Space for the duration of each line. The finished timings can be
saved as a reusable project, exported as SRT, or added directly to a video
with FFmpeg.

The application runs entirely on your computer. It has no backend and does
not upload media or subtitle text.

## Features

- Paste plain text or import existing SRT and LRC files.
- Mark line start and end times using the keyboard.
- Review each completed subtitle interval and flag lines to redo.
- Edit timestamps directly when not in review mode.
- Save and reopen `.stmproj` project files.
- Relocate media when a saved project references a moved file.
- Export standard SRT subtitles, including partially completed projects.
- Detect invalid and overlapping timestamp ranges.
- Add a selectable subtitle track without re-encoding the video.
- Burn subtitles permanently into a video with FFmpeg.
- Adjust playback speed from 0.5× to 1.5×.

## Supported platforms

The current implementation targets Linux, Windows, and macOS. Flutter Web is
not currently supported because desktop playback uses `media_kit` and libmpv.

## Requirements

- Flutter stable with desktop support enabled
- A C++ desktop build toolchain for the target platform
- libmpv development files on Linux
- FFmpeg on `PATH` for subtitled-video export

FFmpeg is optional if only project and SRT export are needed.

### Ubuntu and Debian

```bash
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev ffmpeg
```

Confirm that the native dependencies are visible:

```bash
pkg-config --modversion mpv
ffmpeg -version
```

On Windows and macOS, the media libraries are supplied by
`media_kit_libs_video`; install FFmpeg separately and ensure its executable is
available on `PATH`.

## Run from source

```bash
flutter pub get
flutter run -d linux
```

Replace `linux` with `windows` or `macos` when building on those platforms.

To create a release build:

```bash
flutter build linux
```

## Build an AppImage

On an x86_64 Linux build machine, install the normal Linux requirements from
above and run:

```bash
./packaging/appimage/build-appimage.sh
```

The script builds the Flutter release, downloads `linuxdeploy` when necessary,
packages the Flutter bundle and FFmpeg, then writes:

```text
build/appimage/Subtitle_Marker-x86_64.AppImage
```

Run the result directly:

```bash
chmod +x build/appimage/Subtitle_Marker-x86_64.AppImage
./build/appimage/Subtitle_Marker-x86_64.AppImage
```

FFmpeg is included by default so video export works on machines without a
system FFmpeg installation. To create a smaller AppImage that relies on the
host's FFmpeg instead:

```bash
BUNDLE_FFMPEG=0 ./packaging/appimage/build-appimage.sh
```

The AppImage still expects the host to provide a compatible GTK 3 and libmpv
runtime. On Ubuntu or Debian these can be installed with:

```bash
sudo apt install libgtk-3-0 libmpv2
```

Build on the oldest Linux distribution you intend to support because glibc is
backward-compatible, not forward-compatible. The current script targets
x86_64; other architectures need a matching `linuxdeploy` build.

## Workflow

1. Select **Paste lines** or **Import SRT/LRC**.
2. Select **Load video/audio** and choose the source media.
3. Start playback and mark each line:
   - Hold Space when the line begins.
   - Release Space when the line ends.
   - Press Backspace to clear and retry the latest line.
4. When every line is marked, select **Review marked lines** in the toolbar.
   Play each line's exact interval, move through the list, and select
   **Needs redo** for any line that needs another pass. Choose **Redo flagged**
   to clear those timings and resume marking from the first flagged line.
5. Outside review mode, select any row to seek to it and edit its millisecond
   timestamps directly.
6. Save the work as an `.stmproj` project, export SRT, or export a subtitled
   video.

Invalid ranges and overlaps are shown in the line list. Export remains
possible after acknowledging warnings; incomplete lines are omitted from the
generated SRT.

## Video export

The **Export subtitled video** action offers two modes:

| Mode | Behaviour | Trade-off |
| --- | --- | --- |
| Selectable subtitle track | Copies the original audio/video streams and adds subtitles | Fast and quality-preserving, but subtitle visibility depends on the player |
| Burn subtitles into video | Renders the text into every frame using H.264 | Universally visible, but slower and requires video re-encoding |

MP4, M4V, and MOV outputs use `mov_text` subtitle tracks. MKV outputs use SRT
subtitle tracks. The app prevents the output path from overwriting the source,
shows progress, supports cancellation, and removes its temporary subtitle
file when finished.

## Project format

An `.stmproj` file is readable JSON containing:

- the absolute path to the media file;
- the selected playback rate; and
- subtitle text with start and end timestamps.

The media itself is not copied into the project. If it moves, the app asks you
to locate it when reopening the project.

## Development

```bash
flutter analyze
flutter test
flutter build linux
```

The detailed design and original implementation plan are in
[`docs/superpowers`](docs/superpowers/).

## Troubleshooting

### `PkgConfig::mpv` target was not found

Install the libmpv development package, then regenerate the Flutter build:

```bash
sudo apt install libmpv-dev
flutter clean
flutter pub get
```

### FFmpeg is not installed or not available on PATH

Install FFmpeg, restart the application so it receives the updated `PATH`,
and verify it with `ffmpeg -version` in a terminal.

### A saved project cannot find its media

Choose **Locate media** when prompted. The relocated absolute path is stored
the next time the project is saved.

## License

Copyright © 2026 Subtitle Marker contributors.

This project is licensed under the GNU General Public License, version 3 or
later. See [LICENSE](LICENSE) for the full text.

SPDX-License-Identifier: GPL-3.0-or-later

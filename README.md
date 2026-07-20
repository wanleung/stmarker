# stmarker

A subtitle/lyrics timing tool. Load a video or audio file, load text you
already have line-by-line, then play the media and hold the space bar down
for the start of each line and release it for the end — the tool records the
timestamps and exports a standard `.srt` file.

See [`docs/superpowers/specs/2026-07-20-subtitle-marker-design.md`](docs/superpowers/specs/2026-07-20-subtitle-marker-design.md)
for the full design.

## Linux setup

Install Flutter's Linux desktop prerequisites, the `libmpv` development
package used by `media_kit`, and FFmpeg for subtitled-video export:

```bash
sudo apt install libgtk-3-dev libmpv-dev ninja-build clang cmake pkg-config ffmpeg
flutter pub get
flutter run -d linux
```

Windows and macOS use the native libraries bundled by `media_kit_libs_video`.

FFmpeg must be installed and available on `PATH` on every platform to export a
video with either a selectable subtitle track or burned-in subtitles. Plain
SRT export does not require FFmpeg.

## License

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version. See [LICENSE](LICENSE) for the full text.

SPDX-License-Identifier: GPL-3.0-or-later

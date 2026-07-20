# Task 5 report: FFmpeg burned-in font integration

## Implemented

- Extended `export` with required subtitle font, font size, and asset loader inputs.
- Added a minimal injectable FFmpeg process interface/starter while retaining the existing stdout/stderr, exit-code, progress, and signal-based cancellation flow.
- Materialized the selected font and `assets/fonts/OFL.txt` only for burned-in exports, in the existing FFmpeg temporary directory.
- Added burned-in `fontsdir` and `force_style` filter arguments with escaping for backslashes, colons, commas, apostrophes, brackets, and paths.
- Preserved embedded argument construction byte-for-byte and verified embedded export never calls the asset loader.
- Kept temporary-directory deletion in `finally`; tests prove deletion after success, nonzero exit, process-start failure, and cancellation.

## TDD evidence

- RED: `flutter test test/services/ffmpeg_export_service_test.dart` failed on the missing `FfmpegProcess`, `startProcess`, and burned-font parameters.
- GREEN: the focused service suite passes 9 tests.

## Verification

- `flutter test test/services/ffmpeg_export_service_test.dart` — 9 passed.
- `flutter analyze lib/services/ffmpeg_export_service.dart test/services/ffmpeg_export_service_test.dart` — no issues.
- `git diff --check` — clean.
- Full `flutter analyze` currently reports the expected three missing required arguments at `lib/ui/home_screen.dart:339`; wiring that caller is outside Task 5's two implementation/test files and belongs to the integration task.

## Scope

Committed files are limited to the FFmpeg service, its focused test, and this required report.

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
BUILD_ROOT="$REPO_ROOT/build/appimage"
APPDIR="$BUILD_ROOT/Subtitle_Marker.AppDir"
FLUTTER_BUNDLE="$REPO_ROOT/build/linux/x64/release/bundle"
LINUXDEPLOY="$BUILD_ROOT/linuxdeploy-x86_64.AppImage"
OUTPUT="$BUILD_ROOT/Subtitle_Marker-x86_64.AppImage"
ICON_SOURCE="$REPO_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "This script currently supports x86_64 hosts only." >&2
  exit 1
fi

for command_name in flutter curl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

echo "Building Subtitle Marker for Linux..."
cd "$REPO_ROOT"
flutter build linux --release

echo "Creating AppDir..."
rm -rf -- "$APPDIR"
mkdir -p \
  "$APPDIR/usr/lib/subtitle-marker" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
  "$APPDIR/usr/share/metainfo"

cp -a "$FLUTTER_BUNDLE/." "$APPDIR/usr/lib/subtitle-marker/"
install -Dm755 "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
install -Dm644 "$SCRIPT_DIR/subtitle-marker.desktop" \
  "$APPDIR/subtitle-marker.desktop"
install -Dm644 "$SCRIPT_DIR/subtitle-marker.desktop" \
  "$APPDIR/usr/share/applications/subtitle-marker.desktop"
install -Dm644 "$SCRIPT_DIR/subtitle-marker.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/subtitle-marker.metainfo.xml"
install -Dm644 "$ICON_SOURCE" "$APPDIR/subtitle-marker.png"
install -Dm644 "$ICON_SOURCE" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/subtitle-marker.png"

if [[ ! -x "$LINUXDEPLOY" ]]; then
  echo "Downloading linuxdeploy..."
  curl --fail --location --retry 3 \
    --output "$LINUXDEPLOY" \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
  chmod +x "$LINUXDEPLOY"
fi

linuxdeploy_args=(
  --appdir "$APPDIR"
  --desktop-file "$SCRIPT_DIR/subtitle-marker.desktop"
  --icon-file "$ICON_SOURCE"
  --executable "$APPDIR/usr/lib/subtitle-marker/stmarker"
)

# Flutter plugins are loaded dynamically, so linuxdeploy cannot discover them
# by inspecting the runner alone. Supplying each shared object ensures libmpv
# and the other plugin dependencies are copied into the AppDir.
while IFS= read -r -d '' library; do
  linuxdeploy_args+=(--library "$library")
done < <(find "$APPDIR/usr/lib/subtitle-marker/lib" -maxdepth 1 -type f \
  -name '*.so' -print0)

if [[ "${BUNDLE_FFMPEG:-1}" == "1" ]]; then
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "FFmpeg is required when BUNDLE_FFMPEG=1." >&2
    echo "Install FFmpeg or run with BUNDLE_FFMPEG=0." >&2
    exit 1
  fi
  linuxdeploy_args+=(--executable "$(command -v ffmpeg)")
else
  echo "FFmpeg will not be bundled; video export will require it on the host PATH."
fi

echo "Bundling native dependencies and creating AppImage..."
rm -f -- "$OUTPUT"
APPIMAGE_EXTRACT_AND_RUN=1 \
ARCH=x86_64 \
LDAI_OUTPUT="$OUTPUT" \
"$LINUXDEPLOY" "${linuxdeploy_args[@]}" --output appimage

echo
echo "Created: $OUTPUT"
echo "Run it with:"
echo "  chmod +x '$OUTPUT'"
echo "  '$OUTPUT'"

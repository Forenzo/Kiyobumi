#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v sips >/dev/null || { echo 'Icon building requires macOS sips.' >&2; exit 1; }
command -v iconutil >/dev/null || { echo 'Icon building requires macOS iconutil.' >&2; exit 1; }
icon_output="${1:-$PWD/dist/Kiyobumi.icns}"
mkdir -p "$(dirname "$icon_output")"
icon_work="$(mktemp -d "${TMPDIR:-/tmp}/Kiyobumi-icon.XXXXXX")"
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/Kiyobumi.iconset"
mkdir -p "$iconset"
for icon_size in 16 32 128 256 512; do
    sips -z "$icon_size" "$icon_size" macOS/Assets/KiyobumiIcon.png \
        --out "$iconset/icon_${icon_size}x${icon_size}.png" >/dev/null
    retina_size=$((icon_size * 2))
    sips -z "$retina_size" "$retina_size" macOS/Assets/KiyobumiIcon.png \
        --out "$iconset/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$icon_work/Kiyobumi.icns"
mv -f "$icon_work/Kiyobumi.icns" "$icon_output"

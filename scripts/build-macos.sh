#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "The desktop app builds on macOS. Rust tests can run on other systems." >&2
  exit 1
fi
command -v cargo >/dev/null || { echo "Install the Rust toolchain first (see README.md)." >&2; exit 1; }
xcrun --find swift >/dev/null || { echo "Install Xcode or Apple's Command Line Tools first." >&2; exit 1; }
# Swift 6.4 changed SwiftPM's default backend. Keep the previously used native
# backend and resolve all compiler/SDK paths from the same Apple toolchain.
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
build_options=(--build-system native --scratch-path "$PWD/.build/kiyobumi-native" --sdk "$sdk_path")
echo "Building with Apple SDK $sdk_version using the native SwiftPM backend."
xcrun swift --version
cargo build --manifest-path rust/Cargo.toml --release --locked -p one-import -p onestore
xcrun swift build "${build_options[@]}" -c release -Xswiftc -Osize
if [[ "${1:-}" == "--test" ]]; then
  xcrun swift test "${build_options[@]}"
else
  echo 'Swift tests skipped for this app build. Run with --test using an XCTest-capable Xcode toolchain to test.'
fi
cargo test --manifest-path rust/Cargo.toml --locked
app_path="$PWD/dist/Kiyobumi.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$(xcrun swift build "${build_options[@]}" -c release --show-bin-path)/OpenNotebook" "$app_path/Contents/MacOS/Kiyobumi"
cp macOS/Info.plist "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DTSDKName string macosx$sdk_version" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DTPlatformName string macosx" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DTPlatformVersion string $sdk_version" "$app_path/Contents/Info.plist"
{
    xcrun swift --version
    echo "SDK: $sdk_path ($sdk_version)"
    echo "Backend: native"
    xcrun vtool -show-build "$app_path/Contents/MacOS/Kiyobumi" || echo "Mach-O build inspection unavailable"
} > "$app_path/Contents/Resources/BuildInfo.txt"
for tile in cinema geometry jazz; do
  [[ -s "macOS/Themes/$tile.png" ]] || { echo "Missing theme tile: $tile" >&2; exit 1; }
done
mkdir -p "$app_path/Contents/Resources/Themes"
cp macOS/Themes/*.png "$app_path/Contents/Resources/Themes/"
cp -R macOS/ja.lproj "$app_path/Contents/Resources/"
cp rust/target/release/one-import "$app_path/Contents/Resources/one-import"
cp -R third_party "$app_path/Contents/Resources/"
./scripts/build-icon.sh "$app_path/Contents/Resources/Kiyobumi.icns"
codesign --force --sign - "$app_path/Contents/Resources/one-import"
codesign --force --sign - "$app_path"
echo "Built: $app_path"
echo 'Launch with: open dist/Kiyobumi.app'

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Install this application on a Mac.' >&2; exit 1; }
desktop_alias=false
if [[ "${1:-}" == --desktop ]]; then desktop_alias=true
elif [[ -n "${1:-}" ]]; then echo 'Usage: ./scripts/install-macos.sh [--desktop]' >&2; exit 1; fi
source_app="$PWD/dist/Kiyobumi.app"
[[ -d "$source_app" ]] || { echo 'Build first: ./scripts/build-macos.sh' >&2; exit 1; }
if pgrep -x Kiyobumi >/dev/null; then
    echo 'Quit Kiyobumi first so your notebook finishes saving, then run this installer again.' >&2
    exit 1
fi
codesign --verify --deep --strict "$source_app"
install_root="$HOME/Applications"
install_app="$install_root/Kiyobumi.app"
mkdir -p "$install_root"
if [[ -e "$install_app" || -L "$install_app" ]]; then
    [[ -d "$install_app" && ! -L "$install_app" ]] || { echo 'An unrelated item occupies the installation path.' >&2; exit 1; }
    installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$install_app/Contents/Info.plist")
    [[ "$installed_id" == org.opennotebook.desktop ]] || { echo 'An unrelated application occupies the installation path.' >&2; exit 1; }
fi
install_work=$(mktemp -d "$install_root/.Kiyobumi-install.XXXXXX")
trap 'if [[ -d "$install_work/previous.app" && ! -e "$install_app" ]]; then mv "$install_work/previous.app" "$install_app"; fi; rm -rf "$install_work"' EXIT
ditto "$source_app" "$install_work/Kiyobumi.app"
codesign --verify --deep --strict "$install_work/Kiyobumi.app"
if [[ -d "$install_app" ]]; then mv "$install_app" "$install_work/previous.app"; fi
mv "$install_work/Kiyobumi.app" "$install_app"
if $desktop_alias; then
    if ! osascript - "$install_app" <<'APPLESCRIPT'
on run arguments
    set applicationFile to POSIX file (item 1 of arguments) as alias
    tell application "Finder"
        if not (exists item "Kiyobumi" of desktop) then
            make new alias file at desktop to applicationFile with properties {name:"Kiyobumi"}
        end if
    end tell
end run
APPLESCRIPT
    then
        echo 'The app is installed. macOS did not allow the Desktop alias; you can open it from ~/Applications.' >&2
    fi
fi
echo "Installed: $install_app"
echo 'For a Dock shortcut: right-click the running icon, then Options > Keep in Dock.'
open "$install_app"

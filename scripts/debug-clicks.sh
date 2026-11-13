#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_binary="$PWD/dist/Kiyobumi.app/Contents/MacOS/Kiyobumi"
if [[ ! -x "$app_binary" ]]; then
  echo 'Build first with ./scripts/build-macos.sh' >&2
  exit 1
fi
echo 'Quit other Kiyobumi instances first. Two-finger click blank paper, then copy the KiyobumiClick lines from this terminal.'
echo 'Diagnostics contain event types and geometry, not notebook text.'
export KIYOBUMI_CLICK_DEBUG=1
exec "$app_binary"

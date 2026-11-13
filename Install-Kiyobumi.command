#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f "$HOME/.cargo/env" ]]; then . "$HOME/.cargo/env"; fi
./scripts/build-macos.sh
./scripts/install-macos.sh --desktop

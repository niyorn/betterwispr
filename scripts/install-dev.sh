#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# The local certificate is self-signed, so build-app.sh never finds it on its own.
identity="${CODESIGN_IDENTITY:-BetterWispr Local}"
target="/Applications/BetterWispr Dev.app"
data="$HOME/Library/Application Support/BetterWispr Dev"

app="$(BETTERWISPR_VARIANT=dev CODESIGN_IDENTITY="$identity" ./scripts/build-app.sh release | tail -1)"

# Share the installed app's models so the Dev app never downloads them again.
if [[ ! -e "$data" ]]; then
    mkdir -m 700 "$data"
    ln -s "../BetterWispr/Models" "$data/Models"
fi

if pgrep -f "BetterWispr Dev.app/Contents/MacOS" >/dev/null; then
    osascript -e 'tell application id "org.betterwispr.app.dev" to quit'
    while pgrep -f "BetterWispr Dev.app/Contents/MacOS" >/dev/null; do sleep 0.2; done
fi
rm -rf "$target"
ditto "$app" "$target"
open "$target"
echo "$target"

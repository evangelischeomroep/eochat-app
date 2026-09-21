#!/bin/zsh
# usage: shot.sh <name> [light|dark]  -> shots/<name>-<theme>.png and a 900px copy for reading.
# Switching appearance dismisses transient native menus; capture those first.
set -e
S=$(cd "$(dirname "$0")" && pwd); mkdir -p "$S/shots"
name=$1; theme=${2:-}
if [[ -n $theme ]]; then xcrun simctl ui booted appearance $theme; sleep 1.2; fi
theme=${theme:-$(xcrun simctl ui booted appearance)}
out="$S/shots/${name}-${theme}.png"
xcrun simctl io booted screenshot "$out" >/dev/null 2>&1   # absolute path required
sips -Z 900 "$out" --out "$S/shots/${name}-${theme}-small.png" >/dev/null 2>&1
echo "$S/shots/${name}-${theme}-small.png"

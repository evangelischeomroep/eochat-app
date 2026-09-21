#!/bin/zsh
# usage: type.sh "<text>"   -> types into the focused field via CGEvent
S=$(cd "$(dirname "$0")" && pwd); [[ -x $S/simtap ]] || "$S/build.sh" >/dev/null
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1; sleep 0.3
"$S/simtap" type "$1"

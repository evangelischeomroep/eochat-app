#!/bin/zsh
# usage: key.sh <mac virtual keycode>   (36 = return, 51 = delete, 53 = escape)
S=$(cd "$(dirname "$0")" && pwd); [[ -x $S/simtap ]] || "$S/build.sh" >/dev/null
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1; sleep 0.3
"$S/simtap" key "$1"

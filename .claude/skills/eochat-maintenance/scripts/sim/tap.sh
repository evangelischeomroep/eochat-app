#!/bin/zsh
# usage: tap.sh <x_pt> <y_pt>   device points -> CGEvent click. Needs .offset from calibrate.sh.
S=$(cd "$(dirname "$0")" && pwd)
[[ -f $S/.offset ]] || { echo "run calibrate.sh first"; exit 1; }
source "$S/.offset"
[[ -x $S/simtap ]] || "$S/build.sh" >/dev/null
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1; sleep 0.3
"$S/simtap" click $((OX + $1)) $((OY + $2)); echo "clicked device $1,$2 -> screen $((OX + $1)),$((OY + $2))"

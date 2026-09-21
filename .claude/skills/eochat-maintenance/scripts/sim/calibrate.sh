#!/bin/zsh
# usage: calibrate.sh "<label>" <x_pt> <y_pt>
# Finds the control by accessibility description, reads its centre on screen,
# and stores the screen offset for tap.sh in .offset. Rerun when the Simulator
# window moves (other display, other Space, resized).
set -e
S=$(cd "$(dirname "$0")" && pwd)
c=$(osascript "$S/axpress.scpt" "$1" center 2>&1 || true)
[[ $c == center* ]] || { echo "$c"; echo "hint: -1719 means System Events sees no Simulator window (other Space or display, or not booted)"; exit 1; }
read _ x y <<< "$c"
OX=$(( x - $2 )); OY=$(( y - $3 ))
echo "OX=$OX OY=$OY" > "$S/.offset"
echo "offset stored: OX=$OX OY=$OY (from '$1' at screen $x,$y = device $2,$3)"

#!/bin/zsh
# usage: press.sh "<label substring>"  -> AXPress on the first matching element; falls back to a CG click at its centre.
# Matches on accessibility description *containing* the text; use the most specific substring.
S=$(cd "$(dirname "$0")" && pwd)
[[ -x $S/simtap ]] || "$S/build.sh" >/dev/null
out=$(osascript "$S/axpress.scpt" "$1" press 2>&1)
if [[ $out == pressed* ]]; then echo "$out"; exit 0; fi
c=$(osascript "$S/axpress.scpt" "$1" center 2>&1)
if [[ $c == center* ]]; then read _ x y <<< "$c"; osascript -e 'tell application "Simulator" to activate' >/dev/null; sleep 0.3; "$S/simtap" click $x $y; echo "cg-clicked $1 at $x,$y"; else echo "$c"; exit 1; fi

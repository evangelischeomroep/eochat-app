#!/bin/zsh
# usage: crop.sh <name> <theme> <y_pt> <h_pt>  -> shots/<name>-<theme>-crop.png (full-width band, downscaled)
# sips quirk: a crop whose offset + height equals the image height is silently ignored, hence the clamp.
set -e
S=$(cd "$(dirname "$0")" && pwd)
src="$S/shots/$1-$2.png"; [[ -f $src ]] || { echo "missing $src"; exit 1; }
w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
scale=3
y=$(( $3 * scale )); h=$(( $4 * scale ))
if (( y + h >= H )); then h=$(( H - y - 1 )); fi
out="$S/shots/$1-$2-crop.png"
sips -c $h $w --cropOffset $y 0 "$src" --out "$out" >/dev/null 2>&1
sips -Z 900 "$out" >/dev/null 2>&1
echo "$out"

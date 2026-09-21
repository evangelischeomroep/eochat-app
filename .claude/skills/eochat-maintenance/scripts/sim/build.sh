#!/bin/zsh
# Compile the CGEvent helper once. Needs Xcode command line tools.
set -e
S=$(cd "$(dirname "$0")" && pwd)
swiftc -O "$S/simtap.swift" -o "$S/simtap"
echo "built $S/simtap"

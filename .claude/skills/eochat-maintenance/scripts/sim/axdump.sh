#!/bin/zsh
# Dump the Simulator accessibility tree: role | description | value | x,y wxh. Slow on long lists.
S=$(cd "$(dirname "$0")" && pwd)
osascript "$S/axdump.scpt"

#!/bin/zsh
# Boot the simulator and start the debug app detached. Log and pid land next to this script.
# usage: run-app.sh [udid]
set -e
S=$(cd "$(dirname "$0")" && pwd)
UDID=${1:-25726C04-D2A9-4CB2-9EBC-3E1F4C4EA49A}
REPO=$(cd "$S/../../../../.." && pwd)
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
cd "$REPO"
nohup flutter run -d "$UDID" --dart-define=FORCE_SSO_ONLY=false > "$S/flutter_run.log" 2>&1 &
echo $! > "$S/flutter_run.pid"
echo "log: $S/flutter_run.log   pid: $(cat "$S/flutter_run.pid")"
echo "wait for 'Flutter run key commands' in the log before tapping"

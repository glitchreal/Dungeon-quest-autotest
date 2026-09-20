#!/bin/sh
# DQ autotest watchdog (supervised, on-demand only).
# Detects RobloxPlayer crashes and prepares recovery. Never installs itself.
# Usage: DQ_PRIVATE_LINK='roblox://...' ./tools/dq-watchdog.sh [check|recover]
# State: testing/watchdog-state.json  Stop: testing/STOP
set -u
STATE="testing/watchdog-state.json"
STOPFILE="testing/STOP"
MAX_FAILS=3

is_running() {
  pgrep -x RobloxPlayer >/dev/null 2>&1 && return 0
  pgrep -f "Roblox\.app/Contents/MacOS/RobloxPlayer" >/dev/null 2>&1 && return 0
  return 1
}

fails() { python3 -c "import json;print(json.load(open('$STATE')).get('consecutiveFailures',0))" 2>/dev/null || echo 0; }
bump() {
  python3 - "$STATE" <<'EOF'
import json,sys,os
p=sys.argv[1]
try: s=json.load(open(p))
except Exception: s={"consecutiveFailures":0}
s["consecutiveFailures"]=s.get("consecutiveFailures",0)+1
open(p,"w").write(json.dumps(s,indent=2))
EOF
}
reset() {
  python3 - "$STATE" <<'EOF'
import json,sys
p=sys.argv[1]
try: s=json.load(open(p))
except Exception: s={}
s["consecutiveFailures"]=0
open(p,"w").write(json.dumps(s,indent=2))
EOF
}

if [ -f "$STOPFILE" ]; then echo "STOP present, exiting"; exit 0; fi

case "${1:-check}" in
  check)
    if is_running; then echo "RobloxPlayer running"; exit 0; fi
    echo "RobloxPlayer NOT running (check MCP responsiveness in OpenCode before declaring a crash; dungeon teleports change JobId, not process liveness)"
    exit 1
    ;;
  recover)
    F=$(fails)
    if [ "$F" -ge "$MAX_FAILS" ]; then echo "Too many consecutive failures ($F). Stopping safely."; exit 2; fi
    if [ -z "${DQ_PRIVATE_LINK:-}" ]; then echo "DQ_PRIVATE_LINK not set. Ask user for authorized private-server link; do not invent one."; exit 3; fi
    N=$((F+1))
    SLEEP_S=$((N*N*20))
    echo "Recovery attempt $N/$MAX_FAILS after ${SLEEP_S}s backoff..."
    sleep "$SLEEP_S"
    # Open the authorized private link (NOT plain `open -a Roblox`, which does not join DQ).
    open "$DQ_PRIVATE_LINK"
    # Wait for load + MacSploit/MCP reconnect; caller verifies game+client before resuming.
    sleep 45
    if is_running; then echo "RobloxPlayer process present; verify MCP client + PlaceId in OpenCode next"; exit 0; fi
    bump
    echo "Recovery attempt failed"
    exit 1
    ;;
  reset) reset; echo "failure counter reset";;
  *) echo "usage: $0 [check|recover|reset]"; exit 4;;
esac

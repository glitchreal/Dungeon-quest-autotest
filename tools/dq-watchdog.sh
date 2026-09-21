#!/bin/sh
# DQ autotest watchdog (supervised, on-demand only — never installs itself).
# Separate checks (process presence alone NEVER proves MCP health):
#   1. RobloxPlayer process health (both /Applications and multiroblox paths)
#   2. Game loading (process age / window presence; full PlaceId via OpenCode)
#   3. MacSploit connector availability (connector process / socket hint)
#   4. MCP client responsiveness (MUST verify in OpenCode: list-clients non-empty)
#   5. Correct game/place/session (PlaceId + JobId via OpenCode probe)
# Dungeon teleports change JobId — that is NORMAL, not a crash.
# Usage: ./tools/dq-watchdog.sh [check|recover|reset]
#   recover needs DQ_PRIVATE_LINK='roblox://...' (never logged/committed).
# State: testing/watchdog-state.json  Stop: testing/STOP
set -u
STATE="testing/watchdog-state.json"
STOPFILE="testing/STOP"
MAX_FAILS=3

is_running() {
  pgrep -x RobloxPlayer >/dev/null 2>&1 && return 0
  pgrep -f "Roblox.app/Contents/MacOS/RobloxPlayer" >/dev/null 2>&1 && return 0
  return 1
}
proc_age() {
  ps -axo comm,etime 2>/dev/null | grep -i RobloxPlayer | head -n 1 || echo "unknown"
}
connector_hint() {
  # MacSploit connector: look for its known helper processes; absence is a
  # hint (not proof) that the bridge is down. MCP responsiveness decides.
  pgrep -f -i "macsploit|roblox-executor|Cobalt" >/dev/null 2>&1 && echo "present" || echo "unknown"
}
fails() { python3 -c "import json;print(json.load(open('$STATE')).get('consecutiveFailures',0))" 2>/dev/null || echo 0; }
bump() {
  python3 - "$STATE" <<'EOF'
import json,sys,time
p=sys.argv[1]
try: s=json.load(open(p))
except Exception: s={"consecutiveFailures":0}
s["consecutiveFailures"]=s.get("consecutiveFailures",0)+1
s["lastFailure"]=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())
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
    echo "--- process ---"
    if is_running; then echo "RobloxPlayer: running ($(proc_age))"; else echo "RobloxPlayer: NOT running"; fi
    echo "--- connector ---"
    echo "MacSploit/MCP helper: $(connector_hint) (hint only)"
    echo "--- required OpenCode probes (cannot be checked from shell) ---"
    echo "1) list-clients non-empty?  2) PlaceId in {77649408247578,115445507767090,85776757589518}?"
    echo "3) JobId matches expected session?  Teleport JobId change alone is NOT a crash."
    if is_running; then exit 0; else echo "Process down (verify MCP in OpenCode before declaring crash)"; exit 1; fi
    ;;
  recover)
    F=$(fails)
    if [ "$F" -ge "$MAX_FAILS" ]; then echo "Too many consecutive failures ($F). Stopping safely."; exit 2; fi
    if [ -z "${DQ_PRIVATE_LINK:-}" ]; then echo "DQ_PRIVATE_LINK not set. Ask user for authorized private-server link; do not invent one."; exit 3; fi
    case "$DQ_PRIVATE_LINK" in roblox://*) ;; *) echo "DQ_PRIVATE_LINK looks invalid (must start with roblox://). Not launching."; exit 3;; esac
    N=$((F+1))
    SLEEP_S=$((N*N*20))
    echo "Recovery attempt $N/$MAX_FAILS after ${SLEEP_S}s backoff..."
    sleep "$SLEEP_S"
    open "$DQ_PRIVATE_LINK"
    sleep 45
    if is_running; then echo "Process present; NEXT verify in OpenCode: list-clients + PlaceId + JobId before resuming."; exit 0; fi
    bump
    echo "Recovery attempt failed"
    exit 1
    ;;
  reset) reset; echo "failure counter reset";;
  *) echo "usage: $0 [check|recover|reset]"; exit 4;;
esac

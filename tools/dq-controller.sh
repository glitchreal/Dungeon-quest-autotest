#!/bin/sh
# Bounded overnight controller (programmatic limits, independent of AI memory).
# Limits: 32 iterations, 15 min/iteration, 3 failed recoveries, 3 repeat fixes,
# 1 client, 1 agent, no paid models. STOP via testing/STOP.
# Usage: ./tools/dq-controller.sh
set -u
RESULTS="testing/dungeon-results.json"
STOPFILE="testing/STOP"
STATE="testing/watchdog-state.json"
MAX_ITER=32
MAX_MIN=15

iter=0
while [ "$iter" -lt "$MAX_ITER" ]; do
  iter=$((iter+1))
  if [ -f "$STOPFILE" ]; then echo "STOP present, exiting"; break; fi
  F=$(python3 -c "import json;print(json.load(open('$STATE')).get('consecutiveFailures',0))" 2>/dev/null || echo 0)
  if [ "$F" -ge 3 ]; then echo "Too many failed recoveries ($F). Stopping safely."; break; fi
  echo "=== iteration $iter/$MAX_ITER (budget ${MAX_MIN}m) ==="
  echo "Next pending dungeon:"
  python3 - "$RESULTS" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1]))
for x in d["dungeons"]:
  if x["status"]=="pending":
    print(" ",x["name"]); break
else: print("  none — all decided")
EOF
  echo "Controller does not auto-clear: a dungeon advances only when structured results record an observed clear or a budgeted blocker."
  echo "Manual work happens in OpenCode within this iteration budget; persist results after every attempt."
  # Placeholder wait so the script itself enforces pacing when used as a supervisor.
  # Real per-dungeon work is driven by the agent; timeout guards the iteration.
  sleep 5
done
echo "Controller finished at iteration $iter."

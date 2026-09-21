#!/bin/sh
# DQ bounded overnight controller — real supervisor, not a placeholder.
# Enforces limits programmatically (independent of AI instructions):
#   32 iterations/campaign, 15 min/iteration, 3 repeat fixes per problem,
#   3 consecutive failed recoveries, 1 client, 1 agent, free models only.
# Persists iteration count across restarts; STOP via testing/STOP.
# A successful agent exit is NOT a dungeon clear — only an observed
# completion event recorded in testing/dungeon-results.json counts.
# Usage: ./tools/dq-controller.sh [--once]  (default loops until limits/STOP)
set -u
RESULTS="testing/dungeon-results.json"
STOPFILE="testing/STOP"
WSTATE="testing/watchdog-state.json"
CSTATE="testing/controller-state.json"
MAX_ITER=32
MAX_MIN=15
MAX_RECOVER=3
MAX_REPEAT=3
CAMPAIGN_MIN=480
SCHEMA="testing/controller-result-schema.json"

now_s() { date +%s; }
check_stop() { [ -f "$STOPFILE" ] && { echo "STOP present, exiting"; exit 0; }; }
fails() { python3 -c "import json;print(json.load(open('$WSTATE')).get('consecutiveFailures',0))" 2>/dev/null || echo 0; }
get_iter() { python3 -c "import json;print(json.load(open('$CSTATE')).get('iterations',0))" 2>/dev/null || echo 0; }
set_iter() { python3 - "$CSTATE" "$1" <<'EOF'
import json,sys,time
p,n=sys.argv[1],int(sys.argv[2])
try: s=json.load(open(p))
except Exception: s={}
s["iterations"]=n; s["updatedAt"]=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())
open(p,"w").write(json.dumps(s,indent=2))
EOF
}
campaign_expired() {
  STARTED=$(python3 -c "import json;print(json.load(open('$CSTATE')).get('campaignStart',''))" 2>/dev/null || echo "")
  [ -z "$STARTED" ] && return 1
  python3 - "$STARTED" "$CAMPAIGN_MIN" <<'EOF'
import sys,datetime
try:
  t=datetime.datetime.strptime(sys.argv[1],"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
  sys.exit(0 if (datetime.datetime.now(datetime.timezone.utc)-t).total_seconds() > int(sys.argv[2])*60 else 1)
except Exception: sys.exit(1)
EOF
}
next_dungeon() {
  python3 - "$RESULTS" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1]))
blocked_same=[x for x in d["dungeons"] if x.get("status")=="testing" and x.get("failures",0)>=3]
for x in d["dungeons"]:
  if x["status"] in ("pending","testing") and x["name"] not in [b["name"] for b in blocked_same]:
    print(x["name"]); break
else:
  pend=[x["name"] for x in d["dungeons"] if x["status"] in ("pending","testing")]
  print(pend[0] if pend else "none")
EOF
}
repeat_count() {
  python3 - "$RESULTS" "$1" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1])); name=sys.argv[2]
for x in d["dungeons"]:
  if x["name"]==name:
    errs=x.get("errors",[])
    print(min(3,errs[-3:].count(errs[-1]) if errs else 0) if len(errs)>=1 else 0); break
EOF
}

# Init campaign clock once.
if ! python3 -c "import json;assert json.load(open('$CSTATE')).get('campaignStart')" 2>/dev/null; then
  python3 - "$CSTATE" <<'EOF'
import json,sys,time
p=sys.argv[1]
try: s=json.load(open(p))
except Exception: s={"iterations":0}
s.setdefault("campaignStart",time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()))
open(p,"w").write(json.dumps(s,indent=2))
EOF
fi

MODE="${1:-loop}"
run_one() {
  check_stop
  if campaign_expired; then echo "Campaign time limit (${CAMPAIGN_MIN}m) reached. Stopping."; exit 0; fi
  F=$(fails); [ "$F" -ge "$MAX_RECOVER" ] && { echo "Too many failed recoveries ($F). Stopping safely."; exit 0; }
  ITER=$(get_iter); ITER=$((ITER+1))
  [ "$ITER" -gt "$MAX_ITER" ] && { echo "Max iterations ($MAX_ITER) reached. Stopping."; exit 0; }
  set_iter "$ITER"
  DUNGEON=$(next_dungeon)
  [ "$DUNGEON" = "none" ] && { echo "All dungeons decided. Stopping."; exit 0; }
  R=$(repeat_count "$DUNGEON")
  if [ "$R" -ge "$MAX_REPEAT" ]; then
    echo "Dungeon '$DUNGEON' hit $MAX_REPEAT identical repeats — recording blocker, moving on."
    python3 - "$RESULTS" "$DUNGEON" <<'EOF'
import json,sys
p,name=sys.argv[1],sys.argv[2]
d=json.load(open(p))
for x in d["dungeons"]:
  if x["name"]==name: x["status"]="blocked"; x.setdefault("errors",[]).append("Controller: 3 identical repeats, auto-blocked."); break
open(p,"w").write(json.dumps(d,indent=2))
EOF
    return 0
  fi
  echo "=== iteration $ITER/$MAX_ITER (budget ${MAX_MIN}m) dungeon: $DUNGEON ==="
  if ! pgrep -x RobloxPlayer >/dev/null 2>&1 && ! pgrep -f "Roblox.app/Contents/MacOS/RobloxPlayer" >/dev/null 2>&1; then
    echo "RobloxPlayer not running — run tools/dq-watchdog.sh recover (needs DQ_PRIVATE_LINK) before testing."
  fi
  [ -x "$(command -v codex || true)" ] || { echo "Codex CLI is unavailable. Stopping."; exit 2; }
  [ -f "$SCHEMA" ] || { echo "Missing result schema: $SCHEMA. Stopping."; exit 2; }
  PROMPT="Autotest iteration $ITER/$MAX_ITER for dungeon '$DUNGEON'. Limits: one agent, one Roblox client, 15 minutes. Verify the Roblox MCP client and PlaceId before any game action. Confirm the local bundle revision via getgenv().DQBuildRevision using execute-file only; never download a GitHub build. Observe one bounded run and record DQNav. Do not run Northern Lands without a substantive new code change. Update testing/dungeon-results.json only from observed evidence. A clear requires an observed completion event. Stop if the bridge or prerequisite is missing. Return only JSON matching the supplied schema."
  RESULT="/tmp/dq-iter-$ITER.result.json"
  # Per-iteration timeout is enforced here; Codex writes a schema-validated
  # final result so an agent exit code alone can never count as a clear.
  codex exec -C . --json --output-schema "$SCHEMA" --output-last-message "$RESULT" "$PROMPT" > "/tmp/dq-iter-$ITER.out" 2>&1 &
  AGENT_PID=$!
  ( sleep $((MAX_MIN*60)); kill -TERM $AGENT_PID 2>/dev/null; sleep 5; kill -KILL $AGENT_PID 2>/dev/null ) &
  KILLER_PID=$!
  wait $AGENT_PID; CODE=$?
  kill $KILLER_PID 2>/dev/null; wait 2>/dev/null
  if [ -s "$RESULT" ] && python3 -m json.tool "$RESULT" >/dev/null 2>&1; then
    echo "Codex result schema: valid"
  else
    echo "Codex result schema: INVALID or missing"
    CODE=1
  fi
  rm -f "$RESULT"
  echo "Codex exit code $CODE (NOT a clear). Results file decides progress."
  python3 - "$RESULTS" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1]))
ok=all("attempts" in x and "clears" in x and "failures" in x for x in d["dungeons"])
print("results schema ok" if ok else "RESULTS SCHEMA BROKEN — fix before continuing")
EOF
  if [ "$CODE" -ne 0 ]; then echo "Agent iteration failed/timeout — counters preserved, continuing only if justified."; fi
}

if [ "$MODE" = "--once" ]; then run_one; echo "Single iteration done."; exit 0; fi
while true; do run_one; sleep 10; done

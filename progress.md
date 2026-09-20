# Progress

## Repository setup (2026-09-20)
- Original (upstream, read-only): https://github.com/glitchreal/Dungeon-quest
- Autotest (origin): https://github.com/glitchreal/Dungeon-quest-autotest
- Visibility: PRIVATE
- Local branch: main @ fc256b9ae819547d7937f0691b51bf7820bb22c9
- Verified: origin/main == upstream/main == local HEAD at setup time.
- Remote policy:
  - `origin` = autotest repo (fetch + push). All future commits/pushes target ONLY origin.
  - `upstream` = original repo (fetch only, push disabled via `no_push`).
  - `remote.pushDefault` = origin.
- Rule: never push to upstream. Never commit credentials, private server links, webhook URLs, logs with secrets, or sensitive executor config.

## Autonomous campaign (2026-09-20)
- Phase 1: DONE. New private repo `https://github.com/glitchreal/Dungeon-quest-autotest` (origin); original is upstream fetch-only.
- Phase 2: DONE (inspect). Lobby: AutoCreate/AutoStart + raid tiers (`src/Lobby.luau`, `src/GameAdapter.luau`). Dungeon: owner autostart (`src/Dungeon.luau`). Combat: `src/CombatController.luau` (2648 lines) + Ability/Farm/ThreatGeometry; SoloHitless defaults on; 8-stud blink budget; checkpoints/waypoints/stuck recovery; teleport continuation via queue_on_teleport snapshot; webhooks/stats. No `dq-map-scans` found — none to reuse. Build clean: `lua build.lua` reproduces `dist/` identically.
- Phase 3: DONE (verify). Free model responding (Muse Spark Free). `roblox-mcp`: 17 tools, client `VanguardAttacker` (userId 11044000891) in `[2x Luck] Dungeon Quest Reborn`, PlaceId 77649408247578 (supported lobby), ServerType StandardServer. Active client set. Read-only probes only; no gameplay scripts executed.
- Phase 4: SCAFFOLD DONE, recovery NOT yet demonstrated. Watchdog `tools/dq-watchdog.sh` detects RobloxPlayer (handles both `/Applications` and multiroblox-cache paths; never confuses CrashHandler), max 3 failures with quadratic backoff, no persistent install. BLOCKER: current session is StandardServer, not a private session; `open -a Roblox` does not join DQ. Need authorized private-server link to implement/verify rejoin. Will not invent one.
- Phase 5: SCAFFOLD DONE, controlled load test NOT yet run. MCP connector autoexecutes (`roblox-executor-mcp.lua`); DQ script does not. Guard `testing/local-guard.luau` is PlaceId-gated + duplicate-safe; latest local build via execute-file only. Needs one controlled test + approval before unattended use.
- Phase 6: SCAFFOLD DONE. Live queue probe: level 201, 19 dungeons visible (Aquatic Temple first pending; includes Ghastly Harbor → Northern Lands). Matrix `testing/dungeon-results.json` persists all required fields; clears only on observed completion, hitless only on zero damage.
- Phase 9: SCAFFOLD DONE. `tools/dq-controller.sh` enforces 32 iters / 15 min / 3 recoveries / 3 repeat fixes / 1 client / 1 agent / no paid models + STOP file. macOS has no `timeout` cmd — iteration timeout must be enforced by caller/supervisor.
- Next: need from user (a) authorized private-server link (or confirmation StandardServer is acceptable), (b) approval for one controlled local-build load test in the lobby, (c) explicit approval before any overnight run. No dungeon clears claimed yet.

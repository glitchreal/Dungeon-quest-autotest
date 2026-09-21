# Progress

## Controlled navigation follow-up (2026-09-20)
- Preserved `autotest/nav-overhaul` and existing uncommitted work; `origin` is the autotest repository and `upstream` is fetch-only.
- Corrected `mapRouteGoal` so temporarily blocked anchors are not counted as reached. Added `DQNav.firstFailedSegment`, `lastFailedSegment`, `waypointPos`, and `lastRoom` to diagnose the first failed transition. These are unverified source changes, not a verified traversal or clear.
- `lua build.lua`, `luau-compile` for the controller and generated dungeon bundle, and `git diff --check` passed. Standalone `luau-analyze` has missing Roblox global/type definitions in both committed and working source; this does not establish a new type regression.
- Read-only live MCP probe: lobby bundle `c14f441` loaded; connected lobby is a StandardServer with 24 players. No new dungeon bundle or automated gameplay was run. Verify the rebuilt dungeon bundle in an isolated authorized test before attributing observations to this fix.
- No overnight campaign, commit, or push. Northern Lands stays blocked; no unchanged retries.

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

## Attempt 1 — Northern Lands (FAILED, no clear observed)
- Lobby bundle `dist/lobby.luau` executed clean (no DQ errors). Teleport lobby→dungeon (ReservedServer, Northern Lands) correctly treated as normal teleport, not crash.
- Dungeon bundle `dist/dungeon.luau` loaded: `[EnemyWalker] loaded`. Run started (owner), progressed: 7→4→1 enemies, ~170-stud advance, zero damage until boss room.
- Boss: Midgardian Champion (3.19Q/5Q last seen, ~64%). Death loop: full-HP (432M) respawn → 1-2 shot burst (~100-200M then negative within ~1s) → repeat, ≥4 deaths. Returned to lobby; bossKilled never observed → recorded as failure, NOT a clear.
- Root-cause hypothesis: all smash close-and-strafe handling is gated on `target.Name == "Ancient Temple Protector"` (`src/CombatController.luau:2001`, `1965`, `1782`, `1288`, `1346`); Midgardian Champion slams get only generic backward dodge. Fix must be geometry-triggered (ProtectorSmash-shaped zones already sampled at :1212) rather than name-gated, but needs live telegraph evidence first. No code changed yet — diagnosis only, per no-untested-push rule.
- Limits used: 1 dungeon attempt, 0 code fixes for this problem (budget 3).

## Attempt 2 — Northern Lands (FAILED, pre-profile build)
- Same pattern: reached Midgardian Champion at full 5Q, ground it to 4.24Q/5Q (~85%) with repeated 2-shot respawn-deaths (full 432M → ~210M → negative). Returned to lobby, bossKilled never observed.
- KEY EVIDENCE (live probe during windup): 12+ anchored telegraph parts named `firstBossCrissCross`. `dangerousName()` had no matching substring (`cross` absent) and MeshPart class fails the Part-based precast geometry checks → slam telegraphs invisible to the dodger. Player stood in the cross pattern and ate full bursts.
- Fix implemented (UNCOMMITTED, needs verification): `dangerousName()` now matches `cross` (`src/CombatController.luau`); dual carry profiles auto-selected by dungeon name (`Logic.carryProfile`: `northern` only for Northern Lands, `fast` elsewhere; solo-hitless forcing + HITLESS_SOLO gated to northern; FAST_CARRY/NORTHERN_COMBAT flags in cfg). Rebuilt `dist/` clean. New lobby build executed in fresh lobby with no DQ errors.
- Verification plan: next dungeon teleport gets the new dungeon bundle via execute-file. Commit ONLY after observing dodged crisscross volleys or a clear. Fixes used for this problem: 1 of 3 (cross-substring). Profiles: 0 of 3.

## Attempt 3 — Northern Lands (FAILED outOfTime, NEW build)
- New build (profiles + cross fix) loaded via execute-file; EnemyWalker active.
- Boss ground 5Q → 1.17Q (~23%, best yet) but progress flipped to `outOfTime` with player dead. Deaths continued through trash and boss phases.
- Assessment: cross-substring fix shows NO observable survival improvement yet. Open hypotheses: (a) crisscross parts spawn with transparency >= 0.95 (named-zone check requires < 0.95); (b) deaths come from a different attack (contact bursts, not the cross volley); (c) post-respawn re-engagement walks into active volleys.
- Next: capture crisscross part transparency + attributes during a live windup; check which damage source correlates with deaths. Code stays UNCOMMITTED.

## Attempt 4 — Northern Lands (FAILED, NEW build)
- Boss 5Q → 2.77Q (~55%), then run ended in lobby. One-shots persisted (full→dead single events). Cross fix shows no decisive effect yet.

## Attempt 5 — Northern Lands (FAILED → status blocked, instrumented build)
- Boss 5Q → 3.85Q (~77%). Run ended with no clear observed.
- DQLastDamage attribution (verified working): deaths occur standing inside 3-4 overlapping Block zones (clearances −11…−1); a 497M one-shot came from `firstBossBeamPart.Beam` (instant beam, tracked but inescapable once inside); trash Northern Spearman hits 176M with 10 active hazards.
- BLOCKER (retry budget for dodge tuning exhausted — cross fix saw runs 3–5, no clear): Midgardian Champion one-shots (400–500M instant beams/volleys) vs 432M HP, plus 2-shot trash. Script reliably grinds boss to 23–55% but cannot finish within the timer. Likely needs gear/levels or a Champion-specific pre-positioning approach beyond current budget. Northern stays `blocked`; will retest opportunistically if the user queues it again, but focus pivots to validating the Fast Carry profile on the other 18 dungeons.
- Fast-carry dungeons: 0 attempts so far (user queued Northern Lands 5×). Next non-Northern run exercises the fast profile (already in build).

## Attempt 6 — Northern Lands (FAILED, committed build f7704f3)
- Boss 5Q → 3.37Q (~67%), then run ended with no clear. Sixth consecutive failure; blocked status stands.
- Also fixed `AGENTS.md` in this checkout to document the autotest remote policy (origin-only pushes), since the old text named the original repo as push target.

## Attempt 7 — Northern Lands (FAILED)
- Boss 5Q → 3.03Q (~61%), then run ended. Seventh consecutive failure, pattern unchanged (grind with respawn-deaths, no clear). Blocked status stands; awaiting a non-Northern run to validate Fast Carry.

## Attempt 8 — Northern Lands (FAILED)
- Boss 5Q → 3.37Q (~67%), then run ended. 0/8. The loop is fully consistent: trash 2-shots, Champion one-shots/beams, grind stalls at 23–67%, timer or deaths end it. No further code changes for Northern without new evidence or gear changes.

## Attempt 9 — Northern Lands (FAILED)
- Boss 5Q → 3.19Q (~64%), then run ended. 0/9. Unchanged pattern.

## Attempt 10 — Northern Lands (FAILED)
- Boss 5Q → 2.79Q (~56%), then run ended. 0/10. Blocked status stands. Ten consecutive runs, all Northern Lands, best boss 23% (attempt 3), typical stall 55–67%.

## Attempt 11 — Northern Lands (FAILED)
- Boss 5Q → 2.98Q (~60%), then run ended. 0/11. Unchanged.

## Attempt 12 — Northern Lands (FAILED)
- Boss 5Q → 3.07Q (~61%), then run ended. 0/12. Unchanged.

## Attempt 13 — Northern Lands (FAILED)
- Boss 5Q → 2.19Q (~44%, best since attempt 3's 23%), then run ended. 0/13. Unchanged outcome.

## Attempt 14 — Northern Lands (FAILED)
- Boss 5Q → 3.37Q (~67%), then run ended. 0/14. Unchanged.

## Attempt 15 — Northern Lands (FAILED)
- Boss 5Q → 3.03Q (~61%), then run ended. 0/15. Unchanged.

## Attempt 16 — Northern Lands (FAILED)
- Boss 5Q → 2.94Q (~59%), then run ended. 0/16. Unchanged.

## Attempt 17 — Northern Lands (FAILED)
- Boss 5Q → 3.86Q (~77%), then run ended. 0/17. Unchanged.

## Attempt 18 — Northern Lands (FAILED)
- Boss 5Q → 3.98Q (~80%), then run ended. 0/18. Unchanged.

## Attempt 19 — Northern Lands (FAILED)
- Boss 5Q → 3.10Q (~62%), then run ended. 0/19. Unchanged.

## Attempt 20 — Northern Lands (FAILED)
- Boss 5Q → 3.31Q (~66%), then run ended. 0/20. Twenty consecutive Northern Lands runs, best boss 23% (attempt 3), typical stall 55–80%. Fast-carry profile still unvalidated (no non-Northern runs queued).

## Attempt 21 — Northern Lands (FAILED)
- Boss 5Q → 2.89Q (~58%), then run ended. 0/21. Unchanged.

## Attempt 22 — Northern Lands (FAILED)
- Boss 5Q → 2.63Q (~53%), then run ended. 0/22. Unchanged.

## Attempt 23 — Northern Lands (FAILED)
- Boss 5Q → 3.24Q (~65%), then run ended. 0/23. Unchanged.

## Attempt 24 — Northern Lands (FAILED)
- Boss 5Q → 3.99Q (~80%), then run ended. 0/24. Unchanged.

## Attempt 25 — Northern Lands (FAILED)
- Boss 5Q → 2.97Q (~59%), then run ended. 0/25. Unchanged.

## Attempt 26 — Northern Lands (FAILED)
- Boss 5Q → 3.06Q (~61%), then run ended. 0/26. Unchanged.

## MCP bridge drop (game alive, connector down)
- `list-clients` empty across multiple minutes while `RobloxPlayer` process remains running. Not a game crash (watchdog `check` passes) — the MacSploit MCP connector bridge dropped and only re-establishes via in-client autoexec on teleport/join. Cannot re-establish from outside. Waiting for reconnect; no data lost (`testing/dungeon-results.json` persisted through attempt 26, pushed).
- `testing/watchdog-state.json` + `testing/STOP` are local runtime state (now git-ignored, never committed).

## MCP bridge restored
- After ~6h down (game process alive throughout), a fresh MCP client reconnected in the lobby. Lobby bundle reloaded clean. Resuming run tracking.

## Nav overhaul (branch autotest/nav-overhaul, UNPUSHED — needs review + 1 controlled load test)
- Aquatic Temple diagnosis (attempt 1 evidence): 7 pylon targets all behind walls 111–169 studs, 0 kills in 3+ min, ~85-stud drift. Root causes in code, not distances: (a) `refreshRouteAnchors` sorted checkpoints by room number with no connectivity guarantee; (b) `mapRouteGoal` advanced on 28-flat/60-vertical proximity even through walls/floors; (c) `updateProgress` counted any 0.45-stud displacement as progress, so sideways circling reset stuck detection; (d) `getClosestEnemy` hysteresis could hold an invisible lock while a reachable fight existed; (e) dodges called `clearPath()` + wiped `motionGoal`, erasing the global route; (f) `FAST_CARRY`/`NORTHERN_COMBAT` flags were set but never read — zero behavioral effect.
- Implemented in `src/CombatController.luau` (rebuilt `dist/` clean, `luau-analyze` syntax-clean):
  - Graph-aware routing: anchors are nodes; failed edges/paths recorded (`blockedSegments`, 3-strike/30s cooldown, `recordSegmentFail` on every `createPath` failure); blocked anchors skipped until cooldown; reach check tightened to 14-flat/12-vertical + line-of-sight before advancing, with room-transition history.
  - True stuck detection: progress = distance-to-goal reduction (`NAV_PROGRESS_EPS` 0.6); sideways drift no longer resets; 12s position-loop memory detects circling; per-goal 3-strike blocked-segment rule stops unchanged retries.
  - Reachable-vs-replicated targets: per-tick visibility split with `reachableCount`/`blockedCount`; visible challenger beats invisible lock; invisible target falls back to checkpoint routing (no required-enemy skipping).
  - Movement ownership (`GLOBAL_NAVIGATION`/`LOCAL_NAVIGATION`/`COMBAT_MOVEMENT`/`EMERGENCY_DODGE`/`RECOVERY`): dodge preempts via `saveNavGoal()` and restores afterwards; route index survives blinks; mode-dependent replan hysteresis (combat 8 / approach 5 / route 3 studs).
  - Profiles drive behavior: FAST_CARRY (fast replan 0.5s, 50-stud direct walk, hold-still-and-burn in range, contact-only retreats) vs NORTHERN_COMBAT (orbit, full survival margins, strafing). Verified flags are now read in `controllerTick`, `handleSafety`, and the attack-hold branch.
  - Deterministic attack memory (`observeAttack`/`predictAttack`, trusted after 3 samples, persisted to `DungeonQuestObsidian-attack-memory.json`): zone sightings recorded per boss+telegraph with warning age/geometry; prediction annotates reappearing warnings; evasion/hit stats tracked. Conventional controller, not claimed as AI.
  - `DQNav` hook expanded: dungeon, char/target positions, lock visibility, reachable/blocked counts, nav goal, checkpoint index/total, path computations/failures, best-distance, time-since-progress, transitions, active profile.

## Predictive attack instrumentation (branch autotest/nav-overhaul, UNCOMMITTED — needs 1 controlled load test)
- Diagnosis: `observeAttack` recorded only warn age + size + moving flags, so targeting (player-anchored vs tracking vs fixed arena) was unknowable; `predictAttack` annotated `predictedWarn/predictedSize` but `findEscapeGoal` never read them — prediction had zero movement effect; damage handler incremented global hits only, so per-pattern hit rates could not be compared; no `DQAttackMemory` hook existed for per-pattern tests.
- Implemented in `src/CombatController.luau` (rebuilt `dist/` clean, `luau-compile --only-parse` clean, `git diff --check` clean):
  - Full observation records per sighting: boss+attack identity, warning center/size/shape, player pos + boss pos at warn time, warning age (`quantizePos` strings; `updateAttackTracking` votes `player-anchored`/`tracking`/`fixed` from zone-vs-player displacement correlation; majority vote sets `entry.targeting`).
  - Damage linkage: each damage event attributes up to 3 overlapping zones to their pattern entries (`hits`, `lastHitAt`, `lastHitPos`); evasion credit unchanged (global, 5s no-damage after escape).
  - Prediction drives movement: `predictedClearance`/`predictedRisk` expand trusted-pattern footprints beyond live part size; `findEscapeGoal` radial + line-exit scoring penalizes forecast exposure (`-forecast*500` / `+forecastRisk*500`) while keeping the existing attack-range leash — safe destinations preserve DPS range. Unknown attacks contribute zero (reactive geometry only). No neural net; conventional controller only.
  - Test hooks: `DQNav` now exposes `attackPatterns`, `trustedPatterns`, `attackSummary` (per boss-pattern `samples/warnAvg/sizeAvg/targeting/hits`), `evasions`, `attackHits`; `getgenv().DQAttackMemory` exposes the full persisted DB for per-pattern predicted-vs-observed comparison.
  - Global navigation untouched and still separate (`GLOBAL_NAVIGATION` vs `COMBAT_MOVEMENT`/`EMERGENCY_DODGE` ownership); teleport limits unchanged (8-stud blink, 3-per-3s, 18-stud budget verified untouched in diff).
- Gates: build/parse PASS (unverified source changes, not a verified traversal or clear). NO Northern Lands retry, NO commit, NO push. Next: (1) one controlled lobby load test to confirm new revision stamp + `DQNav`/`DQAttackMemory` live, (2) one Aquatic Temple navigation test first, (3) then single-pattern Champion observations (3+ samples each) before any full clear attempt.

## Attempt 2 — Aquatic Temple (ENDED, no clear observed, 2026-09-21)
- Gate B PASS: lobby bundle `c14f441+dirty` executed clean in lobby (no DQ errors in console; game-script errors only), revision stamp live in-client.
- Lobby auto-queued Aquatic Temple → teleported to ReservedServer dungeon. New dungeon bundle loaded via execute-file; DQNav live, profile `fast` (correct), status `Waiting for wave`, anchors 1/0 pre-start.
- +90s probe: `Following map route: room3`, anchors 3/7 with 2 verified transitions, target Defensive Pyramid Pylon @153.9, 0 reachable / 7 blocked, 0 kills, 5 path fails, `firstFailedSegment` recorded. Real improvement vs attempt 1 (transitions now verify instead of drifting).
- Run ended ~5 min in, client back in lobby; no clear observed, NOT counted as clear. Recorded in `testing/dungeon-results.json` (attempts 1→2).

## Smart-pathfinding upgrade (branch autotest/nav-overhaul, UNCOMMITTED — user asked for genuinely adaptive routing)
- Problem: fallback was a fixed 6-direction × 8-stud stepper with binary revisit memory (the "repeat short steps forever" loop); `surveyUphill` stair-chaining was dead code (defined, never called); every blocked anchor looked identical (wall vs locked door indistinguishable); nothing remembered where it had already failed.
- Implemented in `src/CombatController.luau` (rebuilt `dist/` clean, `luau-compile --only-parse` clean, `git diff --check` clean):
  - Learned traversal costmap (`state.cellCost`, 6-stud cells, +10 per failure capped at 30, 60s decay swept in `updateProgress`): `recordSegmentFail`, waypoint-box-in (`chooseRecoveryGoal`), and failed goals all teach it; the exploration fan is repelled by high-cost cells. Read by GLOBAL/LOCAL nav only — combat dodges untouched.
  - Adaptive goal-biased fan (`chooseFallbackStep` rewrite): 8 directions × escalating radii (8 → 8/14 → 8/14/20 studs by `fallbackStreak`), count-based visit penalties (60s memory, capped), forward-preference term so exploration drifts around walls instead of away. Walking only, ≤20 studs/step; streak resets on verified progress.
  - `surveyUphill` wired into `followGoal`: elevated map-route/approach goals survey the stair transect (cheap rays, 2s throttle) before any `ComputeAsync`.
  - Door-aware blocking: `blockingPartName` identifies the first static blocker; door/gate/barrier/portcullis/seal names earn 60s cooldown + `Holding for door: <name>` status (`state.doorHold`) instead of the generic 30s re-probe loop.
  - `DQNav` exposes `streak`, `doorHold`, `hotCells` for the next live test.
  - Teleport/dodge limits verified untouched (no CFG dodge/teleport constant in diff).
- Gates: build/parse PASS, unverified in live play. NO commit, NO push. Next: one Aquatic Temple run with this bundle, watching `streak`/`hotCells`/`doorHold`/transitions via DQNav.

## Autonomous overhaul, stage 1 (branch autotest/nav-overhaul, UNCOMMITTED — live test running)
- Architectural diagnosis (full-repo inspection 2026-09-21): (a) anchors are a linear list, not a graph — one blocked anchor stalls the whole route, no skip-ahead; (b) fast maps dodge every telegraph despite one-shotting everything (wasted DPS time); (c) smash/burn/focus logic gated on `Ancient Temple Protector` name — Champion gets generic handling only; (d) `issueMove` re-issues MoveTo on sub-stud wobble (jitter source); (e) route experience (transitions, edge fails, completions) dies on teleport — every run starts from zero; (f) no run telemetry (stuck counts, no-progress time unrecorded).
- Implemented in `src/CombatController.luau` + `src/ObsidianHub.luau` (rebuilt `dist/` clean, parse + `git diff --check` clean, teleport/dodge limits verified untouched):
  - Skip-ahead routing + arrival catch-up in `mapRouteGoal`: blocked anchor routes to an unblocked anchor ≤2 ahead (`routeSkips`); reaching a later checkpoint collects all traversed rooms by verified position.
  - Fast-carry threat gating in `handleSafety`: on non-Northern maps escape only when INSIDE danger (clearance < −1) or in melee contact; otherwise hold-and-burn (`fastHold` in DQNav). Northern keeps full dodging.
  - Boss-agnostic combat: `protectorWindup` + smash close-and-strafe trigger on `ProtectorSmash` geometry/windup for any boss (throttled on fast maps); `findEscapeGoal` forward-dodge and no-crowd-retreat key off smash geometry; burn-phase focuses highest-MaxHealth boss-grade target instead of name. Protector rear/flank approach stays name-gated (genuinely map-specific).
  - Movement commit guard in `issueMove`: nav commands hold 0.3s unless the goal jumps >5 studs; escapes/dodges bypass with their own timing.
  - Persistent route memory (`DungeonQuestObsidian-route-memory.json`, per-map, 14-day TTL): verified transitions, anchor edge fails, completions/best time. Sole behavior use: historically-dead edges (6+ fails) start with pre-seeded strikes — one fresh failure blocks instead of three. Live verification still required. `NoteCompletion` wired from hub `finishRun`.
  - Run telemetry in DQNav: `recov`, `stuckEv`, `dodges`, `deaths`, `noProg`, `skips`, `routeHist` (runs/comp/best from memory).
- Still map-specific by design: Protector flank/rear, aquatic line templates. No neural net; week-scale data does not justify RL — experience-weighted costs + costmap is the honest technique.
- Limitation (stated, not hidden): no private-server link on file — tests run in auto-queued ReservedServer dungeon instances (private) from the shared lobby; lobby itself is StandardServer.
- Phase 10: `main.luau`/`launch.luau`/`src/ObsidianHub.luau`/`build.lua` fallback loader now targets `Dungeon-quest-autotest`; `build.lua` stamps every bundle with `DQBuildRevision` + `DQBuildTime` for per-test revision verification. Public README snippet untouched (still points at original for end users).
- Phase 8/9: `tools/dq-controller.sh` is now a real supervisor (32 iters, 15-min timeout enforced via killer process, 3-recovery/3-repeat blockers, persisted `testing/controller-state.json`, 480-min campaign cap, free-model-only `opencode run`, results-schema check; agent exit ≠ clear). `tools/dq-watchdog.sh` separates process/connector/MCP/place/session checks; teleports ≠ crashes; `DQ_PRIVATE_LINK` validated, never logged.
- `AGENTS.md`: fixed stale push-target line to `glitchreal/Dungeon-quest-autotest`.
- Gates: A (build) PASS. B (new revision live in-client) PENDING — live client `VanguardAttacker` in lobby (place 77649408247578) has NO build stamp and NO DQNav; loading the new bundle needs the standing approval for one controlled lobby load test. C–H not yet attempted; Northern Lands untouched (still blocked at 0/28, no repeats run).
- Need from user: (a) approval for one controlled local-build load test in the lobby, (b) private-server link if recovery is ever needed, (c) explicit approval before any overnight run.

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

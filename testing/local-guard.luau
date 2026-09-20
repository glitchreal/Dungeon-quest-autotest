-- Local guarded loader for controlled tests (Phase 5).
-- Runs the latest LOCAL build via execute-file, never a stale GitHub copy.
-- PlaceId-gated, duplicate-safe, automation stays off by default.
local env = getgenv()
local SUPPORTED = {
  [77649408247578] = "lobby",
  [115445507767090] = "lobby",
  [85776757589518] = "dungeon",
}
local route = SUPPORTED[game.PlaceId]
if not route then
  warn("[DQAutotest] Refusing to run in unsupported place: " .. tostring(game.PlaceId))
  return
end
if env.DQAutotestRunning and env.DQAutotestJob == game.JobId then
  warn("[DQAutotest] Already running in this job; skipping duplicate.")
  return
end
env.DQAutotestRunning = true
env.DQAutotestJob = game.JobId
warn("[DQAutotest] Local build check in place " .. tostring(game.PlaceId) .. " (" .. route .. ")")
-- Automation toggles default off; this file only proves the bundle loads.
-- Full execution uses execute-file on dist/<route>.luau from OpenCode.
env.DQAutotestRunning = nil

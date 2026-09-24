local MODE = "Lobby"

-- Shared Obsidian controls remain configurable without loading combat code.
local function createController()
    local state = { running = false, closed = false, status = "In lobby", kills = 0, cachedTargets = {} }
    return {
        Config = {}, State = state,
        SetRunning = function() state.running = false end,
        SetWaypoints = function() end,
        Shutdown = function() state.closed = true end,
    }
end

local function queueAction(config, now, arrivedAt)
    if not Adapter.level() then return "Waiting for player data" end
    if config.AutoRaid then
        local lobby = Adapter.findLobby(true)
        if lobby then
            if now - arrivedAt < config.StartDelay then return nil, "Waiting to start" end
            Adapter.call("startBossRaid")
            return nil, "Starting raid"
        end
        local tiers = Logic.raidTiers(Adapter.inventory())
        local tier = config.AdvanceTier and tiers[#tiers] or tonumber(config.RaidTier)
        if not tier or not table.find(tiers, tier) then return nil, "Locked: no selected raid key" end
        local created = Adapter.call("createBossLobby", tier, config.PrivateLobby, 0)
        return nil, created and ("Created tier " .. tier) or "Server declined raid lobby"
    end

    local existing = Adapter.findLobby(false)
    if existing then
        if config.AutoStart and now - arrivedAt >= config.StartDelay then
            if not Adapter.isLobbyHost(existing) then return "Lobby ready (waiting for host)" end
            local ok, err = pcall(Adapter.call, "startDungeon")
            if ok then return "Starting dungeon" end
            return "Start failed: " .. tostring(err):sub(1, 80)
        end
        return "Lobby ready"
    end
    if config.AutoCreate then
        return Adapter.createLobby(config) and "Lobby created" or "Server declined lobby"
    end
    return "Waiting for a lobby"
end

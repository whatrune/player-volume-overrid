local KVP_KEY = "pvo:licenseVolumes"

-- Saved data
-- volumesByLicense["license:xxxx"] = 0.8
local volumesByLicense = {}

-- Current online map
-- playerMapById[12] = { license = "license:xxxx", name = "PlayerName" }
local playerMapById = {}

-- ===== Utilities =====

local function notify(msg)
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 255 },
        multiline = false,
        args = { "[PVO]", msg }
    })
end

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function saveVolumes()
    local encoded = json.encode(volumesByLicense)
    SetResourceKvp(KVP_KEY, encoded)
end

local function loadVolumes()
    local raw = GetResourceKvpString(KVP_KEY)
    if raw and raw ~= "" then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == "table" then
            volumesByLicense = decoded
        end
    end
end

local function clearOverrideByServerId(serverId)
    -- -1.0 = clear override
    MumbleSetVolumeOverrideByServerId(serverId, -1.0)
end

local function applyOverrideToServerId(serverId, volume)
    MumbleSetVolumeOverrideByServerId(serverId, volume)
end

local function reapplyAllOnlineOverrides()
    for sid, entry in pairs(playerMapById) do
        local license = entry and entry.license
        local vol = license and volumesByLicense[license]

        if vol ~= nil then
            applyOverrideToServerId(tonumber(sid), vol)
        else
            -- Clear unnecessary overrides just in case
            clearOverrideByServerId(tonumber(sid))
        end
    end
end

local function requestPlayerMap()
    TriggerServerEvent("pvo:requestPlayerMap")
end

local function getDisplayKey(license)
    -- Short display key (license is long)
    if type(license) ~= "string" then return tostring(license) end
    if #license <= 18 then return license end
    return ("...%s"):format(license:sub(-12))
end

-- ===== Events =====

RegisterNetEvent("pvo:receivePlayerMap", function(map)
    playerMapById = map or {}
    reapplyAllOnlineOverrides()
end)

-- ===== Commands =====
-- /pv [serverId] [0.1~0.9]
RegisterCommand("pv", function(_, args)
    local sid = tonumber(args[1])
    local vol = tonumber(args[2])

    if not sid or not vol then
        notify("Usage: /pv [serverId] [0.1~0.9] Example: /pv 12 0.8")
        return
    end

    vol = clamp(vol, 0.1, 0.9)

    local entry = playerMapById[sid]
    local license = entry and entry.license
    local playerName = entry and entry.name or ("ID %d"):format(sid)

    if not license then
        notify(("Could not resolve identifier for ID %d yet. Please wait a few seconds and try again."):format(sid))
        requestPlayerMap()
        return
    end

    volumesByLicense[license] = vol
    saveVolumes()

    applyOverrideToServerId(sid, vol)
    notify(("Set volume for ID %d (%s) to %.2f"):format(sid, playerName, vol))
end, false)

-- /pvreset [serverId]
RegisterCommand("pvreset", function(_, args)
    local sid = tonumber(args[1])
    if not sid then
        notify("Usage: /pvreset [serverId]")
        return
    end

    local entry = playerMapById[sid]
    local license = entry and entry.license
    local playerName = entry and entry.name or ("ID %d"):format(sid)

    if not license then
        notify(("Could not resolve identifier for ID %d yet. Please wait a few seconds and try again."):format(sid))
        requestPlayerMap()
        return
    end

    volumesByLicense[license] = nil
    saveVolumes()

    clearOverrideByServerId(sid)
    notify(("Reset volume for ID %d (%s) to default"):format(sid, playerName))
end, false)

-- /pvlist
RegisterCommand("pvlist", function()
    local count = 0

    -- Reverse map: license -> "ID xx (Name)"
    local onlineByLicense = {}
    for sid, entry in pairs(playerMapById) do
        if entry and entry.license then
            onlineByLicense[entry.license] = ("ID %s (%s)"):format(sid, entry.name or "Unknown")
        end
    end

    for license, vol in pairs(volumesByLicense) do
        count = count + 1
        local label = onlineByLicense[license] or ("Offline %s"):format(getDisplayKey(license))
        notify(("%s => %.2f"):format(label, vol))
    end

    if count == 0 then
        notify("No per-player volume settings saved.")
    end
end, false)

-- /pvmute [serverId] (hard mute)
RegisterCommand("pvmute", function(_, args)
    local sid = tonumber(args[1])
    if not sid then
        notify("Usage: /pvmute [serverId]")
        return
    end

    local entry = playerMapById[sid]
    local license = entry and entry.license
    local playerName = entry and entry.name or ("ID %d"):format(sid)

    if not license then
        notify(("Could not resolve identifier for ID %d yet. Please wait a few seconds and try again."):format(sid))
        requestPlayerMap()
        return
    end

    volumesByLicense[license] = 0.0
    saveVolumes()

    applyOverrideToServerId(sid, 0.0)
    notify(("Muted ID %d (%s)"):format(sid, playerName))
end, false)

-- ===== Lifecycle =====

CreateThread(function()
    Wait(1500)
    loadVolumes()
    requestPlayerMap()
    -- startup message hidden on purpose
    -- notify("player-volume-override loaded. Commands: /pv /pvreset /pvlist")
end)

-- Re-fetch player map and re-apply periodically (handles reconnect / ID changes)
CreateThread(function()
    while true do
        Wait(15000)
        requestPlayerMap()
    end
end)

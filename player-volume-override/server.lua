local function getLicenseIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if id:sub(1, 8) == "license:" then
            return id
        end
    end
    return nil
end

RegisterNetEvent("pvo:requestPlayerMap", function()
    local src = source
    local map = {}

    for _, playerSrc in ipairs(GetPlayers()) do
        local sid = tonumber(playerSrc)
        local license = getLicenseIdentifier(sid)
        local name = GetPlayerName(playerSrc) or ("Player %s"):format(playerSrc)

        if sid and license then
            map[sid] = {
                license = license,
                name = name
            }
        end
    end

    TriggerClientEvent("pvo:receivePlayerMap", src, map)
end)

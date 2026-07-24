--- Haengt getragene Taschen als Prop an den Ped. Quelle ist der replizierte
--- Statebag 'cmdPatrolbag', damit auch andere Spieler die Tasche sehen.

---@type table<number, table<string, number>>
local attached = {}

---@param serverId number
---@param bagKey string
local function detach(serverId, bagKey)
    local props = attached[serverId]
    local prop = props and props[bagKey]

    if not prop then return end

    if DoesEntityExist(prop) then
        DeleteEntity(prop)
    end

    props[bagKey] = nil

    if not next(props) then
        attached[serverId] = nil
    end
end

---@param serverId number
local function detachAll(serverId)
    local props = attached[serverId]

    if not props then return end

    for bagKey in pairs(props) do
        detach(serverId, bagKey)
    end
end

---@param ped number
---@param serverId number
---@param bagKey string
---@param carry table
local function attach(ped, serverId, bagKey, carry)
    if attached[serverId]?[bagKey] then return end

    if not pcall(lib.requestModel, carry.model, 5000) then
        return lib.print.error(locale('error.invalid_model', carry.model, bagKey))
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(carry.model, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(carry.model)

    if not DoesEntityExist(prop) then return end

    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, carry.bone),
        carry.offset.x, carry.offset.y, carry.offset.z,
        carry.rotation.x, carry.rotation.y, carry.rotation.z,
        true, true, false, true, 1, true)

    attached[serverId] = attached[serverId] or {}
    attached[serverId][bagKey] = prop
end

--- Trage-Animation des eigenen Peds. Fremde Peds animiert deren Client
--- selbst, deshalb laeuft das nur lokal.
---@return table? carry
local function getOwnCarryAnim()
    local state = LocalPlayer.state.cmdPatrolbag

    if type(state) ~= 'table' then return end

    for key, bag in pairs(Shared.bags) do
        if state[key] and bag.carry?.dict then return bag.carry end
    end
end

--- Haelt die Trage-Animation am Leben: Waffe ziehen, Fahrzeuge und andere
--- Emotes brechen sie ab, danach muss sie neu gestartet werden.
CreateThread(function()
    local playing

    while true do
        local carry = getOwnCarryAnim()

        if not carry then
            if playing then
                StopAnimTask(cache.ped, playing.dict, playing.anim, 1.0)
                playing = nil
            end

            Wait(500)
            goto continue
        end

        -- In Fahrzeugen und beim Schwimmen wuerde die Animation stoeren.
        if cache.vehicle or IsPedSwimming(cache.ped) or IsPedRagdoll(cache.ped) then
            playing = nil
            Wait(500)
            goto continue
        end

        if not IsEntityPlayingAnim(cache.ped, carry.dict, carry.anim, 3) then
            if pcall(lib.requestAnimDict, carry.dict, 5000) then
                -- Flag 49 = loop + upper body only + allow player movement.
                TaskPlayAnim(cache.ped, carry.dict, carry.anim, 3.0, 3.0, -1, 49, 0.0, false, false, false)
                playing = carry
            else
                lib.print.error(locale('error.invalid_anim', carry.dict))
                Wait(5000)
            end
        end

        Wait(500)

        ::continue::
    end
end)

--- Gleicht die Props eines Spielers mit seinem Statebag ab.
---@param serverId number
---@param state? table<string, boolean>
local function refresh(serverId, state)
    local playerId = GetPlayerFromServerId(serverId)

    if playerId == -1 then return detachAll(serverId) end

    local ped = GetPlayerPed(playerId)

    if not DoesEntityExist(ped) then return detachAll(serverId) end

    for key, bag in pairs(Shared.bags) do
        if bag.carry then
            if state?[key] then
                attach(ped, serverId, key, bag.carry)
            else
                detach(serverId, key)
            end
        end
    end
end

AddStateBagChangeHandler('cmdPatrolbag', nil, function(bagName, _, value)
    local serverId = tonumber(bagName:gsub('player:', ''), 10)

    if not serverId then return end

    -- Der Ped existiert bei einem frisch gestreamten Spieler evtl. noch nicht.
    CreateThread(function() refresh(serverId, value) end)
end)

--- Spieler, die erst spaeter in Streaming-Reichweite kommen, senden keinen
--- Statebag-Change: deren Zustand wird zyklisch nachgezogen.
CreateThread(function()
    while true do
        Wait(2000)

        local active = {}

        for _, playerId in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(playerId)
            local state = Player(serverId).state.cmdPatrolbag

            active[serverId] = true

            if type(state) == 'table' then
                refresh(serverId, state)
            end
        end

        -- Props von Spielern entfernen, die ausser Reichweite sind.
        for serverId in pairs(attached) do
            if not active[serverId] then
                detachAll(serverId)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for serverId in pairs(attached) do
        detachAll(serverId)
    end
end)

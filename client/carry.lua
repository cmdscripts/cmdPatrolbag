local attached = {}
local pending = {}

local function detach(serverId, bagKey)
    local props = attached[serverId]
    local entry = props and props[bagKey]

    if not entry then return end

    if DoesEntityExist(entry.prop) then
        DeleteEntity(entry.prop)
    end

    props[bagKey] = nil

    if not next(props) then
        attached[serverId] = nil
    end
end

local function detachAll(serverId)
    local props = attached[serverId]

    if not props then return end

    for bagKey in pairs(props) do
        detach(serverId, bagKey)
    end
end

local function isAttached(serverId, bagKey, ped)
    local entry = attached[serverId]?[bagKey]

    return entry ~= nil
        and entry.ped == ped
        and DoesEntityExist(entry.prop)
        and IsEntityAttachedToEntity(entry.prop, ped)
end

local function attach(ped, serverId, bagKey, carry)
    if isAttached(serverId, bagKey, ped) then return end

    local lock = ('%s:%s'):format(serverId, bagKey)

    if pending[lock] then return end

    pending[lock] = true
    detach(serverId, bagKey)

    if not pcall(lib.requestModel, carry.model, 5000) then
        pending[lock] = nil
        return lib.print.error(locale('error.invalid_model', carry.model, bagKey))
    end

    local state = Player(serverId).state.cmdPatrolbag

    if not DoesEntityExist(ped) or type(state) ~= 'table' or not state[bagKey] then
        pending[lock] = nil
        SetModelAsNoLongerNeeded(carry.model)
        return
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(carry.model, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(carry.model)
    pending[lock] = nil

    if not DoesEntityExist(prop) then return end

    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, carry.bone),
        carry.offset.x, carry.offset.y, carry.offset.z,
        carry.rotation.x, carry.rotation.y, carry.rotation.z,
        true, true, false, true, 1, true)

    attached[serverId] = attached[serverId] or {}
    attached[serverId][bagKey] = { prop = prop, ped = ped }
end

local function getOwnCarryAnim()
    local state = LocalPlayer.state.cmdPatrolbag

    if type(state) ~= 'table' then return end

    for key, bag in pairs(Shared.bags) do
        if state[key] and bag.carry?.dict then return bag.carry end
    end
end

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

        if cache.vehicle or IsPedSwimming(cache.ped) or IsPedRagdoll(cache.ped) then
            playing = nil
            Wait(500)
            goto continue
        end

        if not IsEntityPlayingAnim(cache.ped, carry.dict, carry.anim, 3) then
            if pcall(lib.requestAnimDict, carry.dict, 5000) then
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

    CreateThread(function() refresh(serverId, value) end)
end)

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

        for serverId in pairs(attached) do
            if not active[serverId] then
                detachAll(serverId)
            end
        end
    end
end)

local bagItems = {}

for _, bag in pairs(Shared.bags) do
    bagItems[bag.item] = true
end

AddEventHandler('ox_inventory:itemCount', function(itemName)
    if bagItems[itemName] then
        TriggerServerEvent('cmdPatrolbag:syncState')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for serverId in pairs(attached) do
        detachAll(serverId)
    end
end)

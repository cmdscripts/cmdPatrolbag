local ox = exports.ox_inventory
local registered = {}
local stashCount = 0
local cooldowns = {}
local attempts = {}

local function notify(src, message, type)
    TriggerClientEvent('cmdPatrolbag:notify', src, message, type or 'inform')
end

local function isRateLimited(src)
    local now = GetGameTimer()
    local last = cooldowns[src]

    if last and now - last < Shared.actionCooldown then return true end

    local minute = math.floor(now / 60000)
    local record = attempts[src]

    if not record or record.minute ~= minute then
        record = { minute = minute, count = 0 }
        attempts[src] = record
    end

    if record.count >= Shared.maxActionsPerMinute then return true end

    cooldowns[src] = now
    record.count += 1

    return false
end

local function buildState(src)
    local state = {}

    for key, bag in pairs(Shared.bags) do
        state[key] = (ox:GetItemCount(src, bag.item) or 0) > 0
    end

    return state
end

function PushState(src)
    local player = Player(src)

    if player?.state then
        player.state:set('cmdPatrolbag', buildState(src), true)
    end
end

local pushState = PushState

local freeStashes = {}

local function claimIdentifier(bag)
    local pool = freeStashes[bag.key]
    local entry = pool and table.remove(pool)

    if entry then return entry.identifier, entry.owner end

    if stashCount >= Shared.maxStashes then
        lib.print.error(locale('error.stash_limit', Shared.maxStashes))
        return
    end

    return ('PBG-%s'):format(lib.string.random('AAAA1111AA'))
end

local function releaseIdentifier(bag, metadata)
    if not metadata.identifier or not registered[metadata.stashId] then return end

    freeStashes[bag.key] = freeStashes[bag.key] or {}
    table.insert(freeStashes[bag.key], { identifier = metadata.identifier, owner = metadata.owner })
end

local function ensureStash(bag, identifier, owner)
    local stashId = bag.stashPrefix .. identifier

    if registered[stashId] then return stashId end

    local ok = pcall(function()
        ox:RegisterStash(stashId, ('%s [%s]'):format(bag.label, identifier), bag.slots, bag.weight, owner)
    end)

    if not ok then return end

    registered[stashId] = true
    stashCount += 1

    return stashId
end

local function fillStash(stashId, bag)
    if not bag.items then return true end

    return pcall(function()
        for item, count in pairs(bag.items) do
            if count > 0 then ox:AddItem(stashId, item, count) end
        end
    end)
end

local function findBagSlot(src, bag)
    local slots = ox:Search(src, 'slots', bag.item)

    return type(slots) == 'table' and slots[1] or nil
end

local function openBagSlot(src, bag, slot)
    local metadata = slot.metadata or {}

    if not metadata.identifier then
        metadata.identifier, metadata.owner = claimIdentifier(bag)
    end

    metadata.owner = metadata.owner or Bridge.getOwner(src)

    local stashId = metadata.identifier and ensureStash(bag, metadata.identifier, metadata.owner)

    if not stashId then
        notify(src, locale('notify.open_error'), 'error')
        return false
    end

    if not metadata.filled then
        if not fillStash(stashId, bag) then
            notify(src, locale('notify.fill_error'), 'error')
            return false
        end

        metadata.filled = true
    end

    metadata.stashId = stashId
    metadata.bag = bag.key

    if not pcall(ox.SetMetadata, ox, src, slot.slot, metadata) then
        notify(src, locale('notify.update_error'), 'error')
        return false
    end

    TriggerClientEvent('cmdPatrolbag:openStash', src, stashId)

    return true
end

local function issueBag(src, bagKey)
    local bag = Shared.getBag(bagKey)

    if not bag then return false end

    if bag.onePerInventory and (ox:GetItemCount(src, bag.item) or 0) >= 1 then
        notify(src, locale('notify.already_have'), 'error')
        return false
    end

    if not ox:AddItem(src, bag.item, 1, { bag = bagKey }) then
        notify(src, locale('notify.no_space'), 'error')
        return false
    end

    pushState(src)
    notify(src, locale('notify.issued', bag.label), 'success')

    return true
end

local function returnBag(src, bagKey)
    local bag = Shared.getBag(bagKey)

    if not bag then return false end

    local slot = findBagSlot(src, bag)

    if not slot then
        notify(src, locale('notify.not_found'), 'error')
        return false
    end

    local metadata = slot.metadata or {}
    local cleared = metadata.stashId and pcall(ox.ClearInventory, ox, metadata.stashId)

    if not ox:RemoveItem(src, bag.item, 1, nil, slot.slot) then
        notify(src, locale('notify.remove_failed'), 'error')
        return false
    end

    if cleared then releaseIdentifier(bag, metadata) end

    pushState(src)
    notify(src, locale('notify.returned', bag.label), 'success')

    return true
end

local function isNearPoint(src, point)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then return false end

    local maxDistance = math.max(point.radius, 2.0) + Shared.interactTolerance

    return #(GetEntityCoords(ped) - point.coords.xyz) <= maxDistance
end

local function pointAction(handler)
    return function(src, pointId, bagKey)
        if isRateLimited(src) then
            notify(src, locale('notify.rate_limited'), 'error')
            return false
        end

        local point = Shared.getPoint(pointId)

        if not point or not Bridge.hasAccess(src, point.jobs) then
            notify(src, locale('notify.no_access'), 'error')
            return false
        end

        if not isNearPoint(src, point) then
            notify(src, locale('notify.too_far'), 'error')
            return false
        end

        if not Shared.pointHasBag(point, bagKey) then
            notify(src, locale('notify.not_available'), 'error')
            return false
        end

        return handler(src, bagKey)
    end
end

lib.callback.register('cmdPatrolbag:getPoint', function(src, pointId)
    local point = Shared.getPoint(pointId)

    if not point then return end
    if not Bridge.hasAccess(src, point.jobs) then return false end

    return { label = point.label, bags = point.bags, state = buildState(src) }
end)

lib.callback.register('cmdPatrolbag:take', pointAction(issueBag))
lib.callback.register('cmdPatrolbag:return', pointAction(returnBag))

RegisterNetEvent('cmdPatrolbag:useItem', function(slotId)
    local src = source

    if isRateLimited(src) or type(slotId) ~= 'number' then return end

    local slot = ox:GetSlot(src, slotId)

    if not slot then return end

    local bag = Shared.getBag(slot.metadata?.bag)

    if not bag or bag.item ~= slot.name then
        for _, candidate in pairs(Shared.bags) do
            if candidate.item == slot.name then
                bag = candidate
                break
            end
        end
    end

    if bag then openBagSlot(src, bag, slot) end
end)

local syncRequests = {}

RegisterNetEvent('cmdPatrolbag:syncState', function()
    local src = source
    local now = GetGameTimer()

    if syncRequests[src] and now - syncRequests[src] < 250 then return end

    syncRequests[src] = now
    pushState(src)
end)

Bridge.onPlayerLoaded(function(src)
    SetTimeout(1500, function() pushState(src) end)
end)

AddEventHandler('cmdPatrolbag:frameworkReady', function()
    for _, playerId in ipairs(GetPlayers()) do
        pushState(tonumber(playerId))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    cooldowns[src] = nil
    attempts[src] = nil
    syncRequests[src] = nil
end)

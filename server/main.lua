local ox = exports.ox_inventory
local registered = {}
local stashCount = 0
local cooldowns = {}
local attempts = {}

---@param src number
---@param message string
---@param type? 'inform' | 'error' | 'success'
local function notify(src, message, type)
    TriggerClientEvent('cmdPatrolbag:notify', src, message, type or 'inform')
end

---@param src number
---@return boolean blocked
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

---@param src number
---@return table<string, boolean>
local function buildState(src)
    local state = {}

    for key, bag in pairs(Shared.bags) do
        state[key] = (ox:GetItemCount(src, bag.item) or 0) > 0
    end

    return state
end

--- Repliziert, welche Taschen der Spieler traegt: die Clients haengen
--- daran die Trage-Props auf (client/carry.lua).
---@param src number
function PushState(src)
    local player = Player(src)

    if player?.state then
        player.state:set('cmdPatrolbag', buildState(src), true)
    end
end

local pushState = PushState

---@param bag table
---@param identifier string
---@return string? stashId
local function ensureStash(bag, identifier, owner)
    local stashId = bag.stashPrefix .. identifier

    if registered[stashId] then return stashId end

    if stashCount >= Shared.maxStashes then
        lib.print.error(locale('error.stash_limit', Shared.maxStashes))
        return
    end

    local ok = pcall(function()
        ox:RegisterStash(stashId, ('%s [%s]'):format(bag.label, identifier), bag.slots, bag.weight, owner)
    end)

    if not ok then return end

    registered[stashId] = true
    stashCount += 1

    return stashId
end

---@param stashId string
---@param bag table
local function fillStash(stashId, bag)
    if not bag.items then return true end

    return pcall(function()
        for item, count in pairs(bag.items) do
            if count > 0 then ox:AddItem(stashId, item, count) end
        end
    end)
end

---@param src number
---@param bag table
---@return table? slot
local function findBagSlot(src, bag)
    local slots = ox:Search(src, 'slots', bag.item)

    return type(slots) == 'table' and slots[1] or nil
end

--- Oeffnet die Tasche im Slot: erstellt Stash + Startinhalt beim ersten Mal.
---@param src number
---@param bag table
---@param slot table
---@return boolean
local function openBagSlot(src, bag, slot)
    local metadata = slot.metadata or {}

    if not metadata.identifier then
        metadata.identifier = ('PBG-%d'):format(math.random(Shared.identifierRange.min, Shared.identifierRange.max))
    end

    local stashId = ensureStash(bag, metadata.identifier, Bridge.getOwner(src))

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

---@param src number
---@param bagKey string
---@return boolean
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

---@param src number
---@param bagKey string
---@return boolean
local function returnBag(src, bagKey)
    local bag = Shared.getBag(bagKey)

    if not bag then return false end

    local slot = findBagSlot(src, bag)

    if not slot then
        notify(src, locale('notify.not_found'), 'error')
        return false
    end

    local stashId = slot.metadata?.stashId

    if stashId then pcall(ox.ClearInventory, ox, stashId) end

    if not ox:RemoveItem(src, bag.item, 1, nil, slot.slot) then
        notify(src, locale('notify.remove_failed'), 'error')
        return false
    end

    pushState(src)
    notify(src, locale('notify.returned', bag.label), 'success')

    return true
end

--- Punkt-Aktionen teilen sich Rate-Limit und Zugriffspruefung.
---@param handler fun(src: number, bagKey: string): boolean
---@return fun(src: number, pointId: string, bagKey: string): boolean
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

Bridge.onPlayerLoaded(function(src)
    SetTimeout(1500, function() pushState(src) end)
end)

AddEventHandler('playerDropped', function()
    local src = source

    cooldowns[src] = nil
    attempts[src] = nil
end)

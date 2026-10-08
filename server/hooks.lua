local ox = exports.ox_inventory

local function getItemFilter()
    local filter = {}

    for _, bag in pairs(Shared.bags) do
        filter[bag.item] = true
    end

    return filter
end

local function getPrefixes()
    local prefixes = {}

    for _, bag in pairs(Shared.bags) do
        prefixes[#prefixes + 1] = bag.stashPrefix
    end

    return prefixes
end

CreateThread(function()
    local ok = pcall(lib.waitFor, function()
        if GetResourceState('ox_inventory'):find('start') then return true end
    end, 'ox_inventory', 20000)

    if not ok then return end

    local itemFilter = getItemFilter()
    local prefixes = getPrefixes()

    ox:registerHook('swapItems', function(payload)
        local target = payload.toInventory

        if type(target) ~= 'string' then return true end

        for i = 1, #prefixes do
            if target:find(prefixes[i], 1, true) then
                TriggerClientEvent('cmdPatrolbag:notify', payload.source, locale('notify.bag_in_bag'), 'error')
                return false
            end
        end

        return true
    end, { print = false, itemFilter = itemFilter })

    ox:registerHook('swapItems', function(payload)
        local fromPlayer = payload.fromType == 'player' and payload.fromInventory
        local toPlayer = payload.toType == 'player' and payload.toInventory

        SetTimeout(0, function()
            if fromPlayer then PushState(fromPlayer) end
            if toPlayer and toPlayer ~= fromPlayer then PushState(toPlayer) end
        end)

        return true
    end, { print = false, itemFilter = itemFilter })

    ox:registerHook('createItem', function(payload)
        local inventory = payload.inventoryId

        if type(inventory) ~= 'number' then return end

        local itemName = payload.item and payload.item.name

        for _, bag in pairs(Shared.bags) do
            if bag.item == itemName and bag.onePerInventory then
                SetTimeout(0, function()
                    local slots = ox:Search(inventory, 'slots', bag.item)

                    if type(slots) ~= 'table' or #slots <= 1 then return end

                    local surplus = slots[#slots]

                    for i = #slots, 1, -1 do
                        if not slots[i].metadata?.identifier then
                            surplus = slots[i]
                            break
                        end
                    end

                    ox:RemoveItem(inventory, bag.item, 1, nil, surplus.slot)
                    TriggerClientEvent('cmdPatrolbag:notify', inventory, locale('notify.only_one_bag'), 'error')
                end)

                return
            end
        end
    end, { print = false, itemFilter = itemFilter })
end)

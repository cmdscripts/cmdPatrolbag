local ox = exports.ox_inventory

--- Alle Bag-Items als Filter fuer die Hooks: ox_inventory ruft sie damit
--- nur fuer diese Items auf, statt bei jeder Inventarbewegung im Server.
local function getItemFilter()
    local filter = {}

    for _, bag in pairs(Shared.bags) do
        filter[bag.item] = true
    end

    return filter
end

--- Stash-Praefixe aller Taschen; identifiziert Tasche-in-Tasche-Ziele.
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

    -- Verhindert, dass eine Tasche in einer Tasche landet: das umgeht
    -- Gewichtslimits und kann Inhalte unerreichbar machen.
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

    -- Der Hook laeuft VOR der Bewegung: der Statebag wird danach neu gebaut,
    -- damit das Trage-Prop verschwindet, sobald die Tasche z.B. im Kofferraum
    -- landet (und beim Herausnehmen wieder erscheint).
    ox:registerHook('swapItems', function(payload)
        local fromPlayer = payload.fromType == 'player' and payload.fromInventory
        local toPlayer = payload.toType == 'player' and payload.toInventory

        SetTimeout(0, function()
            if fromPlayer then PushState(fromPlayer) end
            if toPlayer and toPlayer ~= fromPlayer then PushState(toPlayer) end
        end)

        return true
    end, { print = false, itemFilter = itemFilter })

    -- Zweite Tasche derselben Art entfernen, wenn onePerInventory gilt.
    -- createItem wertet den Rueckgabewert nicht als Abbruch aus
    -- (items/server.lua:232 nutzt nur hooks.result als Metadata), deshalb
    -- wird die ueberzaehlige Tasche nach dem Erstellen wieder abgezogen.
    ox:registerHook('createItem', function(payload)
        local inventory = payload.inventoryId

        if type(inventory) ~= 'number' then return end

        local itemName = payload.item and payload.item.name

        for _, bag in pairs(Shared.bags) do
            if bag.item == itemName and bag.onePerInventory then
                SetTimeout(0, function()
                    if (ox:GetItemCount(inventory, bag.item) or 0) <= 1 then return end

                    ox:RemoveItem(inventory, bag.item, 1)
                    TriggerClientEvent('cmdPatrolbag:notify', inventory, locale('notify.only_one_bag'), 'error')
                end)

                return
            end
        end
    end, { print = false, itemFilter = itemFilter })
end)

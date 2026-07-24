local entities = {}

---@param message string
---@param type? string
local function notify(message, type)
    lib.notify({ title = locale('notify.title'), description = message, type = type })
end

--- Baut das Untermenue fuer eine Aktion und ruft den Server auf.
---@param point table
---@param action 'take' | 'open' | 'return'
---@param state table<string, boolean>
local function openBagMenu(point, action, state)
    local options = {}

    for _, bagKey in ipairs(point.bags) do
        local bag = Shared.getBag(bagKey)
        local owned = state[bagKey] == true

        -- Entnehmen zeigt nur fehlende, Abgeben nur vorhandene Taschen.
        if bag and owned ~= (action == 'take') then
            options[#options + 1] = {
                title = bag.label,
                icon = 'briefcase',
                arrow = true,
                onSelect = function()
                    lib.callback.await('cmdPatrolbag:' .. action, false, point.id, bagKey)
                end,
            }
        end
    end

    if #options == 0 then
        return notify(locale('notify.nothing_available'), 'error')
    end

    lib.registerContext({
        id = 'patrolbag_action',
        title = locale('menu.' .. action),
        menu = 'patrolbag_main',
        options = options,
    })

    lib.showContext('patrolbag_action')
end

---@param point table
local function openPointMenu(point)
    local data = lib.callback.await('cmdPatrolbag:getPoint', false, point.id)

    if not data then return end

    if data == false then
        return notify(locale('notify.no_access'), 'error')
    end

    local actions = {
        { action = 'take', icon = 'plus' },
        { action = 'return', icon = 'rotate-left' },
    }

    local options = {}

    for i = 1, #actions do
        options[i] = {
            title = locale('menu.' .. actions[i].action),
            icon = actions[i].icon,
            arrow = true,
            onSelect = function()
                openBagMenu(point, actions[i].action, data.state)
            end,
        }
    end

    lib.registerContext({ id = 'patrolbag_main', title = data.label, options = options })
    lib.showContext('patrolbag_main')
end

---@param point table
---@return number? entity
local function spawnEntity(point)
    local model = point.ped or point.prop

    if not model then return end

    local coords = point.coords

    -- Ungueltiges Modell in der Config darf den Punkt nicht zerstoeren:
    -- lib.requestModel wirft dann, der Punkt faellt auf Marker + [E] zurueck.
    if not pcall(lib.requestModel, model, 10000) then
        lib.print.error(locale('error.invalid_model', model, point.label))
        return
    end

    local entity = point.ped
        and CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        or CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, false, false)

    if not DoesEntityExist(entity) then return end

    SetEntityHeading(entity, coords.w)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)

    if point.ped then
        SetBlockingOfNonTemporaryEvents(entity, true)
    end

    SetModelAsNoLongerNeeded(model)

    return entity
end

---@param point table
---@param entity number
local function addTarget(point, entity)
    exports.ox_target:addLocalEntity(entity, {
        {
            name = 'patrolbag_' .. point.id,
            icon = 'fa-solid fa-briefcase',
            label = point.label,
            distance = 2.0,
            onSelect = function() openPointMenu(point) end,
        },
    })
end

--- Ohne Entity (reiner Marker-Punkt) bleibt nur die Marker-Interaktion,
--- auch wenn ox_target konfiguriert ist.
---@param point table
local function setupPoint(point)
    local entity = spawnEntity(point)

    if entity then
        entities[#entities + 1] = entity
    end

    if Shared.interaction == 'target' and entity then
        return addTarget(point, entity)
    end

    local coords = vec3(point.coords.x, point.coords.y, point.coords.z)

    -- Ped/Prop markiert den Punkt bereits sichtbar: dann kein Marker,
    -- nur TextUI + [E].
    local marker = not entity and lib.marker.new({
        type = Shared.marker.type,
        width = Shared.marker.width,
        height = Shared.marker.height,
        color = Shared.marker.color,
        coords = coords,
    }) or nil

    lib.points.new({
        coords = coords,
        distance = marker and Shared.drawDistance or point.radius,
        onExit = function()
            lib.hideTextUI()
        end,
        nearby = function(self)
            if marker then marker:draw() end

            if self.currentDistance > point.radius then
                return lib.hideTextUI()
            end

            if not lib.isTextUIOpen() then
                lib.showTextUI(locale('help.interact'))
            end

            if IsControlJustReleased(0, 38) then
                lib.hideTextUI()
                openPointMenu(point)
            end
        end,
    })
end

CreateThread(function()
    for i = 1, #Shared.points do
        setupPoint(Shared.points[i])
    end
end)

RegisterNetEvent('cmdPatrolbag:openStash', function(stashId)
    if type(stashId) == 'string' then
        exports.ox_inventory:openInventory('stash', stashId)
    end
end)

RegisterNetEvent('cmdPatrolbag:notify', function(message, type)
    notify(message, type)
end)

exports('useBag', function(_, slot)
    if slot?.slot then
        TriggerServerEvent('cmdPatrolbag:useItem', slot.slot)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    lib.hideTextUI()

    for i = 1, #entities do
        if DoesEntityExist(entities[i]) then
            DeleteEntity(entities[i])
        end
    end
end)

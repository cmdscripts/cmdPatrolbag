local config = lib.load('config')

local defaults = {
    framework = 'auto',
    interaction = 'target',
    locale = 'en',
    debug = false,
    stashPrefix = 'pbg_',
    radius = 1.8,
    drawDistance = 20.0,
    actionCooldown = 750,
    maxActionsPerMinute = 30,
    jobCacheExpiry = 30000,
    maxStashes = 5000,
    identifierRange = { min = 10000, max = 99999 },
    -- Linke Hand (SKEL_L_Hand): die rechte bleibt fuer die Waffe frei.
    -- Werte aus dem 'dufbag'-Emote von scully_emotemenu.
    carry = {
        bone = 28422,
        offset = vec3(0.26, 0.04, 0.0),
        rotation = vec3(90.0, 0.0, -78.99),
        dict = 'move_weapon@jerrycan@generic',
        anim = 'idle',
    },
    marker = {
        type = 'ThickChevronUp',
        width = 0.35,
        height = 0.35,
        color = { r = 0, g = 153, b = 255, a = 180 },
    },
}

Shared = setmetatable({}, {
    __index = function(_, key)
        local value = config[key]
        if value ~= nil then return value end
        return defaults[key]
    end
})

-- 'ox_target' und 'target' meinen dasselbe.
if config.interaction == 'ox_target' then
    config.interaction = 'target'
end

-- Muss vor dem Aufbau der Punkte stehen: die nutzen bereits locale().
LoadLocale(Shared.locale)

local bags = {}

for key, bag in pairs(config.bags or {}) do
    local carry = bag.carry

    bags[key] = {
        key = key,
        label = bag.label or key,
        item = bag.item or key,
        slots = bag.slots or 20,
        weight = bag.weight or 20000,
        items = bag.items,
        onePerInventory = bag.onePerInventory ~= false,
        stashPrefix = ('%s%s_'):format(Shared.stashPrefix, key),

        -- Prop am Spieler, solange die Tasche im Inventar liegt.
        -- String = nur Modell, Tabelle = Modell + eigene Platzierung/Animation.
        carry = carry and {
            model = type(carry) == 'string' and carry or carry.model,
            bone = (type(carry) == 'table' and carry.bone) or Shared.carry.bone,
            offset = (type(carry) == 'table' and carry.offset) or Shared.carry.offset,
            rotation = (type(carry) == 'table' and carry.rotation) or Shared.carry.rotation,
            dict = type(carry) == 'table' and carry.dict ~= nil and carry.dict or Shared.carry.dict,
            anim = (type(carry) == 'table' and carry.anim) or Shared.carry.anim,
        } or nil,
    }
end

Shared.bags = bags

local points = {}

for index, point in ipairs(config.points or {}) do
    local valid = {}

    for _, bagKey in ipairs(point.bags or {}) do
        if bags[bagKey] then
            valid[#valid + 1] = bagKey
        else
            lib.print.error(locale('error.unknown_bag', point.label or index, bagKey))
        end
    end

    if #valid > 0 then
        points[#points + 1] = {
            id = point.id or ('point_%d'):format(index),
            label = point.label or locale('menu.interact'),
            coords = point.coords,
            radius = point.radius or Shared.radius,
            jobs = point.jobs,
            bags = valid,
            ped = point.ped,
            prop = point.prop,
        }
    end
end

Shared.points = points

---@param key string
---@return table?
function Shared.getBag(key)
    return type(key) == 'string' and bags[key] or nil
end

---@param id string
---@return table?
function Shared.getPoint(id)
    if type(id) ~= 'string' then return end

    for i = 1, #points do
        if points[i].id == id then return points[i] end
    end
end

---@param point table
---@param bagKey string
---@return boolean
function Shared.pointHasBag(point, bagKey)
    for i = 1, #point.bags do
        if point.bags[i] == bagKey then return true end
    end

    return false
end

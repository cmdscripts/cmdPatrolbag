local dict = {}

---@param source table
---@param target table
---@param prefix? string
local function flatten(source, target, prefix)
    for key, value in pairs(source) do
        local path = prefix and (prefix .. '.' .. key) or key

        if type(value) == 'table' then
            flatten(value, target, path)
        else
            target[path] = value
        end
    end

    return target
end

---@param key string
---@return table?
local function loadFile(key)
    local file = LoadResourceFile(cache.resource, ('locales/%s.json'):format(key))

    if not file then return end

    local ok, data = pcall(json.decode, file)

    return ok and type(data) == 'table' and data or nil
end

--- Englisch bildet die Basis: fehlt ein Key in der gewaehlten Sprache,
--- greift der englische Text statt eines rohen Key-Namens.
---@param key? string
local function load(key)
    key = key or 'en'

    local strings = flatten(loadFile('en') or {}, {})

    if key ~= 'en' then
        local translated = loadFile(key)

        if translated then
            flatten(translated, strings)
        else
            print(('^3[cmdPatrolbag] locales/%s.json not found, falling back to en^0'):format(key))
        end
    end

    dict = strings
end

--- Uebersetzt einen Key. Zusaetzliche Argumente werden per string.format
--- eingesetzt. Unbekannte Keys geben den Key selbst zurueck.
---@param key string
---@param ... string | number
---@return string
function locale(key, ...)
    local text = dict[key]

    if not text then return key end

    if ... ~= nil then
        local ok, formatted = pcall(string.format, text, ...)
        return ok and formatted or text
    end

    return text
end

---@return table<string, string>
function GetLocales()
    return dict
end

--- Wird von shared.lua aufgerufen, sobald die Config gelesen ist.
---@param key? string
function LoadLocale(key)
    load(key)
end

-- Fallback, falls LoadLocale nie aufgerufen wird: locale() liefert dann
-- englische Texte statt roher Keys.
load('en')

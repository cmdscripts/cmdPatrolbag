local dict = {}

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

local function loadFile(key)
    local file = LoadResourceFile(cache.resource, ('locales/%s.json'):format(key))

    if not file then return end

    local ok, data = pcall(json.decode, file)

    return ok and type(data) == 'table' and data or nil
end

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

function locale(key, ...)
    local text = dict[key]

    if not text then return key end

    if ... ~= nil then
        local ok, formatted = pcall(string.format, text, ...)
        return ok and formatted or text
    end

    return text
end

function GetLocales()
    return dict
end

function LoadLocale(key)
    load(key)
end

load('en')

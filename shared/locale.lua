local resource = GetCurrentResourceName()

local function read(name)
    local raw = LoadResourceFile(resource, ('locales/%s.json'):format(name))
    local decoded = raw and json.decode(raw)
    return type(decoded) == 'table' and decoded or {}
end

local fallback = read('en')
local strings = Config.Locale == 'en' and fallback or read(tostring(Config.Locale))

Locale = {}

function Locale.all()
    local merged = {}
    for key, value in pairs(fallback) do merged[key] = value end
    for key, value in pairs(strings) do merged[key] = value end
    return merged
end

function locale(key)
    return strings[key] or fallback[key] or key
end

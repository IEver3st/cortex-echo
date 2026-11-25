local resource = GetCurrentResourceName()
local TONES = { danger = true, alert = true, presence = true }
local running = false

function Echo.apply()
    if Echo.enabled and not running then
        running = true
        Sources.start()
        Marks.start()
        Cues.start()
    elseif not Echo.enabled and running then
        running = false
        Sources.stop()
        Marks.stop()
        Cues.stop()
    end
    Nui.sync()
    TriggerEvent('cortex-echo:changed', Echo.snapshot())
end

local function toVector(value)
    if type(value) == 'vector3' then return value end
    if type(value) == 'vector4' then return vector3(value.x, value.y, value.z) end
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    return x and y and z and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
end

local function clamp(value, low, high, fallback)
    value = tonumber(value) or fallback
    return math.max(low, math.min(high, value)) + 0.0
end

local PINGABLE_LOUDNESS = { vehicle = true, skid = true }

local function pingKind(data)
    local kind = data.kind
    if type(kind) == 'string' and kind ~= 'custom' and kind ~= 'ownsteps' and kind ~= 'ownvoice' and Kinds.tone[kind] and Config.Sounds[kind] then return kind end
    return 'custom'
end

local function ping(data)
    if type(data) ~= 'table' then return false end
    local kind = pingKind(data)
    if not Echo.listens(kind) then return false end
    local entity = math.type(data.entity) == 'integer' and DoesEntityExist(data.entity) and data.entity or nil
    local coords = entity and GetEntityCoords(entity) or toVector(data.coords)
    if not coords then return false end
    local range = clamp(data.range, 1.0, 500.0, 40.0)
    if #(coords - GetEntityCoords(PlayerPedId())) > range then return false end
    local id = type(data.id) == 'string' and data.id:sub(1, 64) or ('%d:%d:%d'):format(math.floor(coords.x), math.floor(coords.y), math.floor(coords.z))
    local source = Sources.touch(kind, kind .. ':ping:' .. id, entity, coords, range, math.floor(clamp(data.duration, 200.0, 15000.0, 1500.0)), true)
    if kind == 'custom' then
        source.tone = TONES[data.tone] and data.tone or 'alert'
        source.icon = Kinds.icons[data.icon] and data.icon or 'custom'
    else
        source.scale = data.scale and clamp(data.scale, 0.3, 2.0, 1.0) or nil
        if PINGABLE_LOUDNESS[kind] then source.loudness = clamp(data.loudness, 0.1, 1.0, 0.8) end
    end
    return true
end

exports('ping', ping)
exports('isEnabled', function() return Echo.enabled end)
exports('setEnabled', function(value) Echo.setEnabled(value == true) end)
exports('getState', function() return Echo.snapshot() end)
exports('open', function() return Echo.openSettings() end)
exports('close', function() return Echo.closeSettings() end)

RegisterNetEvent('cortex-echo:ping', function(data) ping(data) end)

RegisterCommand(Config.Command, function()
    Echo.openSettings()
end, false)

RegisterCommand('echo_toggle', function()
    Echo.setEnabled(not Echo.enabled)
    Nui.send('toast', Echo.enabled and 'toggled_on' or 'toggled_off')
end, false)

RegisterKeyMapping('echo_toggle', locale('key_toggle'), 'keyboard', '')

AddEventHandler('onClientResourceStart', function(name)
    if name ~= resource then return end
    Echo.load()
    Echo.apply()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, locale('command_help'))
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= resource then return end
    pcall(TriggerEvent, 'chat:removeSuggestion', '/' .. Config.Command)
end)

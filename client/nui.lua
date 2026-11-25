Nui = { ready = false }

local FALLBACK_ACCENT = '#8fcbbf'

local function profileAccent(data)
    local hex = type(data) == 'table' and type(data.profile) == 'table' and data.profile.accent
    return type(hex) == 'string' and hex:match('^#%x%x%x%x%x%x$') and hex or nil
end

local function currentAccent()
    if GetResourceState('cortex-lib') ~= 'started' then return FALLBACK_ACCENT end
    local ok, data = pcall(function() return exports['cortex-lib']:getPresentation() end)
    return ok and profileAccent(data) or FALLBACK_ACCENT
end

function Nui.send(action, data)
    if Nui.ready then SendNUIMessage({ action = action, data = data }) end
end

function Nui.sendEncoded(action, encoded)
    if Nui.ready then SendNuiMessage(('{"action":"%s","data":%s}'):format(action, encoded)) end
end

function Nui.state()
    local state = Echo.snapshot()
    state.accent = currentAccent()
    state.strings = Locale.all()
    return state
end

function Nui.sync()
    Nui.send('state', Nui.state())
end

RegisterNUICallback('ready', function(_, cb)
    Nui.ready = true
    cb({ ok = true })
    Nui.sync()
end)

AddEventHandler('cortex-lib:presentation', function(data)
    local accent = profileAccent(data)
    if accent then Nui.send('accent', accent) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == 'cortex-lib' then Nui.send('accent', FALLBACK_ACCENT) end
end)

local TAB = 'cortex-echo'
local PREFIX = 'cortex-echo:'
local LEGACY = 'cortex-echo:'
local STORED_ON, STORED_OFF = 1, 2
local SIZES = { s = true, m = true, l = true }
local ENABLED, SIZE, DENSITY, SAMPLE, PALETTE = 'echo_enabled', 'echo_size', 'echo_density', 'echo_sample', 'echo_palette'
local LEGACY_FIELD_LIMIT = 64
local SAMPLE_MS = 6000
local CHANGE_SAMPLE_MS = 4000
local RELABEL_DELAY_MS = 300

Echo = {
    enabled = false, size = 'm', detail = 'm', palette = 'custom', prefs = {}, shapes = {}, colors = {}, kinds = {}, linked = false,
}

local kindOf, shapeOf, colorOf = {}, {}, {}
local described = {}
local restyledOpen = false

local function kindKey(kind) return 'echo_kind_' .. kind end
local function shapeKey(kind) return 'echo_shape_' .. kind end
local function colorKey(kind) return 'echo_color_' .. kind end

local function legacyFlag(key, fallback)
    local value = GetResourceKvpInt(LEGACY .. key)
    if value == STORED_ON then return true end
    if value == STORED_OFF then return false end
    return fallback
end

local function legacyChoice(key, fallback)
    local value = GetResourceKvpString(LEGACY .. key)
    return SIZES[value] and value or fallback
end

local function listKinds()
    Echo.kinds, kindOf, shapeOf, colorOf = {}, {}, {}, {}
    for _, kind in ipairs(Kinds.order) do
        local sound = Config.Sounds[kind]
        if type(sound) == 'table' and sound.enabled then
            Echo.kinds[#Echo.kinds + 1] = kind
            kindOf[kindKey(kind)], shapeOf[shapeKey(kind)], colorOf[colorKey(kind)] = kind, kind, kind
        end
    end
end

local function defaults()
    local density = SIZES[Config.Marks.density] and Config.Marks.density or 'm'
    local values = {
        [ENABLED] = legacyFlag('enabled', Config.DefaultEnabled == true),
        [SIZE] = legacyChoice('size', 'm'),
        [DENSITY] = legacyChoice('detail', density),
        [PALETTE] = Looks.defaultPalette(),
    }
    for _, kind in ipairs(Echo.kinds) do
        values[kindKey(kind)] = legacyFlag('kind:' .. kind, true)
        values[shapeKey(kind)] = Looks.defaultShape(kind)
        values[colorKey(kind)] = Looks.defaultColor(kind)
    end
    return values
end

local function choices(prefix)
    return {
        { value = 's', label = locale(prefix .. '_s') },
        { value = 'm', label = locale(prefix .. '_m') },
        { value = 'l', label = locale(prefix .. '_l') },
    }
end

local function listOf(values, prefix)
    local options = {}
    for index, value in ipairs(values) do options[index] = { value = value, label = locale(prefix .. value) } end
    return options
end

local function swatches()
    local options = {}
    for index, swatch in ipairs(Looks.swatches) do options[index] = { value = swatch.value, label = locale('color_' .. swatch.name) } end
    return options
end

local function fields(limit)
    local shown = { [ENABLED] = true }
    local general, marks = locale('section_general'), locale('section_marks')
    local shapes, colors, palettes = listOf(Looks.shapes, 'shape_name_'), swatches(), listOf(Looks.palettes, 'palette_')
    local list = {
        { key = ENABLED, type = 'toggle', section = general, label = locale('enabled_label'), description = locale('enabled_help') },
        { key = SIZE, type = 'select', section = marks, label = locale('size'), description = locale('size_help'), options = choices('size'), showWhen = shown },
        { key = DENSITY, type = 'select', section = marks, label = locale('detail'), description = locale('detail_help'), options = choices('detail'), showWhen = shown },
        { key = PALETTE, type = 'select', section = marks, label = locale('palette_label'), description = locale('palette_help'), options = palettes, showWhen = shown },
        { key = SAMPLE, type = 'buttons', section = marks, label = locale('sample_label'), description = locale('sample_help'),
            buttons = { { value = 'play', label = locale('sample_button') } }, showWhen = shown },
    }
    described = {}
    local looksLeft = limit and math.floor((limit - #list - #Echo.kinds) / 2) or math.huge
    for _, kind in ipairs(Echo.kinds) do
        local sounds = locale('section_' .. (Kinds.section[kind] or 'other'))
        local name = locale('kind_' .. kind)
        local on = { [ENABLED] = true, [kindKey(kind)] = true }
        local custom = { [ENABLED] = true, [kindKey(kind)] = true, [PALETTE] = 'custom' }
        described[kind] = Looks.describe(kind)
        list[#list + 1] = { key = kindKey(kind), type = 'toggle', section = sounds, label = name, description = described[kind], showWhen = shown }
        if looksLeft > 0 then
            looksLeft = looksLeft - 1
            list[#list + 1] = { key = shapeKey(kind), type = 'select', section = sounds, label = (locale('shape_label'):gsub('{kind}', name)), options = shapes, showWhen = on }
            list[#list + 1] = { key = colorKey(kind), type = 'color', section = sounds, label = (locale('color_label'):gsub('{kind}', name)), options = colors, custom = true, showWhen = custom }
        end
    end
    return list
end

local function lib(name, ...)
    if GetResourceState('cortex-lib') ~= 'started' then return nil end
    local args = table.pack(...)
    local results = table.pack(pcall(function() return exports['cortex-lib'][name](exports['cortex-lib'], table.unpack(args, 1, args.n)) end))
    if not results[1] then return nil, results[2] end
    return table.unpack(results, 2, results.n)
end

local function receive(key, value)
    if key == ENABLED and type(value) == 'boolean' then
        Echo.enabled = value
        return true
    elseif key == SIZE and SIZES[value] then
        Echo.size = value
        return true
    elseif key == DENSITY and SIZES[value] then
        Echo.detail = value
        return true
    elseif key == PALETTE and Looks.isPalette(value) then
        Echo.palette = value
        Looks.refresh()
        return true, true
    end
    local kind = kindOf[key]
    if kind and type(value) == 'boolean' then
        Echo.prefs[kind] = value
        return true
    end
    kind = shapeOf[key]
    if kind and Looks.isShape(value) then
        Echo.shapes[kind] = value
        Looks.refresh()
        return true, true
    end
    kind = colorOf[key]
    local hex = kind and Looks.hexColor(value)
    if hex then
        Echo.colors[kind] = hex
        Looks.refresh()
        return true, true
    end
    return false
end

local function readAll(values)
    for key, value in pairs(values) do receive(key, value) end
end

local function relabelNeeded()
    for _, kind in ipairs(Echo.kinds) do
        if described[kind] ~= Looks.describe(kind) then return true end
    end
    return false
end

local function register(base)
    local full = fields()
    local ok, err = lib('registerSettings', TAB, locale('title'), PREFIX, full, base, { group = 'Everyday' })
    if ok ~= true and #full > LEGACY_FIELD_LIMIT then
        ok, err = lib('registerSettings', TAB, locale('title'), PREFIX, fields(LEGACY_FIELD_LIMIT), base, { group = 'Everyday' })
        if ok == true then print('^3[cortex-echo]^7 This cortex-lib allows 64 settings per tab. Update cortex-lib to pick shapes and colours for every sound.') end
    end
    Echo.linked = ok == true
    return Echo.linked, err
end

function Echo.load()
    listKinds()
    Echo.prefs, Echo.shapes, Echo.colors = {}, {}, {}
    local base = defaults()
    readAll(base)
    local linked, err = register(base)
    if not linked then
        print(('^3[cortex-echo]^7 Cortex settings tab not registered (%s). Using saved values.'):format(tostring(err or 'cortex-lib not started')))
        return
    end
    for key in pairs(base) do
        local value = lib('getTabSetting', TAB, key)
        if value ~= nil then receive(key, value) end
    end
    if relabelNeeded() then register(base) end
end

function Echo.listens(kind)
    return Echo.enabled and Echo.prefs[kind] == true
end

function Echo.sound(kind)
    return Echo.listens(kind) and Config.Sounds[kind] or nil
end

local function store(key, value)
    if Echo.linked and lib('setSetting', key, value) then return end
    local accepted, restyled = receive(key, value)
    if restyled then Marks.restyle() end
    if accepted then Echo.apply() end
end

function Echo.setEnabled(value)
    value = value == true
    if Echo.enabled ~= value then store(ENABLED, value) end
end

function Echo.setKind(kind, value)
    if Echo.prefs[kind] ~= nil then store(kindKey(kind), value == true) end
end

function Echo.setShape(kind, shape)
    if Echo.prefs[kind] ~= nil and Looks.isShape(shape) then store(shapeKey(kind), shape) end
end

function Echo.setColor(kind, color)
    local hex = Looks.hexColor(color)
    if Echo.prefs[kind] ~= nil and hex then store(colorKey(kind), hex) end
end

function Echo.setPalette(palette)
    if Looks.isPalette(palette) then store(PALETTE, palette) end
end

function Echo.setSize(size)
    if SIZES[size] then store(SIZE, size) end
end

function Echo.setDetail(detail)
    if SIZES[detail] then store(DENSITY, detail) end
end

function Echo.openSettings()
    return lib('openSettings')
end

function Echo.closeSettings()
    return lib('closeSettings')
end

function Echo.snapshot()
    local kinds = {}
    for index, kind in ipairs(Echo.kinds) do
        local style = Looks.style(kind)
        kinds[index] = { id = kind, tone = Kinds.tone[kind], family = Kinds.family[kind], on = Echo.prefs[kind], shape = style.texture, color = style.hex }
    end
    return { enabled = Echo.enabled, size = Echo.size, detail = Echo.detail, palette = Echo.palette, kinds = kinds }
end

AddEventHandler('cortex-lib:settingChanged', function(key, value, tabId)
    if tabId ~= TAB then return end
    local accepted, restyled = receive(key, value)
    if not accepted then return end
    if restyled then
        Marks.restyle()
        restyledOpen = true
    end
    Echo.apply()
    if key ~= ENABLED and Echo.enabled then Marks.sample(CHANGE_SAMPLE_MS) end
end)

AddEventHandler('cortex-lib:settingsAction', function(tabId, action, fieldKey)
    if tabId == TAB and fieldKey == SAMPLE and action == 'play' and Echo.enabled then Marks.sample(SAMPLE_MS) end
end)

AddEventHandler('cortex-lib:pauseChanged', function(active)
    if active or not Echo.linked then return end
    SetTimeout(RELABEL_DELAY_MS, function()
        if LocalPlayer.state.cortexPauseOpen then return end
        if restyledOpen and Echo.enabled then Marks.sample(SAMPLE_MS) end
        restyledOpen = false
        if Echo.linked and relabelNeeded() then register(defaults()) end
    end)
end)

AddEventHandler('onClientResourceStart', function(name)
    if name ~= 'cortex-lib' then return end
    Echo.load()
    Marks.restyle()
    Echo.apply()
end)

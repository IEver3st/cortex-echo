Looks = {
    shapes = { 'diamond', 'square', 'cross', 'triangle', 'dash', 'circle', 'ring', 'chevron', 'star' },
    palettes = { 'custom', 'redgreen', 'tritan', 'contrast' },
    swatches = {
        { value = '#ff584c', name = 'red' },
        { value = '#ffb846', name = 'amber' },
        { value = '#ffe14d', name = 'yellow' },
        { value = '#4ea0ff', name = 'blue' },
        { value = '#46e4c6', name = 'mint' },
        { value = '#3dff5a', name = 'green' },
        { value = '#cc79a7', name = 'pink' },
        { value = '#b58cff', name = 'purple' },
        { value = '#eeeee4', name = 'white' },
    },
}

local FAMILY_SHAPE = { danger = 'diamond', alert = 'square', emergency = 'cross', people = 'triangle', traffic = 'dash' }
local FAMILY_ALPHA = { danger = 236, alert = 228, emergency = 232, people = 218, traffic = 186 }
local CONTRAST_ALPHA = 255
local TONE_KIND = { danger = 'gunshot', alert = 'custom', presence = 'voice' }

local PALETTE = {
    standard = { danger = '#ff584c', alert = '#ffb846', emergency = '#4ea0ff', people = '#46e4c6', traffic = '#eeeee4' },
    redgreen = { danger = '#ff584c', alert = '#ffe14d', emergency = '#2f7bff', people = '#cc79a7', traffic = '#ffffff' },
    tritan = { danger = '#ff3048', alert = '#ff9e2c', emergency = '#2f7bff', people = '#00ffa8', traffic = '#ffffff' },
    contrast = { danger = '#ff3048', alert = '#ffd000', emergency = '#2f7bff', people = '#00d2a0', traffic = '#ffffff' },
}

local NAMED = {
    { 'red', 255, 72, 64 }, { 'orange', 255, 140, 26 }, { 'amber', 255, 184, 70 }, { 'yellow', 255, 225, 77 },
    { 'lime', 155, 225, 93 }, { 'green', 46, 204, 64 }, { 'mint', 70, 228, 198 }, { 'cyan', 60, 200, 255 },
    { 'blue', 60, 130, 255 }, { 'purple', 165, 120, 255 }, { 'pink', 255, 130, 200 }, { 'white', 238, 238, 228 },
    { 'grey', 150, 155, 160 },
}

local shapeSet = {}
for _, shape in ipairs(Looks.shapes) do shapeSet[shape] = true end
local paletteSet = {}
for _, palette in ipairs(Looks.palettes) do paletteSet[palette] = true end

local cache = {}

local function hexColor(value)
    if type(value) ~= 'string' then return nil end
    local hex = value:lower()
    return hex:match('^#%x%x%x%x%x%x$') and hex or nil
end

local function channels(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

Looks.hexColor = hexColor

function Looks.isShape(value)
    return shapeSet[value] == true
end

function Looks.isPalette(value)
    return paletteSet[value] == true
end

function Looks.family(kind)
    return Kinds.family[kind] or 'alert'
end

function Looks.defaultShape(kind)
    local sound = Config.Sounds[kind]
    local shape = type(sound) == 'table' and sound.shape
    return shapeSet[shape] and shape or FAMILY_SHAPE[Looks.family(kind)] or 'square'
end

function Looks.defaultColor(kind)
    local sound = Config.Sounds[kind]
    return hexColor(type(sound) == 'table' and sound.color) or PALETTE.standard[Looks.family(kind)] or PALETTE.standard.alert
end

function Looks.defaultPalette()
    local palette = Config.Marks.palette
    return paletteSet[palette] and palette or 'custom'
end

function Looks.shapeOf(kind)
    return Echo.shapes[kind] or Looks.defaultShape(kind)
end

function Looks.colorOf(kind)
    local palette = PALETTE[Echo.palette]
    if palette then return palette[Looks.family(kind)] end
    return Echo.colors[kind] or Looks.defaultColor(kind)
end

function Looks.style(kind)
    local style = cache[kind]
    if style then return style end
    local hex = Looks.colorOf(kind)
    local r, g, b = channels(hex)
    style = {
        kind = kind, hex = hex, tint = { r, g, b }, texture = Looks.shapeOf(kind),
        alpha = Echo.palette == 'contrast' and CONTRAST_ALPHA or FAMILY_ALPHA[Looks.family(kind)] or 228,
    }
    cache[kind] = style
    return style
end

function Looks.kindFor(source)
    if source.kind == 'custom' and source.tone then return TONE_KIND[source.tone] or 'custom' end
    return source.kind
end

function Looks.forSource(source)
    return Looks.style(Looks.kindFor(source))
end

function Looks.refresh()
    cache = {}
end

function Looks.colorName(hex)
    for _, swatch in ipairs(Looks.swatches) do
        if swatch.value == hex then return locale('color_' .. swatch.name) end
    end
    local r, g, b = channels(hex)
    local best, bestDistance = 'white', math.huge
    for _, named in ipairs(NAMED) do
        local mean = (r + named[2]) / 2
        local dr, dg, db = r - named[2], g - named[3], b - named[4]
        local distance = (2 + mean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - mean) / 256) * db * db
        if distance < bestDistance then best, bestDistance = named[1], distance end
    end
    return locale('color_' .. best)
end

function Looks.describe(kind)
    local line = locale('look_line')
    local color = Looks.colorName(Looks.colorOf(kind))
    local shape = locale('shape_' .. Looks.shapeOf(kind))
    return (line:gsub('{color}', color):gsub('{shape}', shape))
end

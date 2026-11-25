Cues = {}

local TICK_MS = 50
local IDLE_MS = 150
local LOOK_MS = 250
local MERGE_DEGREES = 14.0
local MIN_DISTANCE = 0.4
local SIGHT_FLAGS = 19
local SIGHT_SLACK = 1.5

local cuesGen = 0
local clock = Perf.clock
local waiting = {}
local radarRect, radarAt = nil, 0

local function relativeBearing(dx, dy, cameraZ)
    local degrees = math.deg(math.atan(dx, dy)) + cameraZ
    return (degrees + 180.0) % 360.0 - 180.0
end

local function apart(a, b)
    local diff = math.abs(a - b) % 360.0
    return diff > 180.0 and 360.0 - diff or diff
end

local function louder(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.l ~= b.l then return a.l > b.l end
    return a.id < b.id
end

local function round(value, places)
    local factor = 10 ^ places
    return math.floor(value * factor + 0.5) / factor
end

local function radar()
    local now = GetGameTimer()
    if now - radarAt < 1000 then return radarRect end
    radarAt = now
    if IsRadarHidden() then
        radarRect = false
        return radarRect
    end
    local width = 0.15 * math.min(1.0, (16.0 / 9.0) / GetAspectRatio(false))
    SetScriptGfxAlign(76, 66)
    local left, top = GetScriptGfxPosition(-0.0045, 0.002 - 0.188888)
    local right, bottom = GetScriptGfxPosition(-0.0045 + width, 0.002)
    ResetScriptGfxAlign()
    radarRect = { round(left, 4), round(top, 4), round(right, 4), round(math.min(1.0, bottom + 0.035), 4) }
    return radarRect
end

local function settle()
    for handle, source in pairs(waiting) do
        local status, hit, coords = GetShapeTestResult(handle)
        if status ~= 1 then
            waiting[handle] = nil
            source.sightProbe = nil
            if status == 2 then
                source.blocked = (hit == true or hit == 1) and #(coords - source.sightTarget) > SIGHT_SLACK
            end
        end
    end
end

local function lookAt(source, now, camera)
    if source.sightProbe or now < (source.lookAt or 0) then return end
    source.lookAt = now + LOOK_MS
    local pos = source.coords
    local target = vector3(pos.x, pos.y, pos.z + 0.4)
    local onScreen = GetScreenCoordFromWorldCoord(target.x, target.y, target.z)
    source.onScreen = onScreen == true or onScreen == 1
    if source.onScreen then
        source.sightTarget = target
        local handle = StartShapeTestLosProbe(camera.x, camera.y, camera.z, target.x, target.y, target.z, SIGHT_FLAGS, source.entity or 0, 7)
        if handle and handle ~= 0 then
            source.sightProbe = handle
            waiting[handle] = source
        end
    else
        source.blocked = false
    end
end

local function cued(source, myVehicle)
    if myVehicle ~= 0 and source.entity == myVehicle then return false end
    if source.kind == 'vehicle' then return source.approaching == true end
    return true
end

function Cues.build()
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local myVehicle = GetVehiclePedIsIn(ped, false)
    local camera = GetFinalRenderedCamCoord()
    local cameraZ = GetFinalRenderedCamRot(2).z
    local now = GetGameTimer()
    local heard = {}
    settle()

    for key, source in pairs(Sources.active) do
        if now <= source.expires and cued(source, myVehicle) then
            local entity = source.entity
            if entity and DoesEntityExist(entity) then source.coords = GetEntityCoords(entity) end
            local pos = source.coords
            local dx, dy, dz = pos.x - origin.x, pos.y - origin.y, pos.z - origin.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if dist >= MIN_DISTANCE then
                lookAt(source, now, camera)
                if source.onScreen == false or source.blocked then
                    local tone = source.tone or Kinds.tone[source.kind]
                    heard[#heard + 1] = {
                        id = key,
                        i = source.icon or source.kind,
                        f = source.tone and Kinds.toneFamily[source.tone] or Kinds.family[source.kind] or 'alert',
                        c = Looks.forSource(source).hex,
                        b = relativeBearing(dx, dy, cameraZ),
                        l = math.max(0.12, math.min(1.0, 1.0 - dist / source.range)),
                        p = source.pulses,
                        rank = Kinds.priority[tone] or 1,
                    }
                end
            end
        end
    end

    table.sort(heard, louder)

    local cues = {}
    local limit = math.max(1, math.floor(tonumber(Config.MaxCues) or 6))
    for _, cue in ipairs(heard) do
        local merged = false
        for _, kept in ipairs(cues) do
            if kept.i == cue.i and apart(kept.b, cue.b) <= MERGE_DEGREES then
                kept.l = math.min(1.0, kept.l + 0.08)
                kept.p = kept.p + cue.p
                merged = true
                break
            end
        end
        if not merged and #cues < limit then cues[#cues + 1] = cue end
    end

    for _, cue in ipairs(cues) do
        cue.rank = nil
        cue.b = round(cue.b, 1)
        cue.l = round(cue.l, 2)
    end
    return cues
end

function Cues.start()
    if Config.Marks.offscreenCues == false then return end
    cuesGen = cuesGen + 1
    local gen = cuesGen
    CreateThread(function()
        local showing = false
        local lastRadar, lastSent
        while gen == cuesGen do
            if Sources.count > 0 and not IsPauseMenuActive() then
                local perf = Perf.on
                local started = perf and clock()
                local cues = Cues.build()
                if perf then Perf.add('cues.build', started) started = clock() end
                if #cues > 0 then
                    local rect = radar()
                    if rect ~= lastRadar then
                        lastRadar = rect
                        Nui.send('radar', rect or false)
                    end
                    local encoded = json.encode(cues)
                    if encoded ~= lastSent then
                        lastSent = encoded
                        Nui.sendEncoded('cues', encoded)
                        if perf then Perf.count('cues.sent') end
                    end
                    showing = true
                elseif showing then
                    Nui.send('cues', false)
                    showing, lastSent = false, nil
                end
                if perf then Perf.add('cues.send', started) end
                Wait(TICK_MS)
            else
                settle()
                if showing then
                    Nui.send('cues', false)
                    showing, lastSent = false, nil
                end
                Wait(IDLE_MS)
            end
        end
    end)
end

function Cues.stop()
    cuesGen = cuesGen + 1
    Nui.send('cues', false)
end

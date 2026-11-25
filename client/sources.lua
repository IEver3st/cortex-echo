Sources = { active = {}, count = 0 }

local SCAN_MS = 200
local HELICOPTER, PLANE = 15, 16
local FIREARMS = 4
local EXPLOSIVE = 5
local SAME_EVENT_METRES = 60.0
local EVENT_QUIET_MS = 6000
local BLAST_GONE_MS = 600
local MOTORCYCLE, CYCLE, BOAT = 8, 13, 14
local ELECTRIC_FLAG = 43
local IDLE_RPM = 0.2
local ENGINE_IDLE = 0.22
local TYRES_FULL_SPEED = 45.0
local TYRES_SHARE = 0.55
local DRIVING_RANGE = 22.0
local DRIVING_LOUDEST = 0.4
local OWN_DIM = 0.8
local TRAFFIC_DIM = 0.6
local APPROACH_SECONDS = 4.0
local APPROACH_MISS = 6.0
local SPIN_START, SPIN_FULL = 3.0, 9.0
local BRAKE_SKID = 7.0
local SIDE_START, SIDE_FULL = 3.5, 7.0
local SQUEAL_MIN = 0.25
local SQUEAL_HOLD = 450
local SQUEAL_OTHERS = 6
local OWN_SQUEAL_MS = 100
local SLIPS_RESET_MS = 30000
local HORN_MS = 100
local HORN_NEAREST = 8
local ARMED_MS = 600
local ARMED_NEAREST = 16
local BLAST_MS = 50
local CALM_MS = 50
local electricModels, axles, slips, classes = {}, {}, {}, {}
local slipsReset, ownSquealAt, hornAt, armedAt, blastAt = 0, 0, 0, 0, 0
local selfArmed = false
local clock = Perf.clock

local scanGen = 0
local fastToken = 0
local fastActive = false
local armed, honkers = {}, {}
local recent = {}
local blasts = {}
local serial = 0
local sirenAudible = IsVehicleSirenAudioOn or function() return true end

function Sources.touch(kind, key, entity, coords, range, hold, pulse)
    local source = Sources.active[key]
    if not source then
        source = { kind = kind, key = key, pulses = 0 }
        Sources.active[key] = source
        Sources.count = Sources.count + 1
    end
    source.entity = entity
    source.coords = coords
    source.range = range
    source.expires = GetGameTimer() + hold
    if pulse then source.pulses = source.pulses + 1 end
    return source
end

local touch = Sources.touch

function Sources.prune(now)
    for key, source in pairs(Sources.active) do
        if now > source.expires then
            Sources.active[key] = nil
            Sources.count = Sources.count - 1
        end
    end
end

local function reach(...)
    local furthest = 0.0
    for index = 1, select('#', ...) do
        local sound = select(index, ...)
        if sound and sound.range > furthest then furthest = sound.range end
    end
    return furthest
end

local function isElectric(veh)
    local model = GetEntityModel(veh)
    local known = electricModels[model]
    if known ~= nil then return known end
    local ok, value = pcall(GetIsVehicleElectric, model)
    if not ok or value == nil then ok, value = pcall(GetVehicleHasFlag, veh, ELECTRIC_FLAG) end
    known = ok and (value == true or value == 1) or false
    electricModels[model] = known
    return known
end

Sources.isElectric = isElectric

local function rearAxle(veh)
    local model = GetEntityModel(veh)
    local axle = axles[model]
    if axle then return axle end
    local low = GetModelDimensions(model)
    axle = low and low.y * 0.62 or -1.3
    axles[model] = axle
    return axle
end

local function loudness(veh, class, speed)
    local tyres = math.min(1.0, speed / TYRES_FULL_SPEED) * TYRES_SHARE
    if class == CYCLE then return tyres * 0.6, false end
    local electric = isElectric(veh)
    local engine = 0.0
    if not electric and GetIsVehicleEngineRunning(veh) then
        local revs = math.max(0.0, math.min(1.0, (GetVehicleCurrentRpm(veh) - IDLE_RPM) / (1.0 - IDLE_RPM)))
        local throttle = math.min(1.0, math.abs(GetVehicleThrottleOffset(veh)))
        engine = ENGINE_IDLE + (1.0 - ENGINE_IDLE) * revs * (0.55 + 0.45 * throttle)
        if class == MOTORCYCLE then engine = engine * 1.2 end
    end
    local level = math.max(engine, tyres) + math.min(engine, tyres) * 0.3
    return math.min(1.0, level), electric
end

local function squeal(veh, speed, now)
    if IsVehicleInBurnout(veh) then return 0.85, 'burnout' end
    if not IsVehicleOnAllWheels(veh) then return 0.0, nil end
    local history = slips[veh]
    local braking = 0.0
    if history and now > history.at then
        braking = (history.speed - speed) / ((now - history.at) / 1000.0)
    end
    slips[veh] = { speed = speed, at = now }
    local wheels = math.min(6, GetVehicleNumberOfWheels(veh))
    local fastest, slowest = 0.0, math.huge
    for wheel = 0, wheels - 1 do
        local spin = math.abs(GetVehicleWheelSpeed(veh, wheel))
        if spin > fastest then fastest = spin end
        if spin < slowest then slowest = spin end
    end
    local level, how = 0.0, nil
    local wheelsKnown = fastest > 0.5 or speed < 3.0
    if wheelsKnown then
        local spin = (fastest - speed - SPIN_START) / SPIN_FULL
        if spin > level then level, how = spin, 'wheelspin' end
        if braking > BRAKE_SKID and speed > 6.0 then
            local lock = (speed - slowest - SPIN_START) / SPIN_FULL
            if lock > level then level, how = lock, 'braking' end
        end
    end
    local side = (math.abs(GetEntitySpeedVector(veh, true).x) - SIDE_START) / SIDE_FULL
    if side > level then level, how = side, 'drift' end
    return math.max(0.0, math.min(1.0, level)), how
end

local function hearSqueal(veh, pos, skid, level, how)
    local source = touch('skid', 'skid:' .. veh, veh, pos, skid.range, SQUEAL_HOLD)
    source.loudness = 0.45 + 0.55 * level
    source.axle = rearAxle(veh)
    source.how = how
end

function Sources.checkOwnSqueal(ped, now)
    local skid = Echo.sound('skid')
    if not skid then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    local level, how = squeal(veh, GetEntitySpeed(veh), now)
    if level >= SQUEAL_MIN then hearSqueal(veh, GetEntityCoords(veh), skid, level, how) end
end

local function approaching(origin, pos, veh)
    local velocity = GetEntityVelocity(veh)
    local speedSquared = velocity.x * velocity.x + velocity.y * velocity.y
    if speedSquared < 9.0 then return false end
    local toward = origin - pos
    local seconds = (toward.x * velocity.x + toward.y * velocity.y) / speedSquared
    if seconds <= 0.0 or seconds > APPROACH_SECONDS then return false end
    local missX, missY = toward.x - velocity.x * seconds, toward.y - velocity.y * seconds
    return missX * missX + missY * missY <= APPROACH_MISS * APPROACH_MISS
end

local function hearEngine(entry, vehicle, origin, driving)
    local source = touch('vehicle', 'vehicle:' .. entry.veh, entry.veh, entry.pos, vehicle.range, 700)
    source.loudness = entry.level
    source.electric = entry.electric
    source.own = entry.own
    source.dim = entry.own and OWN_DIM or (driving and TRAFFIC_DIM or 1.0)
    source.approaching = not entry.own and not driving and approaching(origin, entry.pos, entry.veh)
end

local function byDistance(a, b)
    return a.dist < b.dist
end

local function classOf(veh)
    local model = GetEntityModel(veh)
    local class = classes[model]
    if not class then
        class = GetVehicleClass(veh)
        classes[model] = class
    end
    return class
end

Sources.classOf = classOf

local function nearest(list, count)
    table.sort(list, byDistance)
    local picked = {}
    for index = 1, math.min(count, #list) do picked[index] = list[index].veh end
    return picked
end

local function scanVehicles(origin, myVehicle, now)
    local siren, alarm, horn = Echo.sound('siren'), Echo.sound('alarm'), Echo.sound('horn')
    local vehicle, aircraft, skid = Echo.sound('vehicle'), Echo.sound('aircraft'), Echo.sound('skid')
    local nextHonkers = {}
    local nearby = {}
    local driving = myVehicle ~= 0
    local furthest = math.max(reach(siren, alarm, horn, vehicle, aircraft, skid), World.vehicleReach())
    if furthest > 0.0 then
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if veh ~= myVehicle then
                local pos = GetEntityCoords(veh)
                local dist = #(pos - origin)
                if dist <= furthest then
                    local class = classOf(veh)
                    if siren and dist <= siren.range and IsVehicleSirenOn(veh) and (siren.lightsCount or sirenAudible(veh)) then
                        touch('siren', 'siren:' .. veh, veh, pos, siren.range, 900)
                    end
                    if alarm and dist <= alarm.range and IsVehicleAlarmActivated(veh) then
                        touch('alarm', 'alarm:' .. veh, veh, pos, alarm.range, 900)
                    end
                    if class == HELICOPTER or class == PLANE then
                        if aircraft and dist <= aircraft.range and GetIsVehicleEngineRunning(veh) then
                            touch('aircraft', 'aircraft:' .. veh, veh, pos, aircraft.range, 900)
                        end
                    elseif class ~= BOAT then
                        if horn and dist <= horn.range and not IsVehicleSeatFree(veh, -1) then
                            nextHonkers[#nextHonkers + 1] = { veh = veh, dist = dist }
                        end
                        nearby[#nearby + 1] = { veh = veh, pos = pos, dist = dist, class = class }
                    end
                end
            end
        end
    end

    if myVehicle ~= 0 then
        if horn then nextHonkers[#nextHonkers + 1] = { veh = myVehicle, dist = 0.0 } end
        if siren and siren.own ~= false and IsVehicleSirenOn(myVehicle) and (siren.lightsCount or sirenAudible(myVehicle)) then
            local source = touch('siren', 'siren:' .. myVehicle, myVehicle, GetEntityCoords(myVehicle), siren.range, 900)
            source.dim = OWN_DIM
        end
        if vehicle and vehicle.own ~= false then
            local class = classOf(myVehicle)
            if class ~= HELICOPTER and class ~= PLANE and class ~= BOAT then
                local level, electric = loudness(myVehicle, class, GetEntitySpeed(myVehicle))
                if level >= (tonumber(vehicle.quietest) or 0.12) then
                    hearEngine({ veh = myVehicle, pos = GetEntityCoords(myVehicle), level = level, electric = electric, own = true }, vehicle, origin, driving)
                end
            end
        end
    end

    table.sort(nearby, byDistance)
    local quietest = vehicle and (tonumber(vehicle.quietest) or 0.12) or 1.0
    local needed = driving and DRIVING_LOUDEST or quietest
    local engines = vehicle and (driving and (tonumber(vehicle.driving) or 2) or (tonumber(vehicle.nearest) or 4)) or 0
    local engineRange = vehicle and (driving and DRIVING_RANGE or vehicle.range) or 0.0
    local squeals = 0
    for index = 1, #nearby do
        local entry = nearby[index]
        if engines <= 0 and (not skid or squeals >= SQUEAL_OTHERS) then break end
        local speed = GetEntitySpeed(entry.veh)
        if skid and squeals < SQUEAL_OTHERS and entry.dist <= skid.range then
            squeals = squeals + 1
            local level, how = squeal(entry.veh, speed, now)
            if level >= SQUEAL_MIN then hearSqueal(entry.veh, entry.pos, skid, level, how) end
        end
        if engines > 0 and entry.dist <= engineRange then
            local level, electric = loudness(entry.veh, entry.class, speed)
            if level >= needed then
                engines = engines - 1
                entry.level, entry.electric, entry.own = level, electric, false
                hearEngine(entry, vehicle, origin, driving)
            end
        end
    end
    honkers = nearest(nextHonkers, HORN_NEAREST)
    World.vehicles(nearby, myVehicle, origin, now)
end

local function scanPeds(ped, origin, withArmed)
    local gunshot, footsteps = Echo.sound('gunshot'), Echo.sound('footsteps')
    local armedRange = withArmed and gunshot and gunshot.range or 0.0
    local stepRange = footsteps and footsteps.range or 0.0
    local furthest = math.max(armedRange, stepRange, World.pedReach())
    local found = {}
    local now = GetGameTimer()
    if furthest > 0.0 then
        for _, other in ipairs(GetGamePool('CPed')) do
            if other ~= ped then
                local pos = GetEntityCoords(other)
                local dist = #(pos - origin)
                if dist <= furthest and not IsPedDeadOrDying(other, true) then
                    World.ped(other, pos, dist, now)
                    if dist <= armedRange and IsPedArmed(other, FIREARMS) then
                        found[#found + 1] = { veh = other, dist = dist }
                    end
                    if dist <= stepRange and IsPedOnFoot(other) and not GetPedStealthMovement(other) then
                        local isPlayer = IsPedAPlayer(other)
                        if (isPlayer and footsteps.players) or (not isPlayer and footsteps.npcs) then
                            local speed = GetEntitySpeed(other)
                            if speed > 2.6 or (speed > 0.9 and dist <= footsteps.walkRange) then
                                touch('footsteps', 'footsteps:' .. other, other, pos, footsteps.range, 700)
                            end
                        end
                    end
                end
            end
        end
    end
    if withArmed then armed = nearest(found, ARMED_NEAREST) end
end

local VOICE_NORMAL = 7.0

local nativeVoice

local function voiceReach(distance)
    if nativeVoice == nil then nativeVoice = GetConvar('voice_useNativeAudio', 'false') == 'true' end
    return nativeVoice and distance * 3.0 or distance
end

local function speakingRange(player, fallback)
    local state = Player(GetPlayerServerId(player)).state
    local proximity = state.proximity
    local distance = type(proximity) == 'table' and tonumber(proximity.distance) or tonumber(state.voiceRange)
    if (not distance or distance <= 0.0) and player == PlayerId() then distance = MumbleGetTalkerProximity() end
    if distance and distance > 0.0 then return voiceReach(distance) end
    return fallback
end

local function voiceScale(range)
    return math.max(0.4, math.min(2.6, range / VOICE_NORMAL))
end

local function talking(player)
    return MumbleIsPlayerTalking(player) or NetworkIsPlayerTalking(player)
end

local function scanOwnVoice(me)
    local own = Echo.sound('ownvoice')
    if not own or not talking(me) then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    local range = speakingRange(me, VOICE_NORMAL)
    local source = touch('ownvoice', 'ownvoice', ped, GetEntityCoords(ped), range, 600)
    source.scale = voiceScale(range)
end

local function scanVoices(origin)
    local me = PlayerId()
    scanOwnVoice(me)
    local voice = Echo.sound('voice')
    if not voice then return end
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me and talking(player) then
            local other = GetPlayerPed(player)
            local pos = GetEntityCoords(other)
            local speaking = speakingRange(player, voice.range)
            if #(pos - origin) <= math.min(speaking, voice.range * 3.0) then
                local source = touch('voice', 'voice:' .. player, other, pos, speaking, 600)
                source.scale = voiceScale(speaking)
            end
        end
    end
end

local function locateExplosion(origin, range)
    local minX, minY = origin.x - range, origin.y - range
    local size = range * 2.0
    local low, high = origin.z - range, origin.z + range
    for _ = 1, 9 do
        size = size / 2.0
        local found = false
        for cell = 0, 3 do
            local x = minX + (cell % 2) * size
            local y = minY + (cell // 2) * size
            if IsExplosionInArea(-1, x, y, low, x + size, y + size, high) then
                minX, minY, found = x, y, true
                break
            end
        end
        if not found then return nil end
    end
    local maxX, maxY = minX + size, minY + size
    for _ = 1, 8 do
        local middle = (low + high) / 2.0
        if IsExplosionInArea(-1, minX, minY, low, maxX, maxY, middle) then
            high = middle
        elseif IsExplosionInArea(-1, minX, minY, middle, maxX, maxY, high) then
            low = middle
        else
            break
        end
    end
    return vector3(minX + size / 2.0, minY + size / 2.0, (low + high) / 2.0)
end

local function near(list, pos, now, window, metres)
    local found
    local keep = math.max(window, EVENT_QUIET_MS)
    metres = metres or SAME_EVENT_METRES
    for index = #list, 1, -1 do
        local entry = list[index]
        local age = now - entry.seen
        if age > keep then
            table.remove(list, index)
        elseif not found and age <= window and #(entry.pos - pos) <= metres then
            found = entry
        end
    end
    return found
end

local function heard(kind, pos, now, metres, window)
    local list = recent[kind]
    if not list then
        list = {}
        recent[kind] = list
    end
    local entry = near(list, pos, now, window or EVENT_QUIET_MS, metres)
    if entry then
        entry.seen = now
        return false, entry
    end
    list[#list + 1] = { pos = pos, seen = now }
    return true
end

Sources.heard = heard

local function burst(kind, pos, range, hold, how)
    serial = serial + 1
    local source = touch(kind, kind .. ':' .. serial, nil, pos, range, hold, true)
    if Sources.trace then Sources.trace(kind, how, pos) end
    return source
end

Sources.burst = burst

local function traceRepeat(kind, how, pos, entry)
    if not Sources.trace or not entry or entry.traced then return end
    entry.traced = true
    Sources.trace(kind, how, pos)
end

local function watchExplosion(now, origin)
    local explosion = Echo.sound('explosion')
    if not explosion then return end
    if not IsExplosionInSphere(-1, origin.x, origin.y, origin.z, explosion.range) then return end
    local pos = locateExplosion(origin, explosion.range)
    if Sources.probe then Sources.probe('sphere', pos) end
    if not pos then return end
    local entry = near(blasts, pos, now, BLAST_GONE_MS)
    if entry then
        entry.seen = now
        heard('explosion', pos, now)
        return
    end
    blasts[#blasts + 1] = { pos = pos, seen = now }
    local fresh, repeated = heard('explosion', pos, now)
    if fresh then
        burst('explosion', pos, explosion.range, 2600, 'scan')
    else
        traceRepeat('explosion', 'scan-repeat', pos, repeated)
    end
end

local function eventPoint(args, entity)
    local point = type(args) == 'table' and args[1]
    if type(point) == 'table' then
        local x, y, z = tonumber(point[1]), tonumber(point[2]), tonumber(point[3])
        if x and y and z and (x ~= 0.0 or y ~= 0.0) then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    if math.type(entity) == 'integer' and entity ~= 0 and DoesEntityExist(entity) then return GetEntityCoords(entity) end
    return nil
end

local function reported(kind, args, hold, entity, metres, window)
    local sound = Echo.sound(kind)
    if not sound then return end
    local pos = eventPoint(args, entity)
    if not pos then return end
    if #(pos - GetEntityCoords(PlayerPedId())) > sound.range then return end
    local fresh, repeated = heard(kind, pos, GetGameTimer(), metres, window)
    if not fresh then
        traceRepeat(kind, 'event-repeat', pos, repeated)
        return
    end
    return burst(kind, pos, sound.range, hold, 'event')
end

local function timed(kind, args, hold, entity, metres, window)
    local started = Perf.on and clock()
    local source = reported(kind, args, hold, entity, metres, window)
    if started then
        Perf.add('events', started)
        Perf.count('events')
    end
    return source
end

Sources.report = timed

AddEventHandler('CEventShockingExplosion', function(witnesses, entity, args)
    if Sources.probe then Sources.probe('shocking', nil, witnesses, entity, args) end
    timed('explosion', args, 2600)
end)
AddEventHandler('CEventShockingCarCrash', function(_, entity, args) timed('crash', args, 1800, entity) end)
AddEventHandler('CEventShockingCarPileUp', function(_, entity, args) timed('crash', args, 1800, entity) end)
AddEventHandler('CEventShockingCarOnCar', function(_, entity, args) timed('crash', args, 1800, entity, 12.0, 1500) end)
AddEventHandler('CEventShockingBicycleCrash', function(_, entity, args) timed('crash', args, 1500, entity, 12.0, 1500) end)
AddEventHandler('CEventShockingPedRunOver', function(_, entity, args) timed('crash', args, 1500, entity, 12.0, 1500) end)

local function shot(shooter, origin, gunshot)
    if GetWeaponDamageType(GetSelectedPedWeapon(shooter)) == EXPLOSIVE then return end
    local pos = GetEntityCoords(shooter)
    local range = IsPedCurrentWeaponSilenced(shooter) and gunshot.suppressedRange or gunshot.range
    if #(pos - origin) <= range then
        touch('gunshot', 'gunshot:' .. shooter, shooter, pos, range, 1400, true)
        if Sources.trace then Sources.trace('gunshot', shooter == PlayerPedId() and 'own' or 'ped', pos) end
    end
end

local function startFast(gen)
    fastToken = fastToken + 1
    local token = fastToken
    fastActive = true
    CreateThread(function()
        while token == fastToken and gen == scanGen do
            local started = Perf.on and clock()
            local now = GetGameTimer()
            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            if now >= blastAt then
                blastAt = now + BLAST_MS
                watchExplosion(now, origin)
            end
            if now >= ownSquealAt then
                ownSquealAt = now + OWN_SQUEAL_MS
                Sources.checkOwnSqueal(ped, now)
                World.ownVehicle(ped, now)
            end
            local gunshot = Echo.sound('gunshot')
            if gunshot then
                if selfArmed and IsPedShooting(ped) then shot(ped, origin, gunshot) end
                for index = 1, #armed do
                    local shooter = armed[index]
                    if IsPedShooting(shooter) then shot(shooter, origin, gunshot) end
                end
            end
            if now >= hornAt and #honkers > 0 then
                hornAt = now + HORN_MS
                local horn = Config.Sounds.horn
                for index = 1, #honkers do
                    local veh = honkers[index]
                    if IsHornActive(veh) then
                        touch('horn', 'horn:' .. veh, veh, GetEntityCoords(veh), horn.range, 500)
                    end
                end
            end
            if started then
                Perf.add('sources.fast', started)
                Perf.count('sources.frames')
            end
            if #armed > 0 or (selfArmed and gunshot) then
                Wait(0)
            else
                Wait(CALM_MS)
            end
        end
        if token == fastToken then fastActive = false end
    end)
end

function Sources.start()
    scanGen = scanGen + 1
    local gen = scanGen
    CreateThread(function()
        local pass = 0
        while gen == scanGen do
            local perf = Perf.on
            local started = perf and clock()
            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            pass = pass + 1
            selfArmed = IsPedArmed(ped, FIREARMS)
            scanVoices(origin)
            if perf then Perf.add('scan.voices', started) end
            if pass % 2 == 1 then
                local now = GetGameTimer()
                if now > slipsReset then
                    slips, classes, slipsReset = {}, {}, now + SLIPS_RESET_MS
                end
                local mark = perf and clock()
                scanVehicles(origin, GetVehiclePedIsIn(ped, false), now)
                if perf then Perf.add('scan.vehicles', mark) mark = clock() end
                local withArmed = now >= armedAt
                if withArmed then armedAt = now + ARMED_MS end
                scanPeds(ped, origin, withArmed)
                if perf then Perf.add('scan.peds', mark) mark = clock() end
                World.scan(origin, now, pass)
                if perf then Perf.add('scan.world', mark) end
            end
            if not fastActive then startFast(gen) end
            local mark = perf and clock()
            Sources.prune(GetGameTimer())
            if perf then Perf.add('scan.prune', mark) end
            Wait(SCAN_MS)
        end
    end)
end

function Sources.stop()
    scanGen = scanGen + 1
    fastToken = fastToken + 1
    fastActive = false
    armed, honkers, recent, blasts, classes = {}, {}, {}, {}, {}
    hornAt, armedAt, blastAt, selfArmed = 0, 0, 0, false
    Sources.active, Sources.count = {}, 0
    World.reset()
end

function Sources.scanOnce()
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    scanVoices(origin)
    watchExplosion(GetGameTimer(), origin)
    scanVehicles(origin, GetVehiclePedIsIn(ped, false), GetGameTimer())
    scanPeds(ped, origin, true)
    World.scan(origin, GetGameTimer(), 1)
end

function Sources.stats()
    return { sources = Sources.count, armed = #armed, honkers = #honkers, fast = fastActive }
end

World = {}

local VEHICLE_NEAREST = 12
local STATE_KEEP_TICKS = 8
local SPORTY = { [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [22] = true }
local CYCLE = 13
local WINDOWS = 7
local TYRES = { 0, 1, 2, 3, 4, 5 }
local DOORS = 5
local DOOR_OPEN, DOOR_SHUT = 0.08, 0.02
local LIFT_RPM = 0.7
local POP_GAP_MS = 170
local POP_COOLDOWN_MS = 700
local LIMITER_COOLDOWN_MS = 1200
local POPS_RECHECK_MS = 5000
local IMPACT_CHANGE = 6.0
local IMPACT_DAMAGE = 30.0
local IMPACT_COOLDOWN_MS = 900
local SCREAM_GAP_MS = 900
local PAIN_GAP_MS = 600
local PEDS_RESET_MS = 30000
local PROP_MOVED = 0.3
local PROP_STILL = 0.05
local PROP_FLYING = 1.6
local PROP_COOLDOWN_MS = 700
local FIRE_CELL = 6.0
local MELEE = 2

local performingMelee = IsPedPerformingMeleeAction or IsPedInMeleeCombat
local radioOn = IsVehicleRadioOn
local radioLoud = IsVehicleRadioLoud

local states, objects, peds = {}, {}, {}
local doorSlots, exhausts, dimensions = {}, {}, {}
local tick, scanId, pedsReset = 0, 0, 0
local vehicleKinds, pedKinds = {}, {}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function furthest(kinds)
    local range = 0.0
    for _, sound in pairs(kinds) do
        if sound.range and sound.range > range then range = sound.range end
    end
    return range
end

local function listen(kinds, ...)
    for index = 1, select('#', ...) do
        local kind = select(index, ...)
        kinds[kind] = Echo.sound(kind)
    end
    return kinds
end

function World.vehicleReach()
    vehicleKinds = listen({}, 'backfire', 'tyrepop', 'glass', 'door', 'music', 'crash', 'fire')
    return furthest(vehicleKinds)
end

function World.pedReach()
    pedKinds = listen({}, 'fight', 'scream', 'chatter', 'fire')
    return furthest(pedKinds)
end

local function emit(kind, key, entity, pos, range, hold, scale)
    local source = Sources.touch(kind, key, entity, pos, range, hold, true)
    source.scale = scale
    if Sources.trace then Sources.trace(kind, 'world', pos) end
    return source
end

local function dimsOf(model)
    local known = dimensions[model]
    if known then return known[1], known[2] end
    local low, high = GetModelDimensions(model)
    low, high = low or vector3(-1.0, -2.2, 0.0), high or vector3(1.0, 2.2, 1.4)
    dimensions[model] = { low, high }
    return low, high
end

local function windowsIntact(veh)
    local count = 0
    for window = 0, WINDOWS do
        if IsVehicleWindowIntact(veh, window) then count = count + 1 end
    end
    return count
end

local function tyresBurst(veh)
    local count = 0
    for index = 1, #TYRES do
        if IsVehicleTyreBurst(veh, TYRES[index], false) then count = count + 1 end
    end
    return count
end

local function doorsOf(veh, model)
    local slots = doorSlots[model]
    if slots then return slots end
    slots = {}
    for door = 0, DOORS do
        if GetIsDoorValid(veh, door) then slots[#slots + 1] = door end
    end
    doorSlots[model] = slots
    return slots
end

local function doorPoint(veh, model, door)
    local low, high = dimsOf(model)
    if door == 4 then return GetOffsetFromEntityInWorldCoords(veh, 0.0, high.y * 0.85, 0.0) end
    if door == 5 then return GetOffsetFromEntityInWorldCoords(veh, 0.0, low.y * 0.9, 0.0) end
    local side = door % 2 == 0 and low.x or high.x
    local along = door < 2 and high.y * 0.15 or low.y * 0.3
    return GetOffsetFromEntityInWorldCoords(veh, side, along, 0.0)
end

local function exhaustPoint(veh, model)
    local bone = exhausts[model]
    if bone == nil then
        bone = GetEntityBoneIndexByName(veh, 'exhaust')
        exhausts[model] = bone
    end
    if bone ~= -1 then return GetWorldPositionOfEntityBone(veh, bone) end
    local low = dimsOf(model)
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, low.y, 0.0)
end

local function health(veh)
    return GetVehicleBodyHealth(veh) + math.max(0.0, GetVehicleEngineHealth(veh))
end

local function empty(veh)
    return IsVehicleSeatFree(veh, -1) and GetVehicleNumberOfPassengers(veh) == 0
end

local function fresh(veh, model)
    local state = {
        model = model, windows = windowsIntact(veh), tyres = tyresBurst(veh), health = health(veh),
        doors = {}, tick = tick,
    }
    for _, door in ipairs(doorsOf(veh, model)) do state.doors[door] = GetVehicleDoorAngleRatio(veh, door) end
    states[veh] = state
    return state
end

local function stateOf(veh)
    local model = GetEntityModel(veh)
    local state = states[veh]
    if state and state.model == model then
        state.tick = tick
        return state, false
    end
    return fresh(veh, model), true
end

local function popsAllowed(veh, state, class, sound, now)
    if now < (state.popsCheck or 0) then return state.pops end
    state.popsCheck = now + POPS_RECHECK_MS
    local allowed = class ~= CYCLE and not Sources.isElectric(veh) and (sound.stockCars == true or SPORTY[class]
        or GetVehicleMod(veh, 4) >= 0 or GetVehicleMod(veh, 11) >= 2 or GetVehicleEngineHealth(veh) < 400.0)
    state.pops = allowed == true
    return state.pops
end

local function popAt(veh, model, sound, pops, scale)
    for index = 0, pops - 1 do
        SetTimeout(index * POP_GAP_MS, function()
            if not DoesEntityExist(veh) or not Echo.sound('backfire') then return end
            emit('backfire', 'backfire:' .. veh, nil, exhaustPoint(veh, model), sound.range, 900, scale * (index == 0 and 1.0 or 0.8))
        end)
    end
end

local function backfire(veh, state, class, sound, now)
    if not GetIsVehicleEngineRunning(veh) then
        state.rpm = nil
        return
    end
    local rpm = GetVehicleCurrentRpm(veh)
    local throttle = math.abs(GetVehicleThrottleOffset(veh))
    local gear = GetVehicleCurrentGear(veh)
    local last, lastThrottle, lastGear = state.rpm, state.throttle, state.gear
    state.rpm, state.throttle, state.gear = rpm, throttle, gear
    if not last or now < (state.popAt or 0) or not popsAllowed(veh, state, class, sound, now) then return end
    local pops, cooldown = 0, POP_COOLDOWN_MS
    if last > LIFT_RPM and lastThrottle > 0.5 and throttle < 0.15 then
        pops = last > 0.85 and 3 or 2
    elseif gear > lastGear and lastGear > 0 and last > 0.82 and lastThrottle > 0.6 then
        pops = 1
    elseif rpm > 0.97 and throttle > 0.8 and GetEntitySpeed(veh) < 2.0 then
        pops, cooldown = 1, LIMITER_COOLDOWN_MS
    end
    if pops == 0 then return end
    state.popAt = now + cooldown
    popAt(veh, state.model, sound, pops, 0.7 + 0.4 * last)
end

local function impact(veh, state, pos, sound, now)
    local velocity = GetEntityVelocity(veh)
    local body = health(veh)
    local lastVelocity, lastBody = state.velocity, state.body
    state.velocity, state.body = velocity, body
    if not lastVelocity or now < (state.crashAt or 0) then return end
    local change = #(velocity - lastVelocity)
    local damage = lastBody - body
    if change < IMPACT_CHANGE and (damage < IMPACT_DAMAGE or change < 2.0) then return end
    state.crashAt = now + IMPACT_COOLDOWN_MS
    if not Sources.heard('crash', pos, now, 10.0, 1200) then return end
    local source = Sources.burst('crash', pos, sound.range, 1500, 'physics')
    source.scale = clamp(0.45 + change / 22.0 + math.max(0.0, damage) / 300.0, 0.45, 1.5)
end

local function watchDoors(veh, state, sound, dist)
    local near = sound and dist <= sound.range
    for door, last in pairs(state.doors) do
        local ratio = IsVehicleDoorDamaged(veh, door) and last or GetVehicleDoorAngleRatio(veh, door)
        state.doors[door] = ratio
        if near then
            local scale
            if last > DOOR_OPEN and ratio < DOOR_SHUT then
                scale = 1.0
            elseif last < DOOR_SHUT and ratio > DOOR_OPEN then
                scale = 0.6
            end
            if scale then emit('door', ('door:%d:%d'):format(veh, door), nil, doorPoint(veh, state.model, door), sound.range, 900, scale) end
        end
    end
end

local function watchGlass(veh, state, pos, sound, dist, damaged)
    local windows = windowsIntact(veh)
    local broke = windows < state.windows
    state.windows = windows
    if not broke or not sound or dist > sound.range then return end
    if not (damaged or empty(veh) or GetVehicleDoorLockStatus(veh) >= 2) then return end
    emit('glass', 'glass:' .. veh, nil, pos, sound.range, 1200, 1.0)
end

local function watchTyres(veh, state, pos, sound, dist)
    local burst = tyresBurst(veh)
    local popped = burst > state.tyres
    state.tyres = burst
    if popped and sound and dist <= sound.range then emit('tyrepop', 'tyrepop:' .. veh, nil, pos, sound.range, 1200, 1.0) end
end

local function watchMusic(veh, pos, sound, dist)
    if not radioOn or dist > sound.range or not GetIsVehicleEngineRunning(veh) or not radioOn(veh) then return end
    local driver = GetPedInVehicleSeat(veh, -1)
    local playing = driver ~= 0 and IsPedAPlayer(driver)
    if not playing and sound.npcs ~= false and radioLoud then playing = radioLoud(veh) == true end
    if playing then Sources.touch('music', 'music:' .. veh, veh, pos, sound.range, 1300) end
end

local function watchFire(veh, pos, sound, dist)
    if dist > sound.range then return end
    if IsEntityOnFire(veh) or GetVehicleEngineHealth(veh) < 0.0 then
        Sources.touch('fire', 'fire:' .. veh, veh, pos, sound.range, 1400)
    end
end

local function watchVehicle(veh, pos, dist, class, now, own)
    local kinds = vehicleKinds
    local state, isNew = stateOf(veh)
    if isNew then return end
    local before = state.health
    state.health = health(veh)
    local damaged = before - state.health > 1.0
    if kinds.backfire and not own and dist <= kinds.backfire.range then backfire(veh, state, class, kinds.backfire, now) end
    if kinds.crash and not own and dist <= kinds.crash.range then impact(veh, state, pos, kinds.crash, now) end
    watchTyres(veh, state, pos, kinds.tyrepop, dist)
    watchGlass(veh, state, pos, kinds.glass, dist, damaged)
    watchDoors(veh, state, kinds.door, dist)
    if kinds.music and not own then watchMusic(veh, pos, kinds.music, dist) end
    if kinds.fire then watchFire(veh, pos, kinds.fire, dist) end
end

function World.vehicles(nearby, myVehicle, origin, now)
    if not next(vehicleKinds) then
        if next(states) then states = {} end
        return
    end
    tick = tick + 1
    local checked = 0
    for index = 1, #nearby do
        if checked >= VEHICLE_NEAREST then break end
        local entry = nearby[index]
        checked = checked + 1
        watchVehicle(entry.veh, entry.pos, entry.dist, entry.class, now, false)
    end
    if myVehicle ~= 0 then watchVehicle(myVehicle, GetEntityCoords(myVehicle), 0.0, Sources.classOf(myVehicle), now, true) end
    for veh, state in pairs(states) do
        if tick - state.tick > STATE_KEEP_TICKS or not DoesEntityExist(veh) then states[veh] = nil end
    end
end

function World.ownVehicle(ped, now)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    local backfireSound, crashSound = Echo.sound('backfire'), Echo.sound('crash')
    if not backfireSound and not crashSound then return end
    local state = states[veh]
    if not state or state.model ~= GetEntityModel(veh) then state = fresh(veh, GetEntityModel(veh)) end
    if backfireSound then backfire(veh, state, Sources.classOf(veh), backfireSound, now) end
    if crashSound then impact(veh, state, GetEntityCoords(veh), crashSound, now) end
end

local function pedState(ped)
    local state = peds[ped]
    if not state then
        state = {}
        peds[ped] = state
    end
    return state
end

local function scream(ped, pos, sound, now, gap)
    local state = pedState(ped)
    if now < (state.screamAt or 0) then return end
    state.screamAt = now + gap
    emit('scream', 'scream:' .. ped, ped, pos, sound.range, 1100, 1.0)
end

local function panicked(ped)
    return IsPedFleeing(ped) or IsPedRagdoll(ped) or IsPedInCombat(ped, 0) or IsPedBeingStunned(ped, 0)
end

function World.ped(ped, pos, dist, now)
    local kinds = pedKinds
    local fight, screams, chatter, fire = kinds.fight, kinds.scream, kinds.chatter, kinds.fire
    if fight and dist <= fight.range and performingMelee(ped) then
        Sources.touch('fight', 'fight:' .. ped, ped, pos, fight.range, 800, true)
    end
    local hearScream = screams and dist <= screams.range
    if (hearScream or fire) and IsEntityOnFire(ped) then
        if fire and dist <= fire.range then Sources.touch('fire', 'fire:' .. ped, ped, pos, fire.range, 1400) end
        if hearScream then scream(ped, pos, screams, now, SCREAM_GAP_MS) end
        return
    end
    local hearChatter = chatter and dist <= chatter.range
    if not (hearScream or hearChatter) or not IsAnySpeechPlaying(ped) then return end
    if hearScream and panicked(ped) then
        scream(ped, pos, screams, now, SCREAM_GAP_MS)
    elseif hearChatter then
        Sources.touch('chatter', 'chatter:' .. ped, ped, pos, chatter.range, 800)
    end
end

local function scanFire(origin)
    local fire = Echo.sound('fire')
    if not fire or GetNumberOfFiresInRange(origin.x, origin.y, origin.z, fire.range) == 0 then return end
    local found, pos = GetClosestFirePos(origin.x, origin.y, origin.z)
    if not found or not pos or #(pos - origin) > fire.range then return end
    local key = ('fire:%d:%d'):format(math.floor(pos.x / FIRE_CELL), math.floor(pos.y / FIRE_CELL))
    Sources.touch('fire', key, nil, pos, fire.range, 1400)
end

local function doorObject(obj, pos)
    local ok, found = pcall(DoorSystemFindExistingDoor, pos.x, pos.y, pos.z, GetEntityModel(obj))
    return ok and found == true
end

local function propSound(obj, state, pos, now, props, door, scale)
    if now < (state.at or 0) or IsEntityAttached(obj) then return end
    state.at = now + PROP_COOLDOWN_MS
    if doorObject(obj, pos) then
        if door then emit('door', 'door:obj:' .. obj, nil, pos, door.range, 900, 0.6) end
        return
    end
    emit('props', 'props:' .. obj, nil, pos, props.range, 1200, scale)
end

local function scanProps(origin, now)
    local props = Echo.sound('props')
    if not props then
        if next(objects) then objects = {} end
        return
    end
    local door = Echo.sound('door')
    scanId = scanId + 1
    local range = props.range
    for _, obj in ipairs(GetGamePool('CObject')) do
        local pos = GetEntityCoords(obj)
        if #(pos - origin) <= range then
            local state = objects[obj]
            if not state then
                objects[obj] = { pos = pos, broken = HasObjectBeenBroken(obj, 0), seen = scanId }
            else
                local moved = #(pos - state.pos)
                local scale
                if not state.broken and HasObjectBeenBroken(obj, 0) then
                    state.broken, scale = true, 1.2
                elseif moved > PROP_MOVED and state.still then
                    scale = clamp(0.55 + moved * 0.25, 0.55, 1.2)
                elseif moved < PROP_STILL and state.flying then
                    scale = 0.8
                end
                state.still, state.flying = moved < PROP_STILL, moved > PROP_FLYING
                state.pos, state.seen = pos, scanId
                if scale then propSound(obj, state, pos, now, props, door, scale) end
            end
        end
    end
    for obj, state in pairs(objects) do
        if state.seen ~= scanId then objects[obj] = nil end
    end
end

function World.scan(origin, now, pass)
    if now > pedsReset then peds, pedsReset = {}, now + PEDS_RESET_MS end
    scanProps(origin, now)
    if pass % 4 == 1 then scanFire(origin) end
end

function World.reset()
    states, objects, peds = {}, {}, {}
    vehicleKinds, pedKinds = {}, {}
end

local function damaged(args)
    if not Echo.enabled or type(args) ~= 'table' then return end
    local victim, weapon = args[1], args[7]
    if math.type(victim) ~= 'integer' or victim == 0 or not DoesEntityExist(victim) or not IsEntityAPed(victim) then return end
    local me = PlayerPedId()
    if victim == me then return end
    local pos = GetEntityCoords(victim)
    local dist = #(pos - GetEntityCoords(me))
    local now = GetGameTimer()
    local fight = Echo.sound('fight')
    if fight and dist <= fight.range and math.type(weapon) == 'integer' and GetWeaponDamageType(weapon) == MELEE then
        emit('fight', 'fight:' .. victim, victim, pos, fight.range, 900, 1.0)
    end
    local screams = Echo.sound('scream')
    if screams and screams.pain ~= false and dist <= screams.range then scream(victim, pos, screams, now, PAIN_GAP_MS) end
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then damaged(args) end
end)

AddEventHandler('CEventShockingPropertyDamage', function(_, entity, args)
    local source = Sources.report('props', args, 1200, entity, 6.0, 1000)
    if source then source.scale = 1.1 end
end)

AddEventHandler('CEventShockingSeenMeleeAction', function(_, entity, args)
    Sources.report('fight', args, 900, entity, 4.0, 600)
end)

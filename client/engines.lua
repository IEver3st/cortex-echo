Engines = {}

local TAU = math.pi * 2.0
local IDLE_RPM = 0.2
local LIFT = 0.08
local MARK = 0.3
local SIZE = { s = 0.75, m = 1.0, l = 1.4 }
local DENSITY = { s = 1.35, m = 1.0, l = 0.8 }

local CUT_MS = 220
local REDLINE = 0.88

local WAKE_START = 0.4
local WAKE_BASE, WAKE_SPAN = 3.5, 13.0
local WAKE_SPEED, WAKE_CARRY = 6.0, 1.15
local WAKE_ACCENT_SPEED = 14.0
local WAKE_IDLE_RATE, WAKE_TOP_RATE = 0.45, 2.5
local WAKE_QUIET_RATE, WAKE_QUIET_SPEED = 1.5, 3.0
local WAKE_RINGS = 14
local WAKE_GAP, WAKE_GAP_GROWTH = 0.85, 0.06
local WAKE_FEWEST, WAKE_MOST = 22, 84
local WAKE_FADE = 1.25
local WAKE_ACCENT = 1.25
local WAKE_PLAIN = 0.85

local PULSE_START, PULSE_STEP, PULSE_RINGS = 0.45, 0.85, 12
local PULSE_GAP = 0.55
local PULSE_BASE, PULSE_BASE_REACH = 0.2, 1.4
local PULSE_REDLINE, PULSE_REDLINE_REACH = 0.55, 0.9
local PULSE_IDLE_RATE, PULSE_TOP_RATE = 0.4, 2.4
local PULSE_QUIET_RATE, PULSE_QUIET_SPEED = 0.8, 2.4
local PULSE_REACH, PULSE_REACH_SPAN = 2.4, 7.5
local PULSE_SPEED, PULSE_SPEED_SPAN = 4.0, 8.0
local PULSE_WIDTH, PULSE_GAIN = 0.55, 0.75
local SHIFT_SPEED, SHIFT_WIDTH, SHIFT_GAIN = 20.0, 0.32, 1.1
local PULSE_REAR, PULSE_FRONT = 0.9, 0.25

local SECTORS = 16
local PROBE_MS = 250
local PROBE_FLAGS = 1
local PROBE_HEIGHT = 0.9
local PROBE_SLACK = 0.6

local throughWalls = Config.Marks.throughWalls == true
local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function ringPoint(a, b, d, at)
    local quarter = math.pi * 0.5 * d
    local sides = { 2.0 * a, quarter, 2.0 * b, quarter, 2.0 * a, quarter, 2.0 * b, quarter }
    local segment = 1
    while segment < 8 and at > sides[segment] do
        at = at - sides[segment]
        segment = segment + 1
    end
    local t = d > 0.0 and at / d or 0.0
    local cos, sin = math.cos(t), math.sin(t)
    if segment == 1 then return b + d, -a + at, 0.0, 1.0 end
    if segment == 2 then return b + d * cos, a + d * sin, -sin, cos end
    if segment == 3 then return b - at, a + d, -1.0, 0.0 end
    if segment == 4 then return -b - d * sin, a + d * cos, -cos, -sin end
    if segment == 5 then return -b - d, a - at, 0.0, -1.0 end
    if segment == 6 then return -b - d * cos, -a - d * sin, sin, -cos end
    if segment == 7 then return -b + at, -a - d, 1.0, 0.0 end
    return b + d * sin, -a - d * cos, cos, sin
end

local function perimeter(foot, d)
    return 4.0 * foot.a + 4.0 * foot.b + TAU * d
end

local function markSize()
    return MARK * (SIZE[Echo.size] or 1.0)
end

local function density()
    return DENSITY[Echo.detail] or 1.0
end

local function revRate(revs, idle, top)
    return idle * (top / idle) ^ revs
end

local function freshEngine()
    return {
        gear = -1, rpm = 0.0, revs = 0.0, throttle = 0.0, speed = 0.0, quiet = true,
        shiftAt = -100000, accented = true,
    }
end

function Engines.attach(halo, previous)
    if previous and previous.engine then
        halo.engine, halo.wake, halo.pulse, halo.walls = previous.engine, previous.wake, previous.pulse, previous.walls
        return
    end
    halo.engine = freshEngine()
    halo.wake = { rings = {}, phase = 0.0 }
    halo.pulse = { pulses = {}, phase = 0.0 }
    halo.walls = { at = 0, pending = false }
end

local function readEngine(halo, entity, source, now, dt)
    local engine = halo.engine
    local running = GetIsVehicleEngineRunning(entity)
    local rpm = GetVehicleCurrentRpm(entity)
    local throttle = math.min(1.0, math.abs(GetVehicleThrottleOffset(entity)))
    local gear = GetVehicleCurrentGear(entity)
    local speed = GetEntitySpeed(entity)
    local quiet = source.electric == true or not running
    engine.quiet, engine.rpm, engine.throttle, engine.speed = quiet, rpm, throttle, speed
    engine.revs = clamp((rpm - IDLE_RPM) / (1.0 - IDLE_RPM), 0.0, 1.0)
    engine.accent = false
    if not quiet and engine.gear > 0 and gear > engine.gear then
        engine.shiftAt = now
        engine.accented = false
    end
    engine.gear = gear
    local cutting = now - engine.shiftAt < CUT_MS
    if not engine.accented and not cutting then
        engine.accented = true
        engine.accent = true
    end
    engine.firing = not cutting
    engine.redline = not quiet and not cutting and rpm > REDLINE
end

local function settleWalls(walls)
    local raw = walls.next
    local free = { x = walls.x, y = walls.y }
    for index = 1, SECTORS do
        local left = raw[(index - 2) % SECTORS + 1]
        local right = raw[index % SECTORS + 1]
        free[index] = math.max(raw[index], math.min(left, right))
    end
    walls.free = free
end

local function probeWalls(halo, entity, now)
    if throughWalls then return end
    local walls = halo.walls
    if walls.pending then
        local waiting = false
        for index = 1, SECTORS do
            local handle = walls.handles[index]
            if handle then
                local status, hit, coords = GetShapeTestResult(handle)
                if status == 1 then
                    waiting = true
                else
                    walls.handles[index] = nil
                    if status == 2 and (hit == true or hit == 1) and coords then
                        local dx, dy = coords.x - walls.x, coords.y - walls.y
                        walls.next[index] = math.sqrt(dx * dx + dy * dy)
                    end
                end
            end
        end
        if not waiting then
            walls.pending = false
            settleWalls(walls)
        end
        return
    end
    if now < walls.at or not entity then return end
    walls.at = now + PROBE_MS
    local x, y = halo.cx, halo.cy
    local z = halo.gz + PROBE_HEIGHT
    local range = WAKE_BASE + WAKE_SPAN + 2.0
    walls.x, walls.y, walls.next, walls.handles, walls.pending = x, y, {}, {}, true
    for index = 1, SECTORS do
        local angle = (index - 0.5) / SECTORS * TAU
        local dx, dy = math.cos(angle) * range, math.sin(angle) * range
        walls.next[index] = range
        local handle = StartShapeTestLosProbe(x, y, z, x + dx, y + dy, z + halo.sx * dx + halo.sy * dy, PROBE_FLAGS, entity, 7)
        if handle and handle ~= 0 then walls.handles[index] = handle end
    end
end

local function emitRing(halo, now, accent)
    local engine = halo.engine
    local rings = halo.wake.rings
    if #rings >= WAKE_RINGS then table.remove(rings, 1) end
    local level = accent and math.max(halo.level, 0.7) or halo.level
    rings[#rings + 1] = {
        x = halo.cx, y = halo.cy, z = halo.gz + LIFT, sx = halo.sx, sy = halo.sy, fx = halo.fx, fy = halo.fy,
        born = now, level = level, accent = accent, reach = WAKE_BASE + WAKE_SPAN * level,
        vw = (accent and WAKE_ACCENT_SPEED or WAKE_SPEED) + WAKE_CARRY * engine.speed,
        turn = math.random(), free = halo.walls.free,
    }
end

local function stepWake(halo, now, dt, live)
    local engine = halo.engine
    local wake = halo.wake
    live = live and (throughWalls or halo.walls.free ~= nil)
    if live and engine.firing and halo.level > 0.05 then
        local rate
        if engine.quiet then
            rate = WAKE_QUIET_RATE + WAKE_QUIET_SPEED * math.min(1.0, engine.speed / 30.0)
        else
            rate = revRate(engine.revs, WAKE_IDLE_RATE, WAKE_TOP_RATE)
        end
        wake.phase = wake.phase + rate * dt
        if wake.phase >= 1.0 then
            wake.phase = wake.phase % 1.0
            emitRing(halo, now, false)
        end
    end
    if live and engine.accent and halo.level > 0.05 then emitRing(halo, now, true) end
    local rings = wake.rings
    local kept, furthest = 0, 0.0
    for index = 1, #rings do
        local ring = rings[index]
        local d = WAKE_START + (now - ring.born) / 1000.0 * ring.vw
        if d < ring.reach then
            kept = kept + 1
            rings[kept] = ring
            local dx, dy = ring.x - halo.cx, ring.y - halo.cy
            local extent = math.sqrt(dx * dx + dy * dy) + d
            if extent > furthest then furthest = extent end
        end
    end
    for index = kept + 1, #rings do rings[index] = nil end
    return furthest
end

local function stepPulse(halo, now, dt, live)
    local engine = halo.engine
    local pulse = halo.pulse
    if live and engine.firing and halo.level > 0.05 then
        local rate
        if engine.quiet then
            rate = PULSE_QUIET_RATE + PULSE_QUIET_SPEED * math.min(1.0, engine.speed / 30.0)
        else
            rate = revRate(engine.revs, PULSE_IDLE_RATE, PULSE_TOP_RATE)
        end
        pulse.phase = pulse.phase + rate * dt
        if pulse.phase >= 1.0 then
            pulse.phase = pulse.phase % 1.0
            pulse.pulses[#pulse.pulses + 1] = {
                born = now, speed = PULSE_SPEED + PULSE_SPEED_SPAN * engine.revs, width = PULSE_WIDTH, gain = PULSE_GAIN, throttle = engine.throttle,
            }
        end
    end
    if live and engine.accent and halo.level > 0.05 then
        pulse.pulses[#pulse.pulses + 1] = { born = now, speed = SHIFT_SPEED, width = SHIFT_WIDTH, gain = SHIFT_GAIN, throttle = 0.4 }
    end
    local reach = PULSE_REACH + PULSE_REACH_SPAN * halo.level
    pulse.reach = reach
    local pulses = pulse.pulses
    local kept = 0
    for index = 1, #pulses do
        local item = pulses[index]
        if PULSE_START + (now - item.born) / 1000.0 * item.speed < reach + 1.0 then
            kept = kept + 1
            pulses[kept] = item
        end
    end
    for index = kept + 1, #pulses do pulses[index] = nil end
    return reach
end

local function pulseLayout(halo)
    local foot = halo.print
    local gap = PULSE_GAP * density()
    local layout = { detail = Echo.detail, print = foot, rings = {} }
    for ring = 0, PULSE_RINGS - 1 do
        local d = PULSE_START + ring * PULSE_STEP
        local per = perimeter(foot, d)
        local count = math.max(8, math.floor(per / gap + 0.5))
        local marks = {}
        local shift = (ring % 2) * 0.5
        for slot = 0, count - 1 do
            local x, y, tx, ty = ringPoint(foot.a, foot.b, d, (slot + shift) / count * per)
            marks[#marks + 1] = {
                x = x, y = y + foot.y, tx = tx, ty = ty,
                back = clamp(-y / foot.a, 0.0, 1.0), front = clamp(y / foot.a, 0.0, 1.0),
            }
        end
        layout.rings[#layout.rings + 1] = { d = d, marks = marks }
    end
    halo.pulseLayout = layout
end

function Engines.track(halo, entity, source, now, dt, live)
    if live then
        readEngine(halo, entity, source, now, dt)
        halo.mode = source.own and 'pulse' or 'wake'
        if halo.mode == 'wake' then probeWalls(halo, entity, now) end
    else
        halo.engine.accent = false
        if halo.walls.pending then probeWalls(halo, nil, now) end
    end
    local foot = halo.print
    local body = math.sqrt(foot.a * foot.a + foot.b * foot.b) + math.abs(foot.y)
    local extent
    if halo.mode == 'pulse' then
        extent = stepPulse(halo, now, dt, live) + body
        if #halo.wake.rings > 0 then extent = math.max(extent, stepWake(halo, now, dt, false) + body) end
    else
        extent = stepWake(halo, now, dt, live) + body
        if #halo.pulse.pulses > 0 then stepPulse(halo, now, dt, false) end
    end
    halo.reach = math.max(extent, body + 2.0)
end

function Engines.busy(halo)
    return #halo.wake.rings > 0 or #halo.pulse.pulses > 0
end

local function drawWake(halo, put, now, stride)
    local foot = halo.print
    local a, b, fy = foot.a, foot.b, foot.y
    local size = markSize()
    local spacing = density()
    local base = halo.alpha
    local rings = halo.wake.rings
    for index = 1, #rings do
        local ring = rings[index]
        local d = WAKE_START + (now - ring.born) / 1000.0 * ring.vw
        local reach = ring.reach
        if d < reach then
            local fade = (1.0 - d / reach) ^ WAKE_FADE
            local alpha = base * (0.35 + 0.65 * ring.level) * fade * (ring.accent and WAKE_ACCENT or WAKE_PLAIN)
            if alpha > 3.0 then
                if alpha > 255.0 then alpha = 255.0 end
                alpha = math.floor(alpha)
                local per = perimeter(foot, d)
                local count = clamp(math.floor(per / ((WAKE_GAP + d * WAKE_GAP_GROWTH) * spacing) + 0.5), WAKE_FEWEST, WAKE_MOST)
                count = math.max(8, count // stride)
                local radius = size * (1.0 + d * 0.03) * (ring.accent and 1.3 or 1.0)
                local ux, uy = ring.fx, ring.fy
                local rx, ry = uy, -ux
                local cx, cy, cz, sx, sy = ring.x, ring.y, ring.z, ring.sx, ring.sy
                local free = ring.free
                for slot = 0, count - 1 do
                    local x, y, tx, ty = ringPoint(a, b, d, (slot + ring.turn) / count * per)
                    y = y + fy
                    local px, py = cx + x * rx + y * ux, cy + x * ry + y * uy
                    local open = true
                    if free then
                        local dx, dy = px - free.x, py - free.y
                        local angle = math.atan(dy, dx)
                        if angle < 0.0 then angle = angle + TAU end
                        local sector = math.floor(angle / TAU * SECTORS) % SECTORS + 1
                        open = dx * dx + dy * dy <= (free[sector] + PROBE_SLACK) ^ 2
                    end
                    if open then
                        put(px, py, cz + sx * (px - cx) + sy * (py - cy), sx, sy, tx * rx + ty * ux, tx * ry + ty * uy, radius, alpha)
                    end
                end
            end
        end
    end
end

local function drawPulse(halo, put, now, stride)
    local layout = halo.pulseLayout
    if not layout or layout.detail ~= Echo.detail or layout.print ~= halo.print then
        pulseLayout(halo)
        layout = halo.pulseLayout
    end
    local engine = halo.engine
    local pulse = halo.pulse
    local reach = pulse.reach or PULSE_REACH
    local pulses = pulse.pulses
    local size = markSize()
    local base = halo.alpha
    local throttle = engine.throttle
    local hx, hy, hz = halo.cx, halo.cy, halo.gz + LIFT
    local ux, uy = halo.fx, halo.fy
    local rx, ry = uy, -ux
    local sx, sy = halo.sx, halo.sy
    local level = halo.level
    for ringIndex = 1, #layout.rings do
        local ring = layout.rings[ringIndex]
        local d = ring.d
        if d > reach then break end
        local light, rear = 0.0, 0.0
        for index = 1, #pulses do
            local item = pulses[index]
            local at = PULSE_START + (now - item.born) / 1000.0 * item.speed
            local k = (d - at) / item.width
            if k > -2.5 and k < 2.5 then
                local energy = math.exp(-k * k) * item.gain * math.max(0.0, 1.0 - at / (reach + 1.0))
                light = light + energy
                rear = rear + energy * item.throttle
            end
        end
        local floor = 0.0
        if d < PULSE_BASE_REACH and level > 0.05 then floor = PULSE_BASE end
        if engine.redline and d < PULSE_REDLINE_REACH then floor = PULSE_REDLINE end
        local total = floor + light
        if total >= 0.03 then
            local fall = 1.0 - 0.55 * d / reach
            local share = light > 0.0 and rear / light or 0.0
            local strength = base * total * fall * 0.9
            local radius = size * (1.0 + d * 0.03)
            local marks = ring.marks
            for index = 1, #marks, stride do
                local mark = marks[index]
                local alpha = strength * (1.0 + PULSE_REAR * mark.back * share - PULSE_FRONT * mark.front * throttle)
                if alpha > 3.0 then
                    if alpha > 255.0 then alpha = 255.0 end
                    local x, y = mark.x, mark.y
                    local px, py = hx + x * rx + y * ux, hy + x * ry + y * uy
                    local tx, ty = mark.tx, mark.ty
                    put(px, py, hz + sx * (px - hx) + sy * (py - hy), sx, sy, tx * rx + ty * ux, tx * ry + ty * uy, radius, math.floor(alpha))
                end
            end
        end
    end
end

function Engines.draw(halo, put, now)
    local stride = halo.stride or 1
    if halo.mode == 'pulse' then
        drawPulse(halo, put, now, stride)
        if #halo.wake.rings > 0 then drawWake(halo, put, now, stride) end
    else
        drawWake(halo, put, now, stride)
        if #halo.pulse.pulses > 0 and halo.pulseLayout then drawPulse(halo, put, now, stride) end
    end
end

function Engines.report(halo)
    local engine = halo.engine
    return {
        mode = halo.mode, rings = #halo.wake.rings, pulses = #halo.pulse.pulses,
        rpm = engine.rpm, gear = engine.gear, throttle = engine.throttle, redline = engine.redline == true,
        walls = halo.walls.free and (function()
            local closest = math.huge
            for index = 1, SECTORS do closest = math.min(closest, halo.walls.free[index]) end
            return closest
        end)() or -1,
    }
end

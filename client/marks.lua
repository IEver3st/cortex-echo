Marks = { flat = false }

local PROBE_FLAGS = 19
local PROBE_OPTIONS = 7
local IN_FLIGHT = 64
local BACKLOG = 400
local LIFT = 0.035
local IDLE_MS = 120
local BURST_GAP_MS = 340
local REPULSE_MS = 340
local PULSES = 12
local MOVING_SPEED = 1.5
local STEP_SPEED = 0.9
local PREVIEW_MS = 700
local REBUILD_METRES = 2.5
local STEP_REBUILD_METRES = 0.4
local BACKLOG_REBUILD_METRES = 10.0
local FIELD_KEEP_MS = 5000
local NUDGE_METRES = 2.0
local STALE_SHARE = 0.35
local TAU = math.pi * 2.0
local ROOT3 = math.sqrt(3.0)
local TXD = 'cortex_echo_marks'

local SINGLE_RADIUS = 0.11
local CLUSTER_MIN, CLUSTER_MAX, CLUSTER_SHARE = 0.5, 3.0, 0.45
local MEDIUM_CLUSTER, WIDE_CLUSTER = 0.9, 1.8
local WALL_CLUSTER_MAX = 1.6
local CHECK_REACH = 0.85
local CHECK_DEPTH = 0.15
local CHECK_ALIGN = 0.8
local RAISED = 1.0

local UA, VA = 0.5, 0.03
local UB, VB = 0.99363, 0.885
local UC, VC = 0.00637, 0.885

local SIZE_SHIFT = { s = 1, m = 0, l = -1 }
local SINGLE_SIZE = { s = 0.75, m = 1.0, l = 1.4 }
local GROW_EDGE, SHRINK_EDGE = 1.3, 0.8
local SPACING = { s = 1.4, m = 1.0, l = 0.8 }
local WALLS = { s = 0.6, m = 1.0, l = 1.35 }
local DRAWN = { s = 0.5, m = 0.75, l = 1.0 }

local LOOK = {
    explosion = { reach = 80.0, spacing = 3.5, growth = 0.11, walls = 90, life = 3800, speed = 40.0, burst = true, nudge = true },
    gunshot = { reach = 45.0, spacing = 3.4, growth = 0.19, walls = 36, life = 1900, speed = 50.0, burst = true },
    siren = { reach = 38.0, spacing = 3.2, growth = 0.21, walls = 30, life = 1400, speed = 32.0, every = 650, halo = 22.0, beat = 650 },
    aircraft = { reach = 40.0, spacing = 4.3, growth = 0.27, walls = 0, life = 1700, speed = 34.0, every = 800, halo = 22.0, hum = 2.0, revs = 0.0 },
    crash = { reach = 30.0, spacing = 2.4, growth = 0.2, walls = 36, life = 1900, speed = 36.0, burst = true, nudge = true },
    horn = { reach = 28.0, spacing = 2.5, growth = 0.22, walls = 30, life = 1100, speed = 36.0, every = 380, halo = 20.0, beat = 380 },
    alarm = { reach = 24.0, spacing = 2.4, growth = 0.25, walls = 24, life = 1100, speed = 30.0, every = 600, halo = 18.0, beat = 600 },
    custom = { reach = 24.0, spacing = 2.2, growth = 0.22, walls = 30, life = 1500, speed = 32.0, burst = true, every = 1200, nudge = true },
    vehicle = { reach = 14.0, spacing = 1.8, growth = 0.37, walls = 14, life = 950, speed = 24.0, every = 450, halo = 18.0, hum = 1.2, revs = 2.6 },
    voice = { reach = 7.0, spacing = 1.7, growth = 0.24, walls = 10, life = 1100, speed = 14.0, every = 520 },
    ownvoice = { reach = 7.0, spacing = 1.5, growth = 0.26, walls = 10, life = 1100, speed = 14.0, every = 640, dim = 0.6 },
    footsteps = { reach = 6.0, spacing = 1.1, growth = 0.46, walls = 8, life = 1200, speed = 14.0, step = true },
    skid = { reach = 16.0, spacing = 2.0, growth = 0.3, walls = 0, life = 900, speed = 30.0, every = 300, halo = 16.0, hum = 1.2, revs = 1.2 },
    ownsteps = { reach = 4.5, spacing = 0.9, growth = 0.5, walls = 6, life = 1150, speed = 14.0, step = true, dim = 0.65 },
    fire = { reach = 16.0, spacing = 2.2, growth = 0.26, walls = 16, life = 1500, speed = 12.0, every = 900 },
    fight = { reach = 9.0, spacing = 1.5, growth = 0.32, walls = 10, life = 1000, speed = 22.0, burst = true },
    scream = { reach = 24.0, spacing = 2.3, growth = 0.22, walls = 24, life = 1500, speed = 30.0, burst = true },
    backfire = { reach = 20.0, spacing = 2.4, growth = 0.22, walls = 18, life = 1200, speed = 46.0, burst = true },
    tyrepop = { reach = 30.0, spacing = 2.8, growth = 0.2, walls = 24, life = 1500, speed = 48.0, burst = true },
    door = { reach = 7.0, spacing = 1.3, growth = 0.42, walls = 8, life = 900, speed = 24.0, burst = true },
    music = { reach = 13.0, spacing = 2.0, growth = 0.3, walls = 12, life = 1300, speed = 14.0, every = 520, halo = 16.0, beat = 520 },
    glass = { reach = 16.0, spacing = 1.9, growth = 0.26, walls = 18, life = 1400, speed = 34.0, burst = true },
    props = { reach = 12.0, spacing = 1.7, growth = 0.3, walls = 12, life = 1200, speed = 28.0, burst = true },
    chatter = { reach = 5.5, spacing = 1.4, growth = 0.28, walls = 8, life = 1000, speed = 12.0, every = 640 },
}

local HALO_MOVING, HALO_SETTLED = 4.0, 2.5
local HALO_CHECK_MS = 250
local HALO_NEAR, HALO_FAR = 30.0, 60.0
local POLL_PENDING = 3
local EMIT_MS = 50
local HALO_EASE = 3.0
local HALO_FOLLOW = 15.0
local HALO_TILT = 6.0
local HALO_PLANE_MS = 50
local HALO_WAVELENGTH = 6.0
local HALO_BASE = 18.0
local HALO_RINGS = { s = { 1.0, 3.2, 6.0 }, m = { 0.9, 3.0, 5.6 }, l = { 0.8, 2.6, 4.8, 7.4 } }
local HALO_GAP = { s = 3.0, m = 2.6, l = 2.2 }
local HALO_MARK = 0.3
local HALO_LIFT = 0.08
local HALO_AXLE = 0.6
local HALO_FALLOFF = 0.45
local HALO_SPREAD = 0.85
local HALO_FADE = 0.15

local throughWalls = Config.Marks.throughWalls == true
local drawDistance = tonumber(Config.Marks.drawDistance) or 150.0
local raysPerFrame = math.max(4, math.floor(tonumber(Config.Marks.raysPerFrame) or 32))
local tileBudget = math.max(100, math.floor(tonumber(Config.Marks.budget) or 2400))

local drawTextured = DrawTexturedPoly or DrawSpritePoly
local drawPoly = DrawPoly
local clock = Perf.clock
local runtimeTxd = nil
local loadedShapes = {}

local fields, fieldCount, serial = {}, 0, 0
local function newQueue()
    return { head = 1, tail = 0 }
end

local checks, bursts, steady = newQueue(), newQueue(), newQueue()
local Fhandle, Fjob, flying = {}, {}, 0
local marksGen = 0
local halos = {}
local stats = { grounds = 0, polls = 0, culled = 0, drawn = 0, capped = 0, probes = 0, hits = 0, tiles = 0, singles = 0, checked = 0, crowded = 0, refused = 0, fallbacks = 0, fields = 0, reused = 0, stale = 0 }

local function loadShape(shape)
    if loadedShapes[shape] then return end
    if not runtimeTxd then runtimeTxd = CreateRuntimeTxd(TXD) end
    for variant = 0, 3 do
        local name = shape .. variant
        CreateRuntimeTextureFromImage(runtimeTxd, name, ('textures/%s.png'):format(name))
    end
    loadedShapes[shape] = true
end

local function waiting(queue)
    return queue.tail - queue.head + 1
end

local function queued()
    return waiting(checks) + waiting(bursts) + waiting(steady)
end

local function push(queue, job)
    local tail = queue.tail + 1
    queue.tail = tail
    queue[tail] = job
    job[1].pending = job[1].pending + 1
    job[1].probes = job[1].probes + 1
end

local function enqueue(field, sx, sy, sz, ex, ey, ez, size, due, tx, ty)
    push(field.queue, { field, sx, sy, sz, ex, ey, ez, size, due, tx, ty })
end

local function tangents(nx, ny, nz, angle)
    local ax, ay, az = 0.0, 0.0, 1.0
    if nz > 0.85 or nz < -0.85 then ax, az = 1.0, 0.0 end
    local ux, uy, uz = ay * nz - az * ny, az * nx - ax * nz, ax * ny - ay * nx
    local length = math.sqrt(ux * ux + uy * uy + uz * uz)
    if length < 0.0001 then return nil end
    ux, uy, uz = ux / length, uy / length, uz / length
    local wx, wy, wz = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
    local cos, sin = math.cos(angle), math.sin(angle)
    return ux * cos + wx * sin, uy * cos + wy * sin, uz * cos + wz * sin,
        wx * cos - ux * sin, wy * cos - uy * sin, wz * cos - uz * sin
end

local function clusterRadius(spacing, limit)
    return math.max(CLUSTER_MIN, math.min(limit or CLUSTER_MAX, spacing * CLUSTER_SHARE))
end

local function crowded(field, x, y, z, cell, kind)
    local key = ('%s%d:%d:%d:%d'):format(kind, math.floor(cell * 10.0), math.floor(x / cell), math.floor(y / cell), math.floor(z / cell))
    if field.grid[key] then
        stats.crowded = stats.crowded + 1
        return true
    end
    field.grid[key] = true
    return false
end

local function reachOf(field, x, y, z)
    local dx, dy = x - field.x, y - field.y
    local dz = math.max(0.0, math.abs(z - field.z) - field.height)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function place(field, hx, hy, hz, nx, ny, nz, angle, radius, variant)
    local distance = reachOf(field, hx, hy, hz)
    local limit = field.reach
    if distance > limit then return end
    local ax, ay, az, bx, by, bz = tangents(nx, ny, nz, angle)
    if not ax then return end
    ax, ay, az, bx, by, bz = ax * radius, ay * radius, az * radius, bx * radius, by * radius, bz * radius
    local cx, cy, cz = hx + nx * LIFT, hy + ny * LIFT, hz + nz * LIFT
    local falloff = 1.0 - distance / limit
    local tiles = field.tiles
    local now = GetGameTimer()
    if #tiles == 0 then field.first = now end
    field.last = now
    if now > field.at + math.floor(distance / field.speed * 1000.0) then field.late = field.late + 1 end
    tiles[#tiles + 1] = {
        cx, cy, cz,
        math.floor(distance / field.speed * 1000.0 + math.random() * 70.0),
        field.alpha * (0.22 + 0.78 * falloff ^ 0.8),
        cx + bx * 2.0, cy + by * 2.0, cz + bz * 2.0,
        cx + ax * ROOT3 - bx, cy + ay * ROOT3 - by, cz + az * ROOT3 - bz,
        cx - ax * ROOT3 - bx, cy - ay * ROOT3 - by, cz - az * ROOT3 - bz,
        field.texture .. variant,
        now,
    }
    stats.tiles = stats.tiles + 1
    if variant == 0 then stats.singles = stats.singles + 1 end
end

local function variantFor(radius)
    if radius < MEDIUM_CLUSTER then return 1 end
    if radius < WIDE_CLUSTER then return 2 end
    return 3
end

local function single(field, hx, hy, hz, nx, ny, nz)
    if crowded(field, hx, hy, hz, 0.35, 's') then return end
    place(field, hx, hy, hz, nx, ny, nz, math.random() * TAU, SINGLE_RADIUS * (SINGLE_SIZE[field.size] or 1.0), 0)
end

local function cluster(field, hx, hy, hz, nx, ny, nz, radius, angle)
    local variant = variantFor(radius) + (SIZE_SHIFT[field.size] or 0)
    if variant < 1 then
        variant, radius = 1, radius * GROW_EDGE
    elseif variant > 3 then
        variant, radius = 3, radius * SHRINK_EDGE
    end
    place(field, hx, hy, hz, nx, ny, nz, angle, radius, variant)
end

local function verify(field, hx, hy, hz, nx, ny, nz, spacing, due)
    local radius = clusterRadius(spacing, WALL_CLUSTER_MAX)
    if crowded(field, hx, hy, hz, math.max(0.45, radius * 1.6), 'c') then return end
    local angle = math.random() * TAU
    local check = { x = hx, y = hy, z = hz, nx = nx, ny = ny, nz = nz, radius = radius, angle = angle, left = 3, good = 0 }
    local reach = radius * (field.size == 'l' and GROW_EDGE or 1.0) * CHECK_REACH
    for step = 0, 2 do
        local ax, ay, az = tangents(nx, ny, nz, angle + step * TAU / 3.0 + math.pi * 0.5)
        if not ax then return end
        local px, py, pz = hx + ax * reach, hy + ay * reach, hz + az * reach
        local job = { field, px + nx * 0.35, py + ny * 0.35, pz + nz * 0.35, px - nx * 0.35, py - ny * 0.35, pz - nz * 0.35, 0.0, due + 250 }
        job.check = check
        push(checks, job)
    end
    stats.checked = stats.checked + 1
end

local function settle(field, check, hit, coords, normal)
    check.left = check.left - 1
    if hit and normal then
        local nx, ny, nz = check.nx, check.ny, check.nz
        local align = normal.x * nx + normal.y * ny + normal.z * nz
        local depth = (coords.x - check.x) * nx + (coords.y - check.y) * ny + (coords.z - check.z) * nz
        if align > CHECK_ALIGN and math.abs(depth) < CHECK_DEPTH then check.good = check.good + 1 end
    end
    if check.left > 0 or field.dead then return end
    if check.good == 3 then
        cluster(field, check.x, check.y, check.z, check.nx, check.ny, check.nz, check.radius, check.angle)
    else
        single(field, check.x, check.y, check.z, check.nx, check.ny, check.nz)
    end
end

local function landed(field, hx, hy, hz, nx, ny, nz, entity, size, due)
    if size < 0.0 then
        size = math.max(0.9, math.min(8.0, -size * reachOf(field, hx, hy, hz)))
    end
    local floor = field.z - field.height
    if nz >= 0.7 and entity == 0 and hz < floor + RAISED then
        local radius = clusterRadius(size)
        if crowded(field, hx, hy, hz, math.max(0.45, radius * 1.6), 'c') then return end
        cluster(field, hx, hy, hz, nx, ny, nz, radius, math.random() * TAU)
    else
        verify(field, hx, hy, hz, nx, ny, nz, size, due)
    end
end

local function finish(job, status, hit, coords, normal, entity)
    local field = job[1]
    field.pending = field.pending - 1
    local struck = status == 2 and (hit == true or hit == 1) and normal ~= nil
    if job.check then
        settle(field, job.check, struck, coords, normal)
        return
    end
    if status ~= 2 or field.dead then return end
    if struck then
        local still = not entity or entity == 0 or GetEntitySpeed(entity) < MOVING_SPEED
        local nx, ny, nz = normal.x, normal.y, normal.z
        if still and nx * nx + ny * ny + nz * nz > 0.25 then
            stats.hits = stats.hits + 1
            landed(field, coords.x, coords.y, coords.z, nx, ny, nz, entity or 0, job[8], job[9])
        end
    elseif job[10] then
        stats.fallbacks = stats.fallbacks + 1
        local top = field.z - field.height + 1.5
        push(checks, { field, job[10], job[11], top, job[10], job[11], top - 4.0 - field.reach * 0.25, job[8], job[9] })
    end
end

local function start(queue, now, started)
    while started < raysPerFrame and flying < IN_FLIGHT and queue.head <= queue.tail do
        local job = queue[queue.head]
        local field = job[1]
        if field.dead or now > job[9] then
            queue[queue.head] = nil
            queue.head = queue.head + 1
            field.pending = field.pending - 1
            field.stale = field.stale + 1
            stats.stale = stats.stale + 1
            if job.check then settle(field, job.check, false) end
        else
            local handle = StartShapeTestLosProbe(job[2], job[3], job[4], job[5], job[6], job[7], PROBE_FLAGS, field.ignore, PROBE_OPTIONS)
            if not handle or handle == 0 then
                stats.refused = stats.refused + 1
                return started, true
            end
            queue[queue.head] = nil
            queue.head = queue.head + 1
            flying = flying + 1
            Fhandle[flying], Fjob[flying] = handle, job
            started = started + 1
        end
    end
    if queue.head > queue.tail then
        queue.head, queue.tail = 1, 0
    end
    return started, false
end

local function pumpRays(now)
    local kept, pending, polls = 0, 0, 0
    local total = flying
    local cap = math.max(POLL_PENDING, total // 8)
    for index = 1, total do
        local handle, job = Fhandle[index], Fjob[index]
        local done = false
        if pending < cap then
            polls = polls + 1
            local status, hit, coords, normal, entity = GetShapeTestResult(handle)
            if status == 1 then
                pending = pending + 1
            else
                done = true
                finish(job, status, hit, coords, normal, entity)
            end
        end
        if not done then
            kept = kept + 1
            Fhandle[kept], Fjob[kept] = handle, job
        end
    end
    for index = kept + 1, total do Fhandle[index], Fjob[index] = nil, nil end
    flying = kept
    stats.polls = stats.polls + polls

    local started, refused = start(checks, now, 0)
    if not refused then started, refused = start(bursts, now, started) end
    if not refused then started = start(steady, now, started) end
    stats.probes = stats.probes + started
end

local function cameraDistance(x, y, z)
    local camera = GetFinalRenderedCamCoord()
    local dx, dy, dz = camera.x - x, camera.y - y, camera.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function nudge(x, y, z, ignore)
    local px, py = 0.0, 0.0
    for step = 0, 7 do
        local angle = step * TAU / 8.0
        local ex, ey = x + math.cos(angle) * NUDGE_METRES, y + math.sin(angle) * NUDGE_METRES
        local handle = StartExpensiveSynchronousShapeTestLosProbe(x, y, z, ex, ey, z, PROBE_FLAGS, ignore, PROBE_OPTIONS)
        local status, hit, coords, normal = GetShapeTestResult(handle)
        if status == 2 and (hit == true or hit == 1) and normal then
            local hx, hy = coords.x - x, coords.y - y
            local gap = NUDGE_METRES - math.sqrt(hx * hx + hy * hy)
            if gap > 0.0 then
                px, py = px + normal.x * gap * 0.5, py + normal.y * gap * 0.5
            end
        end
    end
    return x + px, y + py
end

local function retire(key)
    local old = fields[key]
    if not old then return end
    serial = serial + 1
    old.retired = true
    fields[key] = nil
    fields[key .. '#' .. serial] = old
end

local function pulse(field, now)
    local pulses = field.pulses
    if field.at and now - field.at < REPULSE_MS then return false end
    local span = field.life + math.floor(field.reach / field.speed * 1000.0) + 120
    while #pulses > 0 and (now - pulses[1] > span or #pulses >= PULSES) do table.remove(pulses, 1) end
    pulses[#pulses + 1] = now
    field.at = now
    field.ends = now + span
    return true
end

local function build(key, style, look, x, y, z, height, ignore, scale, now)
    local reach = look.reach * (scale or 1.0)
    local seen = cameraDistance(x, y, z)
    if seen > drawDistance + reach + height then return nil end
    loadShape(style.texture)
    if look.nudge and not throughWalls then x, y = nudge(x, y, z, ignore or 0) end

    retire(key)
    local lod = (1.0 + math.max(0.0, seen - 50.0) / 80.0) * math.max(0.6, math.min(1.0, scale or 1.0))
    local packing = SPACING[Echo.detail] or SPACING.m
    local field = {
        x = x, y = y, z = z, height = height, reach = reach, speed = look.speed, life = look.life,
        ignore = ignore or 0, size = Echo.size, detail = Echo.detail, tint = style.tint, texture = style.texture, style = style,
        alpha = style.alpha * (look.dim or 1.0), tiles = {}, grid = {}, pulses = {}, pending = 0, built = now,
        late = 0, stale = 0, probes = 0, kind = style.kind, queue = look.burst and bursts or steady,
    }
    fields[key] = field
    fieldCount = fieldCount + 1
    stats.fields = stats.fields + 1
    pulse(field, now)

    local grace = look.life * STALE_SHARE
    local floor = z - height
    local wallZ = z + math.max(0.0, 0.9 - height)
    local wallBase = (look.walls or 0) * math.min(1.5, math.max(0.5, scale or 1.0))
    local walls = math.floor(wallBase * (WALLS[Echo.detail] or WALLS.m) + 0.5)
    local wallAngle = -math.sqrt(6.57 / math.max(1.0, wallBase)) * lod
    local golden = math.pi * (3.0 - math.sqrt(5.0))
    local low, high = math.sin(math.rad(-8.0)), math.sin(math.rad(60.0))

    local function wallRay(index)
        local rise = low + (high - low) * (index + 0.5) / walls
        local flat = math.sqrt(1.0 - rise * rise)
        local angle = index * golden
        enqueue(field, x, y, wallZ, x + math.cos(angle) * flat * reach, y + math.sin(angle) * flat * reach, wallZ + rise * reach,
            wallAngle, now + reach * 0.5 / look.speed * 1000.0 + grace)
    end

    local wallIndex = 0
    local radius = math.min(0.4, look.spacing * 0.5)
    local turn = math.random() * TAU
    while radius < reach do
        local spacing = (look.spacing + radius * look.growth) * lod
        local step = spacing * packing
        local count = math.max(5, math.ceil(TAU * radius / step))
        local due = now + radius / look.speed * 1000.0 + grace
        turn = turn + 0.7
        for slot = 0, count - 1 do
            local angle = turn + slot * TAU / count
            local tx, ty = x + math.cos(angle) * radius, y + math.sin(angle) * radius
            if throughWalls then
                enqueue(field, tx, ty, z + 1.2, tx, ty, floor - 4.0 - radius * 0.25, spacing, due)
            else
                enqueue(field, x, y, z, x + (tx - x) * 2.5, y + (ty - y) * 2.5, z + (floor - z) * 2.5, spacing, due, tx, ty)
            end
        end
        local wallsDue = math.min(walls, math.floor(walls * math.min(1.0, (radius + step) / (reach * 0.6))))
        while wallIndex < wallsDue do
            wallRay(wallIndex)
            wallIndex = wallIndex + 1
        end
        radius = radius + step
    end
    while wallIndex < walls do
        wallRay(wallIndex)
        wallIndex = wallIndex + 1
    end
    return field
end

local function fieldFor(key, style, look, x, y, z, height, ignore, scale, now)
    local field = fields[key]
    if field and not field.dead and now - field.built < FIELD_KEEP_MS and field.size == Echo.size and field.detail == Echo.detail and field.style == style then
        local dx, dy, dz = field.x - x, field.y - y, field.z - z
        local moved = dx * dx + dy * dy + dz * dz
        local keep = look.step and STEP_REBUILD_METRES or REBUILD_METRES
        if queued() > BACKLOG then keep = math.max(keep, BACKLOG_REBUILD_METRES) end
        if moved < keep * keep then
            pulse(field, now)
            stats.reused = stats.reused + 1
            return field
        end
    end
    return build(key, style, look, x, y, z, height, ignore, scale, now)
end

local function stepInterval(speed)
    return math.max(300, math.min(640, 820 - speed * 80))
end

local CROUCHED = GetHashKey('move_ped_crouched') & 0xFFFFFFFF

local function hushed(ped)
    if GetPedStealthMovement(ped) then return true end
    if (GetPedMovementClipset(ped) & 0xFFFFFFFF) == CROUCHED then return true end
    local state
    if ped == PlayerPedId() then
        state = LocalPlayer.state
    else
        local player = NetworkGetPlayerIndexFromPed(ped)
        if player == -1 then return false end
        state = Player(GetPlayerServerId(player)).state
    end
    return state.crouch == true or (tonumber(state.stance) or 0) >= 2
end

local function stepScale(speed, ped)
    local scale = math.max(0.6, math.min(1.5, 0.55 + speed * 0.11))
    if hushed(ped) then return math.min(scale * 0.35, 0.3) end
    return scale
end

local groundCache, groundKeys = {}, 0

local function groundUnder(x, y, z)
    local key = ('%d:%d:%d'):format(math.floor(x), math.floor(y), math.floor(z))
    local cached = groundCache[key]
    if cached then return cached end
    local found, ground = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    if not found then return z - 0.8 end
    if groundKeys > 4000 then groundCache, groundKeys = {}, 0 end
    groundCache[key] = ground
    groundKeys = groundKeys + 1
    return ground
end

local function origin(source)
    local entity = source.entity
    if entity and DoesEntityExist(entity) then
        local pos = GetEntityCoords(entity)
        source.coords = pos
        local height = GetEntityHeightAboveGround(entity)
        if IsEntityAPed(entity) and source.kind == 'footsteps' then
            return pos.x, pos.y, pos.z - height + 0.35, 0.35, entity
        end
        return pos.x, pos.y, pos.z, math.max(0.3, height), entity
    end
    local pos = source.coords
    local ground = groundUnder(pos.x, pos.y, pos.z)
    local z = math.max(pos.z, ground + 0.8)
    return pos.x, pos.y, z, z - ground, 0
end

local function emitSource(key, source, look, now)
    local x, y, z, height, entity = origin(source)
    local style = Looks.forSource(source)
    local scale = 1.0
    if source.kind == 'gunshot' and source.range == Config.Sounds.gunshot.suppressedRange then
        scale = 0.3
    elseif source.kind == 'footsteps' and entity ~= 0 then
        scale = stepScale(GetEntitySpeed(entity), entity)
    elseif source.kind == 'vehicle' then
        scale = source.loudness or 1.0
    elseif source.scale then
        scale = source.scale
    elseif source.kind == 'custom' then
        scale = math.max(0.5, math.min(2.5, source.range / 40.0))
    end
    fieldFor(key, style, look, x, y, z, height, entity, scale, now)
    source.lastEmit = now
end

local footprints = {}

local function footprintOf(source, entity)
    local model = GetEntityModel(entity)
    local known = footprints[model]
    if not known then
        local low, high = GetModelDimensions(model)
        if low and high and high.y > low.y and high.x > low.x then
            known = { y = (low.y + high.y) * 0.5, a = math.max(0.4, (high.y - low.y) * 0.5), b = math.max(0.3, (high.x - low.x) * 0.5) }
        else
            known = { y = 0.0, a = 2.2, b = 1.0 }
        end
        footprints[model] = known
    end
    if source.kind == 'skid' and source.axle then return { y = source.axle, a = HALO_AXLE, b = known.b } end
    return known
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
    if segment == 1 then return b + d, -a + at end
    if segment == 2 then return b + d * math.cos(t), a + d * math.sin(t) end
    if segment == 3 then return b - at, a + d end
    if segment == 4 then return -b - d * math.sin(t), a + d * math.cos(t) end
    if segment == 5 then return -b - d, a - at end
    if segment == 6 then return -b - d * math.cos(t), -a - d * math.sin(t) end
    if segment == 7 then return -b + at, -a - d end
    return b + d * math.sin(t), -a - d * math.cos(t)
end

local function haloLayout(halo)
    local rings = HALO_RINGS[Echo.detail] or HALO_RINGS.m
    local gap = HALO_GAP[Echo.detail] or HALO_GAP.m
    local scale = halo.look.halo / HALO_BASE
    local foot = halo.print
    local a, b = foot.a, foot.b
    local size = SINGLE_SIZE[Echo.size] or 1.0
    local texture = halo.texture .. '0'
    local marks = {}
    for ring, offset in ipairs(rings) do
        local d = offset * scale
        local perimeter = 4.0 * a + 4.0 * b + TAU * d
        local count = math.max(6, math.floor(perimeter / gap + 0.5))
        local peak = 1.0 - HALO_FALLOFF * (ring - 1) / math.max(1, #rings - 1)
        local radius = HALO_MARK * size * (1.0 + d * 0.04)
        for slot = 0, count - 1 do
            local at = (slot + (ring % 2) * 0.5) / count * perimeter
            local x, y = ringPoint(a, b, d, at)
            local nx, ny = ringPoint(a, b, d, at + 0.05)
            local tx, ty = nx - x, ny - y
            local length = math.sqrt(tx * tx + ty * ty)
            if length < 0.0001 then tx, ty, length = 0.0, 1.0, 1.0 end
            local ax, ay = tx / length * radius, ty / length * radius
            local bx, by = ay, -ax
            marks[#marks + 1] = {
                bx * 2.0, by * 2.0, ax * ROOT3 - bx, ay * ROOT3 - by, -ax * ROOT3 - bx, -ay * ROOT3 - by,
                x = x, y = y + foot.y, d = d, ring = ring, peak = peak,
            }
        end
    end
    halo.marks, halo.rings, halo.mark = marks, #rings, texture
    halo.reach = rings[#rings] * scale + math.sqrt(a * a + b * b) + math.abs(foot.y)
    halo.detail, halo.size = Echo.detail, Echo.size
end

local function haloLevel(source)
    if source.kind == 'vehicle' or source.kind == 'skid' then return source.loudness or 0.0 end
    return 1.0
end

local function ringShown(level, ring, rings)
    local shown = (level - (ring - 1) / rings * HALO_SPREAD) / HALO_FADE
    if shown <= 0.0 then return 0.0 end
    return shown > 1.0 and 1.0 or shown
end

local function updateHalo(key, halo, now)
    local source = halo.source
    local entity = source.entity
    local alive = Sources.active[key] == source and now <= source.expires and entity and DoesEntityExist(entity)
    local dt = math.min(0.1, (now - (halo.last or now)) / 1000.0)
    halo.last = now
    local target = alive and haloLevel(source) or 0.0
    halo.level = halo.level + (target - halo.level) * math.min(1.0, dt * HALO_EASE)
    if not alive then
        if halo.engine then Engines.track(halo, nil, source, now, dt, false) end
        if halo.level < 0.02 and not (halo.engine and Engines.busy(halo)) then halos[key] = nil end
        return
    end
    if halo.detail ~= Echo.detail or halo.size ~= Echo.size then haloLayout(halo) end
    local pos = GetEntityCoords(entity)
    local forward = GetEntityForwardVector(entity)
    local flat = math.sqrt(forward.x * forward.x + forward.y * forward.y)
    if flat > 0.01 then halo.fx, halo.fy = forward.x / flat, forward.y / flat end
    halo.cx, halo.cy = pos.x, pos.y
    if not halo.drop or (now >= halo.planeAt and not halo.culled) then
        halo.planeAt = now + HALO_PLANE_MS
        local floor = pos.z - GetEntityHeightAboveGround(entity)
        local found, z, normal = GetGroundZAndNormalFor_3dCoord(pos.x, pos.y, floor + 0.6)
        stats.grounds = stats.grounds + 1
        local drop, sx, sy = floor - pos.z, 0.0, 0.0
        if (found == true or found == 1) and normal and normal.z > 0.5 and math.abs(z - floor) < 1.0 then
            drop, sx, sy = z - pos.z, -normal.x / normal.z, -normal.y / normal.z
        end
        if halo.drop then
            local follow = math.min(1.0, dt * HALO_FOLLOW)
            local tilt = math.min(1.0, dt * HALO_TILT)
            halo.drop = halo.drop + (drop - halo.drop) * follow
            halo.sx = halo.sx + (sx - halo.sx) * tilt
            halo.sy = halo.sy + (sy - halo.sy) * tilt
        else
            halo.drop, halo.sx, halo.sy = drop, sx, sy
        end
    end
    halo.gz = pos.z + halo.drop
    if halo.engine then Engines.track(halo, entity, source, now, dt, true) end
end

local function emitHalos(now)
    for key, halo in pairs(halos) do updateHalo(key, halo, now) end
end

local function isHalo(source, entity, now)
    if not entity or entity == 0 then return false end
    if source.kind == 'vehicle' or source.kind == 'skid' then return true end
    if now < (source.haloAt or 0) then return source.moving == true end
    source.haloAt = now + HALO_CHECK_MS
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        source.moving = false
        return false
    end
    local speed = GetEntitySpeed(entity)
    if source.moving then
        source.moving = speed > HALO_SETTLED
    else
        source.moving = speed > HALO_MOVING
    end
    return source.moving
end

local function feedHalo(key, source, look)
    local halo = halos[key]
    if halo and halo.source == source and halo.style then return end
    local style = Looks.forSource(source)
    loadShape(style.texture)
    local previous = halo
    halo = {
        key = key, source = source, look = look, tint = style.tint, texture = style.texture, style = style,
        alpha = style.alpha * (source.dim or 1.0), level = previous and previous.level or 0.0,
        print = footprintOf(source, source.entity), planeAt = 0, drop = previous and previous.drop,
        sx = previous and previous.sx or 0.0, sy = previous and previous.sy or 0.0,
        fx = previous and previous.fx or 0.0, fy = previous and previous.fy or 1.0,
    }
    haloLayout(halo)
    if source.kind == 'vehicle' then Engines.attach(halo, previous) end
    halos[key] = halo
end

local function emitSources(now)
    for key, source in pairs(Sources.active) do
        local look = LOOK[source.kind]
        if look and now <= source.expires and look.halo and isHalo(source, source.entity, now) then
            feedHalo(key, source, look)
        elseif look and now <= source.expires then
            if look.burst and source.pulses > (source.shown or 0) then
                if now - (source.lastEmit or 0) >= BURST_GAP_MS then
                    source.shown = source.pulses
                    emitSource(key, source, look, now)
                    if look.every then source.nextEmit = now + look.every end
                end
            elseif (look.every or look.step) and now >= (source.nextEmit or 0) then
                emitSource(key, source, look, now)
                if look.step and source.entity and DoesEntityExist(source.entity) then
                    source.nextEmit = now + stepInterval(GetEntitySpeed(source.entity))
                else
                    source.nextEmit = now + (look.every or 500)
                end
            end
        end
    end
end

local ownNext = 0

local function walking(ped)
    if not IsPedOnFoot(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsEntityDead(ped) then return nil end
    local speed = GetEntitySpeed(ped)
    if speed < STEP_SPEED then return nil end
    return speed
end

local function emitOwnSteps(now, ped)
    if now < ownNext or not Echo.listens('ownsteps') then return end
    local speed = walking(ped)
    if not speed then return end
    local pos = GetEntityCoords(ped)
    local ground = pos.z - GetEntityHeightAboveGround(ped)
    fieldFor('own', Looks.style('ownsteps'), LOOK.ownsteps, pos.x, pos.y, ground + 0.35, 0.35, ped, stepScale(speed, ped), now)
    ownNext = now + stepInterval(speed)
end

local previewIndex, previewNext, sampleUntil = 0, 0, 0

local function emitPreview(now, ped)
    if now >= sampleUntil or now < previewNext or not Echo.enabled then return end
    previewNext = now + PREVIEW_MS
    local shown = {}
    for _, kind in ipairs(Echo.kinds) do
        if Echo.prefs[kind] and kind ~= 'ownsteps' and kind ~= 'ownvoice' and LOOK[kind] then shown[#shown + 1] = kind end
    end
    if #shown == 0 then return end
    previewIndex = previewIndex % #shown + 1
    local kind = shown[previewIndex]
    local rotation = GetFinalRenderedCamRot(2)
    local heading = math.rad(rotation.z + 20.0 - (previewIndex % 3) * 20.0)
    local pos = GetEntityCoords(ped)
    local distance = 6.0 + (previewIndex % 2) * 3.0
    local x, y = pos.x - math.sin(heading) * distance, pos.y + math.cos(heading) * distance
    local ground = groundUnder(x, y, pos.z)
    local look = LOOK[kind]
    build('preview:' .. previewIndex, Looks.style(kind), look, x, y, ground + 1.0, 1.0, ped, math.min(1.0, 9.0 / look.reach), now)
end

local function envelope(t, life)
    if t < 0 or t >= life then return 0.0 end
    local progress = t / life
    local fade = progress < 0.45 and 1.0 or (1.0 - (progress - 0.45) / 0.55) ^ 1.5
    if t < 90 then fade = fade * t / 90 end
    return fade
end

local function outside(front, centre, around, halfAngle)
    if centre <= around * around then return false end
    local distance = math.sqrt(centre)
    local widest = halfAngle + math.asin(around / distance)
    if widest >= math.pi then return false end
    return front < distance * math.cos(widest)
end

local function draw(now)
    local camera = GetFinalRenderedCamCoord()
    local rotation = GetFinalRenderedCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local cp = math.cos(pitch)
    local fx, fy, fz = -math.sin(yaw) * cp, math.cos(yaw) * cp, math.sin(pitch)
    local half = math.atan(math.tan(math.rad(GetFinalRenderedCamFov()) * 0.5) * math.sqrt(1.0 + GetAspectRatio(false) ^ 2)) + 0.15
    local cone = math.cos(math.min(1.5, half)) ^ 2
    local halfAngle = math.min(1.5, half)
    local cx, cy, cz = camera.x, camera.y, camera.z
    local far = drawDistance * drawDistance
    local cap = math.floor(tileBudget * (DRAWN[Echo.detail] or DRAWN.m))
    local drawn, capped = 0, 0
    local flat = Marks.flat or not drawTextured

    SetBackfaceculling(false)
    for key, field in pairs(fields) do
        local ox, oy, oz = field.x - cx, field.y - cy, field.z - cz
        local around = field.reach + 2.0
        local front = ox * fx + oy * fy + oz * fz
        local centre = ox * ox + oy * oy + oz * oz
        local limit = drawDistance + around
        if now > field.ends and field.pending <= 0 then
            field.dead = true
            fields[key] = nil
            fieldCount = fieldCount - 1
            if Marks.trace then Marks.trace(field) end
        elseif centre > limit * limit or front < -around or outside(front, centre, around, halfAngle) then
            stats.culled = stats.culled + 1
        else
            local pulses, life = field.pulses, field.life
            local newest = #pulses
            local tint = field.tint
            local r, g, b = tint[1], tint[2], tint[3]
            local tiles = field.tiles
            for index = 1, #tiles do
                local tile = tiles[index]
                local delay, born = tile[4], tile[16]
                local fade = 0.0
                for which = newest, 1, -1 do
                    local begin = pulses[which] + delay
                    if begin < born then begin = born end
                    if now >= begin then
                        fade = envelope(now - begin, life)
                        if now - begin < 90 and which > 1 then
                            local older = pulses[which - 1] + delay
                            if older < born then older = born end
                            local before = envelope(now - older, life)
                            if before > fade then fade = before end
                        end
                        break
                    end
                end
                if fade > 0.0 then
                    local dx, dy, dz = tile[1] - cx, tile[2] - cy, tile[3] - cz
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < far then
                        local ahead = dx * fx + dy * fy + dz * fz
                        if d2 < 30.0 or (ahead > 0.0 and ahead * ahead > cone * d2) then
                            local alpha = math.floor(tile[5] * fade)
                            if alpha > 3 then
                                if drawn >= cap then
                                    capped = capped + 1
                                elseif flat then
                                    local mx, my, mz = tile[1], tile[2], tile[3]
                                    drawPoly(mx + (tile[6] - mx) * 0.15, my + (tile[7] - my) * 0.15, mz + (tile[8] - mz) * 0.15,
                                        mx + (tile[9] - mx) * 0.15, my + (tile[10] - my) * 0.15, mz + (tile[11] - mz) * 0.15,
                                        mx + (tile[12] - mx) * 0.15, my + (tile[13] - my) * 0.15, mz + (tile[14] - mz) * 0.15, r, g, b, alpha)
                                    drawn = drawn + 1
                                else
                                    drawTextured(tile[6], tile[7], tile[8], tile[9], tile[10], tile[11], tile[12], tile[13], tile[14],
                                        r, g, b, alpha, TXD, tile[15], UA, VA, 1.0, UB, VB, 1.0, UC, VC, 1.0)
                                    drawn = drawn + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local seconds = now / 1000.0
    local paintR, paintG, paintB, paintTexture = 255, 255, 255, nil
    local function put(px, py, pz, sx, sy, ax, ay, radius, alpha)
        local dx, dy, dz = px - cx, py - cy, pz - cz
        local d2 = dx * dx + dy * dy + dz * dz
        if d2 >= far then return end
        local ahead = dx * fx + dy * fy + dz * fz
        if d2 >= 30.0 and (ahead <= 0.0 or ahead * ahead <= cone * d2) then return end
        if drawn >= cap then
            capped = capped + 1
            return
        end
        ax, ay = ax * radius, ay * radius
        local bx, by = ay, -ax
        local x1, y1 = bx * 2.0, by * 2.0
        local x2, y2 = ax * ROOT3 - bx, ay * ROOT3 - by
        local x3, y3 = -ax * ROOT3 - bx, -ay * ROOT3 - by
        if flat then
            x1, y1, x2, y2, x3, y3 = x1 * 0.3, y1 * 0.3, x2 * 0.3, y2 * 0.3, x3 * 0.3, y3 * 0.3
            drawPoly(px + x1, py + y1, pz + sx * x1 + sy * y1, px + x2, py + y2, pz + sx * x2 + sy * y2,
                px + x3, py + y3, pz + sx * x3 + sy * y3, paintR, paintG, paintB, alpha)
        else
            drawTextured(px + x1, py + y1, pz + sx * x1 + sy * y1, px + x2, py + y2, pz + sx * x2 + sy * y2,
                px + x3, py + y3, pz + sx * x3 + sy * y3, paintR, paintG, paintB, alpha, TXD, paintTexture, UA, VA, 1.0, UB, VB, 1.0, UC, VC, 1.0)
        end
        drawn = drawn + 1
    end
    for _, halo in pairs(halos) do
        local level = halo.level
        local hx, hy, hz = halo.cx, halo.cy, halo.gz
        local inView = false
        if hx and hz then
            local around = halo.reach + 2.0
            local ox, oy, oz = hx - cx, hy - cy, hz - cz
            local squared = ox * ox + oy * oy + oz * oz
            local centre = math.sqrt(squared)
            local front = ox * fx + oy * fy + oz * fz
            inView = centre < drawDistance + around and front > -around and not outside(front, squared, around, halfAngle)
            halo.stride = centre > HALO_FAR and 3 or (centre > HALO_NEAR and 2 or 1)
        end
        halo.culled = not inView
        if halo.engine then
            if inView and (level > 0.02 or Engines.busy(halo)) then
                local tint = halo.tint
                paintR, paintG, paintB, paintTexture = tint[1], tint[2], tint[3], halo.mark
                Engines.draw(halo, put, now)
            end
        elseif level > 0.02 and inView then
            local stride = halo.stride
            local look = halo.look
            local tint = halo.tint
            local r, g, b = tint[1], tint[2], tint[3]
            local beat = look.beat ~= nil
            local freq = beat and (1000.0 / look.beat) or ((look.hum or 1.2) + (look.revs or 2.6) * level)
            local depth = beat and 0.45 or 0.25
            local strength = halo.alpha * (0.45 + 0.55 * level)
            local rings = halo.rings
            local ux, uy = halo.fx, halo.fy
            local rx, ry = uy, -ux
            local sx, sy = halo.sx, halo.sy
            local base = hz + HALO_LIFT
            local texture = halo.mark
            local marks = halo.marks
            local ring, shown, wave = 0, 0.0, 0.0
            for index = 1, #marks, stride do
                local mark = marks[index]
                if mark.ring ~= ring then
                    ring = mark.ring
                    shown = beat and 1.0 or ringShown(level, ring, rings)
                    wave = (1.0 - depth) + depth * math.sin(TAU * (seconds * freq - mark.d / HALO_WAVELENGTH))
                end
                if shown > 0.0 then
                    local alpha = math.floor(strength * mark.peak * wave * shown)
                    if alpha > 3 then
                        local mx, my = mark.x, mark.y
                        local px, py = hx + mx * rx + my * ux, hy + mx * ry + my * uy
                        local pz = base + sx * (px - hx) + sy * (py - hy)
                        local dx, dy, dz = px - cx, py - cy, pz - cz
                        local d2 = dx * dx + dy * dy + dz * dz
                        local ahead = dx * fx + dy * fy + dz * fz
                        if d2 < far and (d2 < 30.0 or (ahead > 0.0 and ahead * ahead > cone * d2)) then
                            if drawn >= cap then
                                capped = capped + 1
                            else
                                local a1, b1, a2, b2, a3, b3 = mark[1], mark[2], mark[3], mark[4], mark[5], mark[6]
                                local x1, y1 = a1 * rx + b1 * ux, a1 * ry + b1 * uy
                                local x2, y2 = a2 * rx + b2 * ux, a2 * ry + b2 * uy
                                local x3, y3 = a3 * rx + b3 * ux, a3 * ry + b3 * uy
                                if flat then
                                    x1, y1, x2, y2, x3, y3 = x1 * 0.3, y1 * 0.3, x2 * 0.3, y2 * 0.3, x3 * 0.3, y3 * 0.3
                                    drawPoly(px + x1, py + y1, pz + sx * x1 + sy * y1, px + x2, py + y2, pz + sx * x2 + sy * y2,
                                        px + x3, py + y3, pz + sx * x3 + sy * y3, r, g, b, alpha)
                                else
                                    drawTextured(px + x1, py + y1, pz + sx * x1 + sy * y1, px + x2, py + y2, pz + sx * x2 + sy * y2,
                                        px + x3, py + y3, pz + sx * x3 + sy * y3, r, g, b, alpha, TXD, texture, UA, VA, 1.0, UB, VB, 1.0, UC, VC, 1.0)
                                end
                                drawn = drawn + 1
                            end
                        end
                    end
                end
            end
        end
    end
    SetBackfaceculling(true)
    stats.drawn, stats.capped = drawn, capped
end

local function clearAll()
    for _, field in pairs(fields) do field.dead = true end
    fields, fieldCount = {}, 0
    checks, bursts, steady = newQueue(), newQueue(), newQueue()
    halos = {}
    for index = 1, flying do
        GetShapeTestResult(Fhandle[index])
        Fhandle[index], Fjob[index] = nil, nil
    end
    flying = 0
    groundCache, groundKeys = {}, 0
    ownNext, previewNext, sampleUntil = 0, 0, 0
end

local function showing()
    return fieldCount > 0 or next(halos) ~= nil
end

local function working()
    return showing() or flying > 0 or queued() > 0
end

local function emitAll(now, ped)
    emitSources(now)
    emitOwnSteps(now, ped)
    emitPreview(now, ped)
end

local function frame(now)
    local perf = Perf.on
    local started = perf and clock()
    local ped = PlayerPedId()
    emitAll(now, ped)
    local mark = perf and clock()
    if perf then Perf.add('marks.emit', started) end
    emitHalos(now)
    if perf then Perf.add('marks.halos', mark) mark = clock() end
    pumpRays(now)
    if perf then Perf.add('marks.rays', mark) mark = clock() end
    local drew = showing()
    if drew then draw(now) end
    if perf then
        Perf.add('marks.draw', mark)
        Perf.count('marks.frames')
        if drew then Perf.count('marks.drawn', stats.drawn) end
    end
end

local function listening(now, ped)
    if Sources.count > 0 or now < sampleUntil then return true end
    return Echo.listens('ownsteps') and walking(ped) ~= nil
end

function Marks.start()
    marksGen = marksGen + 1
    local gen = marksGen
    CreateThread(function()
        while gen == marksGen do
            local now = GetGameTimer()
            if IsPauseMenuActive() then
                Wait(IDLE_MS)
            elseif working() then
                frame(now)
                Wait(0)
            else
                local perf = Perf.on
                local started = perf and clock()
                local ped = PlayerPedId()
                local heard = listening(now, ped)
                if heard then emitAll(now, ped) end
                if perf then Perf.add('marks.wait', started) end
                if not heard then
                    Wait(IDLE_MS)
                elseif working() then
                    Wait(0)
                else
                    Wait(EMIT_MS)
                end
            end
        end
    end)
end

function Marks.stop()
    marksGen = marksGen + 1
    clearAll()
end

function Marks.restyle()
    for _, halo in pairs(halos) do halo.style = false end
end

function Marks.sample(ms)
    sampleUntil = GetGameTimer() + ms
    previewNext = 0
end

function Marks.clear()
    clearAll()
end

function Marks.stats()
    local tiles = 0
    for _, field in pairs(fields) do tiles = tiles + #field.tiles end
    return {
        fields = fieldCount,
        tiles = tiles,
        cap = math.floor(tileBudget * (DRAWN[Echo.detail] or DRAWN.m)),
        drawn = stats.drawn,
        capped = stats.capped,
        queued = queued(),
        flying = flying,
        probes = stats.probes,
        hits = stats.hits,
        made = stats.tiles,
        singles = stats.singles,
        checked = stats.checked,
        crowded = stats.crowded,
        refused = stats.refused,
        fallbacks = stats.fallbacks,
        skipped = stats.stale,
        built = stats.fields,
        reused = stats.reused,
        halos = (function() local count = 0 for _ in pairs(halos) do count = count + 1 end return count end)(),
        grounds = stats.grounds,
        polls = stats.polls,
        culled = stats.culled,
        textured = drawTextured ~= nil and not Marks.flat,
    }
end

function Marks.resetCounts()
    for key in pairs(stats) do stats[key] = 0 end
end

function Marks.benchFill(count)
    local style = Looks.style('gunshot')
    loadShape(style.texture)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local floor = pos.z - GetEntityHeightAboveGround(ped)
    local now = GetGameTimer()
    local field = {
        x = pos.x, y = pos.y, z = floor + 1.0, height = 1.0, reach = 80.0, speed = 100000.0, life = 60000,
        ignore = ped, size = Echo.size, detail = Echo.detail, tint = style.tint, texture = style.texture, style = style, alpha = style.alpha, tiles = {}, grid = {}, pulses = {},
        pending = 0, built = now, late = 0, stale = 0, probes = 0, kind = style.kind, queue = bursts,
    }
    fields['bench'] = field
    fieldCount = fieldCount + 1
    pulse(field, now - 500)
    for _ = 1, count do
        local a = math.random() * TAU
        local r = 1.5 + 40.0 * math.sqrt(math.random())
        cluster(field, pos.x + math.cos(a) * r, pos.y + math.sin(a) * r, floor, 0.0, 0.0, 1.0, clusterRadius(3.5 + r * 0.11), math.random() * TAU)
    end
end

function Marks.benchDraw(times)
    local now = GetGameTimer()
    local started = GetNetworkTimeAccurate()
    for _ = 1, times do draw(now) end
    return (GetNetworkTimeAccurate() - started) / times
end

function Marks.benchBuild(kind, times)
    clearAll()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local now = GetGameTimer()
    local started = GetNetworkTimeAccurate()
    for index = 1, times do build('bench:' .. index, Looks.style('gunshot'), LOOK[kind], pos.x, pos.y, pos.z, 1.0, ped, 1.0, now) end
    local spent = (GetNetworkTimeAccurate() - started) / times
    local probes = queued() / times
    clearAll()
    return spent, probes
end

function Marks.haloReport(own)
    local list = {}
    for key, halo in pairs(halos) do
        local source = halo.source
        local shown = 0
        for index = 1, #halo.marks do
            if ringShown(halo.level, halo.marks[index].ring, halo.rings) > 0.0 then shown = shown + 1 end
        end
        list[#list + 1] = {
            key = key, kind = source.kind, own = source.entity == own, electric = source.electric == true, level = halo.level,
            loud = source.loudness or 1.0, speed = source.entity and DoesEntityExist(source.entity) and GetEntitySpeed(source.entity) or 0.0,
            anchors = #halo.marks, ready = shown, reach = halo.reach,
            engine = halo.engine and Engines.report(halo) or nil,
        }
    end
    return list
end

Marks.LOOK = LOOK

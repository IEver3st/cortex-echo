Config = {}

Config.Locale = 'en'
Config.Command = 'echo'
Config.DefaultEnabled = false
Config.MaxCues = 6

Config.Marks = {
    throughWalls = false,
    density = 'm',
    budget = 2400,
    drawDistance = 150.0,
    raysPerFrame = 32,
    offscreenCues = true,
    palette = 'custom',
}

Config.Sounds = {
    gunshot = { enabled = true, range = 160.0, suppressedRange = 25.0, shape = 'diamond', color = '#ff584c' },
    explosion = { enabled = true, range = 250.0, shape = 'diamond', color = '#ff584c' },
    crash = { enabled = true, range = 90.0, shape = 'square', color = '#ffb846' },
    siren = { enabled = true, range = 180.0, lightsCount = true, own = true, shape = 'cross', color = '#4ea0ff' },
    horn = { enabled = true, range = 60.0, shape = 'square', color = '#ffb846' },
    alarm = { enabled = true, range = 60.0, shape = 'square', color = '#ffb846' },
    skid = { enabled = true, range = 80.0, shape = 'square', color = '#ffb846' },
    vehicle = { enabled = true, range = 60.0, quietest = 0.12, own = true, nearest = 4, driving = 2, shape = 'dash', color = '#eeeee4' },
    aircraft = { enabled = true, range = 220.0, shape = 'dash', color = '#eeeee4' },
    footsteps = { enabled = true, range = 14.0, walkRange = 6.0, players = true, npcs = false, shape = 'triangle', color = '#46e4c6' },
    ownsteps = { enabled = true, shape = 'triangle', color = '#46e4c6' },
    voice = { enabled = true, range = 12.0, shape = 'ring', color = '#3dff5a' },
    ownvoice = { enabled = true, shape = 'ring', color = '#3dff5a' },
    fire = { enabled = true, range = 45.0, shape = 'chevron', color = '#ff584c' },
    fight = { enabled = true, range = 25.0, shape = 'square', color = '#ff584c' },
    scream = { enabled = true, range = 45.0, pain = true, shape = 'triangle', color = '#ff584c' },
    backfire = { enabled = true, range = 70.0, stockCars = false, shape = 'circle', color = '#ffb846' },
    tyrepop = { enabled = true, range = 90.0, shape = 'ring', color = '#ffb846' },
    door = { enabled = true, range = 18.0, shape = 'square', color = '#eeeee4' },
    music = { enabled = true, range = 30.0, npcs = true, shape = 'ring', color = '#b58cff' },
    glass = { enabled = true, range = 45.0, shape = 'star', color = '#ffe14d' },
    props = { enabled = true, range = 35.0, shape = 'square', color = '#ffe14d' },
    chatter = { enabled = true, range = 10.0, shape = 'circle', color = '#46e4c6' },
    custom = { enabled = true, shape = 'square', color = '#ffb846' },
}

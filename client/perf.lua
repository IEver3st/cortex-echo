Perf = { on = false, spent = {}, counts = {} }

local system = rawget(_G, 'os') or {}
local nanotime, source
if type(system.nanotime) == 'function' then
    nanotime, source = system.nanotime, 'os.nanotime'
elseif type(system.microtime) == 'function' then
    nanotime, source = function() return system.microtime() * 1000 end, 'os.microtime'
elseif type(system.clock) == 'function' then
    nanotime, source = function() return system.clock() * 1000000000 end, 'os.clock'
else
    nanotime, source = function() return GetGameTimer() * 1000000 end, 'GetGameTimer'
end

Perf.clock = nanotime
Perf.source = source

function Perf.add(name, started)
    local spent = Perf.spent
    spent[name] = (spent[name] or 0) + (nanotime() - started)
end

function Perf.count(name, amount)
    local counts = Perf.counts
    counts[name] = (counts[name] or 0) + (amount or 1)
end

function Perf.reset()
    Perf.spent, Perf.counts = {}, {}
end

-- Shared test setup: a standard set of items and a way to pre-write a character config.
local lfs = require('lfs')
local mock = require('mock')

local M = {}

function M.items(m)
    m.item('Rusty Sword', '1H Slashing', { 'mainhand', 'offhand' })
    m.item('Fine Steel Sword', '1H Slashing', { 'mainhand', 'offhand' })
    m.item('Greatstaff', '2H Blunt', { 'mainhand' })
    m.item('Round Shield', 'Shield', { 'offhand' })
    m.item('Lucky Charm', 'Charm', { 'charm' })
end

M.ALL_DEBUG = { swap = true, guard = true, config = true, cmd = true, ui = true }

function M.configPath(m)
    return m.tmpdir .. '/BogoSwap/testserver_Tester.lua'
end

-- Writes the character config BogoSwap will load, merged over the built-in defaults.
function M.writeConfig(m, values)
    local config = require('bogoswap.core.config')
    lfs.mkdir(m.tmpdir .. '/BogoSwap')
    local cfg = config.merge(config.BUILTIN_DEFAULTS, values)
    local f = assert(io.open(M.configPath(m), 'w'))
    f:write('return ', mock.serialize(cfg), '\n')
    f:close()
end

function M.readConfig(m)
    return dofile(M.configPath(m))
end

-- The usual configuration: swap mainhand between two one-handers on Spirit of Wolf.
function M.swords(m, extra)
    M.items(m)
    local values = {
        TriggerEffectName = 'Spirit of Wolf',
        SwapEquipmentSlot = 'mainhand',
        MatchItemName = 'Fine Steel Sword',
        NoMatchItemName = 'Rusty Sword',
    }
    for k, v in pairs(extra or {}) do values[k] = v end
    M.writeConfig(m, values)
    m.world.bags = { 'Fine Steel Sword', 'Rusty Sword' }
end

function M.count(s, sub)
    local n, i = 0, 1
    while true do
        local a, b = s:find(sub, i, true)
        if not a then return n end
        n, i = n + 1, b + 1
    end
end

return M
